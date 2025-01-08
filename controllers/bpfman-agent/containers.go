/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
*/

package bpfmanagent

import (
	"context"
	"fmt"
	"os/exec"
	"slices"
	"strconv"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"

	"github.com/buger/jsonparser"
	"github.com/go-logr/logr"
)

type ContainerInfo struct {
	podName       string
	containerName string
	pid           int64
}

// Create an interface for getting the list of containers in which the program
// should be attached so we can mock it in unit tests.
type ContainerGetter interface {
	// Get the list of containers on this node that match the containerSelector.
	GetContainers(ctx context.Context,
		selectorNamespace string,
		selectorPods metav1.LabelSelector,
		selectorContainerNames *[]string,
		logger logr.Logger) (*[]ContainerInfo, error)
}

type RealContainerGetter struct {
	nodeName  string
	clientSet kubernetes.Interface
}

func NewRealContainerGetter(nodeName string) (*RealContainerGetter, error) {
	clientSet, err := getClientset()
	if err != nil {
		return nil, fmt.Errorf("failed to get clientset: %v", err)
	}

	containerGetter := RealContainerGetter{
		nodeName:  nodeName,
		clientSet: clientSet,
	}

	return &containerGetter, nil
}

func (c *RealContainerGetter) GetContainers(
	ctx context.Context,
	selectorNamespace string,
	selectorPods metav1.LabelSelector,
	selectorContainerNames *[]string,
	logger logr.Logger) (*[]ContainerInfo, error) {

	// Get the list of pods that match the selector.
	podList, err := c.getPodsForNode(ctx, selectorNamespace, selectorPods)
	if err != nil {
		return nil, fmt.Errorf("failed to get pod list: %v", err)
	}

	// Get the list of containers in the list of pods that match the selector.
	containerList, err := getContainerInfo(podList, selectorContainerNames, logger)
	if err != nil {
		return nil, fmt.Errorf("failed to get container info: %v", err)
	}

	logger.V(1).Info("from getContainerInfo", "containers", containerList)

	return containerList, nil
}

// getPodsForNode returns a list of pods on the given node that match the given
// container selector.
func (c *RealContainerGetter) getPodsForNode(
	ctx context.Context,
	selectorNamespace string,
	selectorPods metav1.LabelSelector,
) (*v1.PodList, error) {

	selectorString := metav1.FormatLabelSelector(&selectorPods)

	if selectorString == "<error>" {
		return nil, fmt.Errorf("error parsing selector: %v", selectorString)
	}

	listOptions := metav1.ListOptions{
		FieldSelector: "spec.nodeName=" + c.nodeName,
	}

	if selectorString != "<none>" {
		listOptions.LabelSelector = selectorString
	}

	podList, err := c.clientSet.CoreV1().Pods(selectorNamespace).List(ctx, listOptions)
	if err != nil {
		return nil, fmt.Errorf("error getting pod list: %v", err)
	}

	return podList, nil
}

// getContainerInfo returns a list of containerInfo for the given pod list and container names.
func getContainerInfo(podList *v1.PodList, containerNames *[]string, logger logr.Logger) (*[]ContainerInfo, error) {

	crictl := "/usr/local/bin/crictl"

	containers := []ContainerInfo{}

	for i, pod := range podList.Items {
		logger.V(1).Info("Pod", "index", i, "Name", pod.Name, "Namespace", pod.Namespace, "NodeName", pod.Spec.NodeName)

		// Find the unique Pod ID of the given pod.
		cmd := exec.Command(crictl, "pods", "--name", pod.Name, "-o", "json")
		podInfo, err := cmd.Output()
		if err != nil {
			logger.Info("Failed to get pod info", "error", err)
			return nil, err
		}

		// The crictl --name option works like a grep on the names of pods.
		// Since we are using the unique name of the pod generated by k8s, we
		// will most likely only get one pod. Though very unlikely, it is
		// technically possible that this unique name is a substring of another
		// pod name. If that happens, we would get multiple pods, so we handle
		// that possibility with the following for loop.
		var podId string
		podFound := false
		for podIndex := 0; ; podIndex++ {
			indexString := "[" + strconv.Itoa(podIndex) + "]"
			podId, err = jsonparser.GetString(podInfo, "items", indexString, "id")
			if err != nil {
				// We hit the end of the list of pods and didn't find it.  This
				// should only happen if the pod was deleted between the time we
				// got the list of pods and the time we got the info about the
				// pod.
				break
			}
			podName, err := jsonparser.GetString(podInfo, "items", indexString, "metadata", "name")
			if err != nil {
				// We shouldn't get an error here if we didn't get an error
				// above, but just in case...
				logger.Error(err, "Error getting pod name")
				break
			}

			if podName == pod.Name {
				podFound = true
				break
			}
		}

		if !podFound {
			return nil, fmt.Errorf("pod %s not found in crictl pod list", pod.Name)
		}

		logger.V(1).Info("podFound", "podId", podId, "err", err)

		// Get info about the containers in the pod so we can get their unique IDs.
		cmd = exec.Command(crictl, "ps", "--pod", podId, "-o", "json")
		containerData, err := cmd.Output()
		if err != nil {
			logger.Info("Failed to get container info", "error", err)
			return nil, err
		}

		// For each container in the pod...
		for containerIndex := 0; ; containerIndex++ {

			indexString := "[" + strconv.Itoa(containerIndex) + "]"

			// Make sure the container name is in the list of containers we want.
			containerName, err := jsonparser.GetString(containerData, "containers", indexString, "metadata", "name")
			if err != nil {
				break
			}

			if containerNames != nil &&
				len(*containerNames) > 0 &&
				!slices.Contains((*containerNames), containerName) {
				continue
			}

			// If it is in the list, get the container ID.
			containerId, err := jsonparser.GetString(containerData, "containers", indexString, "id")
			if err != nil {
				break
			}

			// Now use the container ID to get more info about the container so
			// we can get the PID.
			cmd = exec.Command(crictl, "inspect", "-o", "json", containerId)
			containerData, err := cmd.Output()
			if err != nil {
				logger.Info("Failed to get container data", "error", err)
				continue
			}
			containerPid, err := jsonparser.GetInt(containerData, "info", "pid")
			if err != nil {
				logger.Info("Failed to get container PID", "error", err)
				continue
			}

			container := ContainerInfo{
				podName:       pod.Name,
				containerName: containerName,
				pid:           containerPid,
			}

			containers = append(containers, container)
		}

	}

	return &containers, nil
}

// Check if the annotation is set to indicate that no containers on this node
// matched the container selector.
func noContainersOnNode[T BpfProg](bpfProgram *T, annotationIndex string) bool {
	if bpfProgram == nil {
		return false
	}

	annotations := (*bpfProgram).GetAnnotations()
	noContainersOnNode, ok := annotations[annotationIndex]
	if ok && noContainersOnNode == "true" {
		return true
	}

	return false
}

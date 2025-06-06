/*
Copyright 2025 The bpfman Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Code generated by client-gen. DO NOT EDIT.

package fake

import (
	"context"

	v1alpha1 "github.com/bpfman/bpfman-operator/apis/v1alpha1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	labels "k8s.io/apimachinery/pkg/labels"
	types "k8s.io/apimachinery/pkg/types"
	watch "k8s.io/apimachinery/pkg/watch"
	testing "k8s.io/client-go/testing"
)

// FakeClusterBpfApplications implements ClusterBpfApplicationInterface
type FakeClusterBpfApplications struct {
	Fake *FakeBpfmanV1alpha1
}

var clusterbpfapplicationsResource = v1alpha1.SchemeGroupVersion.WithResource("clusterbpfapplications")

var clusterbpfapplicationsKind = v1alpha1.SchemeGroupVersion.WithKind("ClusterBpfApplication")

// Get takes name of the clusterBpfApplication, and returns the corresponding clusterBpfApplication object, and an error if there is any.
func (c *FakeClusterBpfApplications) Get(ctx context.Context, name string, options v1.GetOptions) (result *v1alpha1.ClusterBpfApplication, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootGetAction(clusterbpfapplicationsResource, name), &v1alpha1.ClusterBpfApplication{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.ClusterBpfApplication), err
}

// List takes label and field selectors, and returns the list of ClusterBpfApplications that match those selectors.
func (c *FakeClusterBpfApplications) List(ctx context.Context, opts v1.ListOptions) (result *v1alpha1.ClusterBpfApplicationList, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootListAction(clusterbpfapplicationsResource, clusterbpfapplicationsKind, opts), &v1alpha1.ClusterBpfApplicationList{})
	if obj == nil {
		return nil, err
	}

	label, _, _ := testing.ExtractFromListOptions(opts)
	if label == nil {
		label = labels.Everything()
	}
	list := &v1alpha1.ClusterBpfApplicationList{ListMeta: obj.(*v1alpha1.ClusterBpfApplicationList).ListMeta}
	for _, item := range obj.(*v1alpha1.ClusterBpfApplicationList).Items {
		if label.Matches(labels.Set(item.Labels)) {
			list.Items = append(list.Items, item)
		}
	}
	return list, err
}

// Watch returns a watch.Interface that watches the requested clusterBpfApplications.
func (c *FakeClusterBpfApplications) Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error) {
	return c.Fake.
		InvokesWatch(testing.NewRootWatchAction(clusterbpfapplicationsResource, opts))
}

// Create takes the representation of a clusterBpfApplication and creates it.  Returns the server's representation of the clusterBpfApplication, and an error, if there is any.
func (c *FakeClusterBpfApplications) Create(ctx context.Context, clusterBpfApplication *v1alpha1.ClusterBpfApplication, opts v1.CreateOptions) (result *v1alpha1.ClusterBpfApplication, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootCreateAction(clusterbpfapplicationsResource, clusterBpfApplication), &v1alpha1.ClusterBpfApplication{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.ClusterBpfApplication), err
}

// Update takes the representation of a clusterBpfApplication and updates it. Returns the server's representation of the clusterBpfApplication, and an error, if there is any.
func (c *FakeClusterBpfApplications) Update(ctx context.Context, clusterBpfApplication *v1alpha1.ClusterBpfApplication, opts v1.UpdateOptions) (result *v1alpha1.ClusterBpfApplication, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootUpdateAction(clusterbpfapplicationsResource, clusterBpfApplication), &v1alpha1.ClusterBpfApplication{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.ClusterBpfApplication), err
}

// UpdateStatus was generated because the type contains a Status member.
// Add a +genclient:noStatus comment above the type to avoid generating UpdateStatus().
func (c *FakeClusterBpfApplications) UpdateStatus(ctx context.Context, clusterBpfApplication *v1alpha1.ClusterBpfApplication, opts v1.UpdateOptions) (*v1alpha1.ClusterBpfApplication, error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootUpdateSubresourceAction(clusterbpfapplicationsResource, "status", clusterBpfApplication), &v1alpha1.ClusterBpfApplication{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.ClusterBpfApplication), err
}

// Delete takes name of the clusterBpfApplication and deletes it. Returns an error if one occurs.
func (c *FakeClusterBpfApplications) Delete(ctx context.Context, name string, opts v1.DeleteOptions) error {
	_, err := c.Fake.
		Invokes(testing.NewRootDeleteActionWithOptions(clusterbpfapplicationsResource, name, opts), &v1alpha1.ClusterBpfApplication{})
	return err
}

// DeleteCollection deletes a collection of objects.
func (c *FakeClusterBpfApplications) DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error {
	action := testing.NewRootDeleteCollectionAction(clusterbpfapplicationsResource, listOpts)

	_, err := c.Fake.Invokes(action, &v1alpha1.ClusterBpfApplicationList{})
	return err
}

// Patch applies the patch and returns the patched clusterBpfApplication.
func (c *FakeClusterBpfApplications) Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v1alpha1.ClusterBpfApplication, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootPatchSubresourceAction(clusterbpfapplicationsResource, name, pt, data, subresources...), &v1alpha1.ClusterBpfApplication{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.ClusterBpfApplication), err
}

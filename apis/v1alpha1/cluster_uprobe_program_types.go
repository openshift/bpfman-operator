/*
Copyright 2023 The bpfman Authors.

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

// All fields are required unless explicitly marked optional
// +kubebuilder:validation:Required
package v1alpha1

// ClUprobeProgramInfo contains the information for the uprobe program
type ClUprobeProgramInfo struct {
	// The list of points to which the program should be attached.  The list items
	// are optional and may be udated after the bpf program has been loaded
	// +optional
	// +kubebuilder:default:={}
	Links []ClUprobeAttachInfo `json:"links"`
}

type ClUprobeAttachInfo struct {
	// Function to attach the uprobe to.
	// +optional
	Function string `json:"function"`

	// Offset added to the address of the function for uprobe.
	// +optional
	// +kubebuilder:default:=0
	Offset uint64 `json:"offset"`

	// Library name or the absolute path to a binary or library.
	Target string `json:"target"`

	// Only execute uprobe for given process identification number (PID). If PID
	// is not provided, uprobe executes for all PIDs.
	// +optional
	Pid *int32 `json:"pid"`

	// Containers identifies the set of containers in which to attach the
	// uprobe. If Containers is not specified, the uprobe will be attached in
	// the bpfman-agent container.
	// +optional
	Containers *ClContainerSelector `json:"containers"`
}

type ClUprobeProgramInfoState struct {
	// List of attach points for the BPF program on the given node. Each entry
	// in *AttachInfoState represents a specific, unique attach point that is
	// derived from *AttachInfo by fully expanding any selectors.  Each entry
	// also contains information about the attach point required by the
	// reconciler
	// +optional
	// +kubebuilder:default:={}
	Links []ClUprobeAttachInfoState `json:"links"`
}

type ClUprobeAttachInfoState struct {
	AttachInfoStateCommon `json:",inline"`

	// Function to attach the uprobe to.
	// +optional
	Function string `json:"function"`

	// Offset added to the address of the function for uprobe.
	// +optional
	// +kubebuilder:default:=0
	Offset uint64 `json:"offset"`

	// Library name or the absolute path to a binary or library.
	Target string `json:"target"`

	// Only execute uprobe for given process identification number (PID). If PID
	// is not provided, uprobe executes for all PIDs.
	// +optional
	Pid *int32 `json:"pid"`

	// Optional container pid to attach the uprobe program in.
	// +optional
	ContainerPid *int32 `json:"containerPid"`
}

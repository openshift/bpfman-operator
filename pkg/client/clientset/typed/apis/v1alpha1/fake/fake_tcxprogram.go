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

// FakeTcxPrograms implements TcxProgramInterface
type FakeTcxPrograms struct {
	Fake *FakeBpfmanV1alpha1
}

var tcxprogramsResource = v1alpha1.SchemeGroupVersion.WithResource("tcxprograms")

var tcxprogramsKind = v1alpha1.SchemeGroupVersion.WithKind("TcxProgram")

// Get takes name of the tcxProgram, and returns the corresponding tcxProgram object, and an error if there is any.
func (c *FakeTcxPrograms) Get(ctx context.Context, name string, options v1.GetOptions) (result *v1alpha1.TcxProgram, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootGetAction(tcxprogramsResource, name), &v1alpha1.TcxProgram{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.TcxProgram), err
}

// List takes label and field selectors, and returns the list of TcxPrograms that match those selectors.
func (c *FakeTcxPrograms) List(ctx context.Context, opts v1.ListOptions) (result *v1alpha1.TcxProgramList, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootListAction(tcxprogramsResource, tcxprogramsKind, opts), &v1alpha1.TcxProgramList{})
	if obj == nil {
		return nil, err
	}

	label, _, _ := testing.ExtractFromListOptions(opts)
	if label == nil {
		label = labels.Everything()
	}
	list := &v1alpha1.TcxProgramList{ListMeta: obj.(*v1alpha1.TcxProgramList).ListMeta}
	for _, item := range obj.(*v1alpha1.TcxProgramList).Items {
		if label.Matches(labels.Set(item.Labels)) {
			list.Items = append(list.Items, item)
		}
	}
	return list, err
}

// Watch returns a watch.Interface that watches the requested tcxPrograms.
func (c *FakeTcxPrograms) Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error) {
	return c.Fake.
		InvokesWatch(testing.NewRootWatchAction(tcxprogramsResource, opts))
}

// Create takes the representation of a tcxProgram and creates it.  Returns the server's representation of the tcxProgram, and an error, if there is any.
func (c *FakeTcxPrograms) Create(ctx context.Context, tcxProgram *v1alpha1.TcxProgram, opts v1.CreateOptions) (result *v1alpha1.TcxProgram, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootCreateAction(tcxprogramsResource, tcxProgram), &v1alpha1.TcxProgram{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.TcxProgram), err
}

// Update takes the representation of a tcxProgram and updates it. Returns the server's representation of the tcxProgram, and an error, if there is any.
func (c *FakeTcxPrograms) Update(ctx context.Context, tcxProgram *v1alpha1.TcxProgram, opts v1.UpdateOptions) (result *v1alpha1.TcxProgram, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootUpdateAction(tcxprogramsResource, tcxProgram), &v1alpha1.TcxProgram{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.TcxProgram), err
}

// UpdateStatus was generated because the type contains a Status member.
// Add a +genclient:noStatus comment above the type to avoid generating UpdateStatus().
func (c *FakeTcxPrograms) UpdateStatus(ctx context.Context, tcxProgram *v1alpha1.TcxProgram, opts v1.UpdateOptions) (*v1alpha1.TcxProgram, error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootUpdateSubresourceAction(tcxprogramsResource, "status", tcxProgram), &v1alpha1.TcxProgram{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.TcxProgram), err
}

// Delete takes name of the tcxProgram and deletes it. Returns an error if one occurs.
func (c *FakeTcxPrograms) Delete(ctx context.Context, name string, opts v1.DeleteOptions) error {
	_, err := c.Fake.
		Invokes(testing.NewRootDeleteActionWithOptions(tcxprogramsResource, name, opts), &v1alpha1.TcxProgram{})
	return err
}

// DeleteCollection deletes a collection of objects.
func (c *FakeTcxPrograms) DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error {
	action := testing.NewRootDeleteCollectionAction(tcxprogramsResource, listOpts)

	_, err := c.Fake.Invokes(action, &v1alpha1.TcxProgramList{})
	return err
}

// Patch applies the patch and returns the patched tcxProgram.
func (c *FakeTcxPrograms) Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v1alpha1.TcxProgram, err error) {
	obj, err := c.Fake.
		Invokes(testing.NewRootPatchSubresourceAction(tcxprogramsResource, name, pt, data, subresources...), &v1alpha1.TcxProgram{})
	if obj == nil {
		return nil, err
	}
	return obj.(*v1alpha1.TcxProgram), err
}

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

package v1alpha1

import (
	"context"
	"time"

	v1alpha1 "github.com/bpfman/bpfman-operator/apis/v1alpha1"
	scheme "github.com/bpfman/bpfman-operator/pkg/client/clientset/scheme"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	types "k8s.io/apimachinery/pkg/types"
	watch "k8s.io/apimachinery/pkg/watch"
	rest "k8s.io/client-go/rest"
)

// BpfNsApplicationsGetter has a method to return a BpfNsApplicationInterface.
// A group's client should implement this interface.
type BpfNsApplicationsGetter interface {
	BpfNsApplications(namespace string) BpfNsApplicationInterface
}

// BpfNsApplicationInterface has methods to work with BpfNsApplication resources.
type BpfNsApplicationInterface interface {
	Create(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.CreateOptions) (*v1alpha1.BpfNsApplication, error)
	Update(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.UpdateOptions) (*v1alpha1.BpfNsApplication, error)
	UpdateStatus(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.UpdateOptions) (*v1alpha1.BpfNsApplication, error)
	Delete(ctx context.Context, name string, opts v1.DeleteOptions) error
	DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error
	Get(ctx context.Context, name string, opts v1.GetOptions) (*v1alpha1.BpfNsApplication, error)
	List(ctx context.Context, opts v1.ListOptions) (*v1alpha1.BpfNsApplicationList, error)
	Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error)
	Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v1alpha1.BpfNsApplication, err error)
	BpfNsApplicationExpansion
}

// bpfNsApplications implements BpfNsApplicationInterface
type bpfNsApplications struct {
	client rest.Interface
	ns     string
}

// newBpfNsApplications returns a BpfNsApplications
func newBpfNsApplications(c *BpfmanV1alpha1Client, namespace string) *bpfNsApplications {
	return &bpfNsApplications{
		client: c.RESTClient(),
		ns:     namespace,
	}
}

// Get takes name of the bpfNsApplication, and returns the corresponding bpfNsApplication object, and an error if there is any.
func (c *bpfNsApplications) Get(ctx context.Context, name string, options v1.GetOptions) (result *v1alpha1.BpfNsApplication, err error) {
	result = &v1alpha1.BpfNsApplication{}
	err = c.client.Get().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		Name(name).
		VersionedParams(&options, scheme.ParameterCodec).
		Do(ctx).
		Into(result)
	return
}

// List takes label and field selectors, and returns the list of BpfNsApplications that match those selectors.
func (c *bpfNsApplications) List(ctx context.Context, opts v1.ListOptions) (result *v1alpha1.BpfNsApplicationList, err error) {
	var timeout time.Duration
	if opts.TimeoutSeconds != nil {
		timeout = time.Duration(*opts.TimeoutSeconds) * time.Second
	}
	result = &v1alpha1.BpfNsApplicationList{}
	err = c.client.Get().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		VersionedParams(&opts, scheme.ParameterCodec).
		Timeout(timeout).
		Do(ctx).
		Into(result)
	return
}

// Watch returns a watch.Interface that watches the requested bpfNsApplications.
func (c *bpfNsApplications) Watch(ctx context.Context, opts v1.ListOptions) (watch.Interface, error) {
	var timeout time.Duration
	if opts.TimeoutSeconds != nil {
		timeout = time.Duration(*opts.TimeoutSeconds) * time.Second
	}
	opts.Watch = true
	return c.client.Get().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		VersionedParams(&opts, scheme.ParameterCodec).
		Timeout(timeout).
		Watch(ctx)
}

// Create takes the representation of a bpfNsApplication and creates it.  Returns the server's representation of the bpfNsApplication, and an error, if there is any.
func (c *bpfNsApplications) Create(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.CreateOptions) (result *v1alpha1.BpfNsApplication, err error) {
	result = &v1alpha1.BpfNsApplication{}
	err = c.client.Post().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(bpfNsApplication).
		Do(ctx).
		Into(result)
	return
}

// Update takes the representation of a bpfNsApplication and updates it. Returns the server's representation of the bpfNsApplication, and an error, if there is any.
func (c *bpfNsApplications) Update(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.UpdateOptions) (result *v1alpha1.BpfNsApplication, err error) {
	result = &v1alpha1.BpfNsApplication{}
	err = c.client.Put().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		Name(bpfNsApplication.Name).
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(bpfNsApplication).
		Do(ctx).
		Into(result)
	return
}

// UpdateStatus was generated because the type contains a Status member.
// Add a +genclient:noStatus comment above the type to avoid generating UpdateStatus().
func (c *bpfNsApplications) UpdateStatus(ctx context.Context, bpfNsApplication *v1alpha1.BpfNsApplication, opts v1.UpdateOptions) (result *v1alpha1.BpfNsApplication, err error) {
	result = &v1alpha1.BpfNsApplication{}
	err = c.client.Put().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		Name(bpfNsApplication.Name).
		SubResource("status").
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(bpfNsApplication).
		Do(ctx).
		Into(result)
	return
}

// Delete takes name of the bpfNsApplication and deletes it. Returns an error if one occurs.
func (c *bpfNsApplications) Delete(ctx context.Context, name string, opts v1.DeleteOptions) error {
	return c.client.Delete().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		Name(name).
		Body(&opts).
		Do(ctx).
		Error()
}

// DeleteCollection deletes a collection of objects.
func (c *bpfNsApplications) DeleteCollection(ctx context.Context, opts v1.DeleteOptions, listOpts v1.ListOptions) error {
	var timeout time.Duration
	if listOpts.TimeoutSeconds != nil {
		timeout = time.Duration(*listOpts.TimeoutSeconds) * time.Second
	}
	return c.client.Delete().
		Namespace(c.ns).
		Resource("bpfnsapplications").
		VersionedParams(&listOpts, scheme.ParameterCodec).
		Timeout(timeout).
		Body(&opts).
		Do(ctx).
		Error()
}

// Patch applies the patch and returns the patched bpfNsApplication.
func (c *bpfNsApplications) Patch(ctx context.Context, name string, pt types.PatchType, data []byte, opts v1.PatchOptions, subresources ...string) (result *v1alpha1.BpfNsApplication, err error) {
	result = &v1alpha1.BpfNsApplication{}
	err = c.client.Patch(pt).
		Namespace(c.ns).
		Resource("bpfnsapplications").
		Name(name).
		SubResource(subresources...).
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(data).
		Do(ctx).
		Into(result)
	return
}

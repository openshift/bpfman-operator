# OpenShift Distribution Tools

Scripts that transform upstream bpfman-operator for Red Hat OpenShift.

## What these do

The scripts change upstream bundles to work in OpenShift:

- Replace Quay.io images with Red Hat registry images
- Add Red Hat branding to operator metadata
- Add architecture labels so OLM knows what platforms work (amd64, arm64, ppc64le, s390x)
- Add OpenShift-specific annotations for disconnected environments and FIPS

## Why here?

These scripts live in `hack/openshift/` because they're only used for Red Hat's downstream builds. They work with Konflux (Red Hat's build system) and don't affect upstream development.

## The scripts

### `update-bundle.py`
Changes the ClusterServiceVersion file to use Red Hat images and adds OpenShift metadata.

```bash
./hack/openshift/update-bundle.py \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec <operator-image>
```

### `update-configmap.py`
Replaces image references in the ConfigMap with Red Hat registry images.

```bash
./hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec <agent-image> \
  --bpfman-pullspec <daemon-image>
```


### `OPENSHIFT-VERSION`
Contains the version number used for OpenShift builds. All OpenShift-specific Containerfiles use this value via a build argument (`BUILDVERSION`). Update this file when preparing a new release:

```bash
echo "BUILDVERSION=0.5.7" > OPENSHIFT-VERSION
```

The Containerfiles read this at build time using `--build-arg-file OPENSHIFT-VERSION`.

### `Makefile`
Test the transformations locally:
- `transform-bundle` - Test bundle transformation
- `transform-bundle-container` - Build bundle container with transformations
- `transform-configmap` - Test ConfigMap transformation
- `transform-catalog` - Test catalog transformation
- `transform-catalog-container` - Build catalog container with transformations
- `transform-all-container` - Build all containers with transformations
- `generate-rpm-lockfile` - Generate rpms.lock.yaml for Konflux builds
- `format` - Format Python files with Black
- `format-check` - Check Python formatting

## How Konflux uses these

### Image files
Konflux updates these files in `konflux/images/` when new images are built:

- `bpfman-operator.txt` - Operator image
- `bpfman-agent.txt` - Agent image
- `bpfman.txt` - Daemon image

The `.tekton` pipelines know about these files through `build-nudge-files` annotations.

### During builds
Container builds read the image references from those files:

```dockerfile
RUN hack/openshift/update-bundle.py \
    --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
    --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"
```

This way Konflux can update images without changing the build scripts.

## Testing locally

Run the transformations without building containers:

```bash
# Show available targets
make

# Run specific transformations
make transform-bundle
make transform-configmap
```

From the project root:

```bash
make -C hack/openshift/ transform-bundle
```

Or run the scripts directly:

```bash
# Bundle transformation
hack/openshift/update-bundle.py \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"

# ConfigMap transformation
hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec "$(cat hack/openshift/konflux/images/bpfman-agent.txt)" \
  --bpfman-pullspec "$(cat hack/openshift/konflux/images/bpfman.txt)"
```

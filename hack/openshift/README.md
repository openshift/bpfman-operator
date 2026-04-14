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
Changes the ClusterServiceVersion file to use Red Hat images and adds OpenShift metadata. Also builds the `relatedImages` section for disconnected environment support.

```bash
./hack/openshift/update-bundle.py \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec <operator-image> \
  --agent-pullspec <agent-image> \
  --bpfman-pullspec <bpfman-image> \
  --csi-pullspec <csi-node-driver-registrar-image> \
  --version <version>
```

The `--agent-pullspec`, `--bpfman-pullspec`, and `--csi-pullspec` arguments are optional but recommended for building the `relatedImages` section that OLM uses for disconnected environments.

### `update-configmap.py`
Replaces image references in the ConfigMap with Red Hat registry images.

```bash
./hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec <agent-image> \
  --bpfman-pullspec <daemon-image>
```


### `OPENSHIFT-VERSION`
Contains build-time configuration for OpenShift builds:

- `BUILDVERSION` - Operator version for CSV metadata
- `CSI_NODE_DRIVER_REGISTRAR_IMAGE` - Red Hat CSI image SHA-pinned reference (we don't build this image)

```bash
BUILDVERSION=0.6.0
CSI_NODE_DRIVER_REGISTRAR_IMAGE=registry.redhat.io/openshift4/ose-csi-node-driver-registrar-rhel9@sha256:...
```

The Containerfiles read these values at build time using `--build-arg-file OPENSHIFT-VERSION`. The CSI image is a Red Hat-provided image, not built by Konflux, so it's SHA-pinned here for security and reproducibility.

### `Makefile`
Test the transformations locally:
- `build-operator-container` - Build operator container with Red Hat CSI image
- `build-bundle-container` - Build bundle container with transformations
- `transform-bundle` - Test bundle transformation
- `transform-configmap` - Test ConfigMap transformation
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
  --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)" \
  --version "$(grep BUILDVERSION OPENSHIFT-VERSION | cut -d= -f2)"

# ConfigMap transformation
hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec "$(cat hack/openshift/konflux/images/bpfman-agent.txt)" \
  --bpfman-pullspec "$(cat hack/openshift/konflux/images/bpfman.txt)"
```

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

### `update-catalog.sh`
Updates the catalog index to point to Red Hat images and sets timestamps.

```bash
./hack/openshift/update-catalog.sh \
  --index-file catalog/index.yaml \
  --bundle-pullspec <bundle-image> \
  --operator-pullspec <operator-image>
```

### `sync-version.sh`
Synchronises the VERSION value from the repository root to all OpenShift-specific Containerfiles. The version information in OpenShift Containerfiles is stored as literal values in LABEL instructions (not dynamically read from the VERSION file), so this script updates those literal values to match the upstream VERSION.

Run this after merging from upstream when the VERSION file changes:

```bash
make -C hack/openshift set-version
```

### `Makefile`
Test the transformations locally:
- `transform-bundle` - Test bundle transformation
- `transform-bundle-container` - Build bundle container with transformations
- `transform-configmap` - Test ConfigMap transformation
- `transform-catalog` - Test catalog transformation
- `transform-catalog-container` - Build catalog container with transformations
- `transform-all-container` - Build all containers with transformations
- `set-version` - Copy VERSION value and replace in OpenShift Containerfiles
- `generate-rpm-lockfile` - Generate rpms.lock.yaml for Konflux builds
- `format` - Format Python files with Black
- `format-check` - Check Python formatting

## How Konflux uses these

### Image files
Konflux updates these files in `konflux/images/` when new images are built:

- `bpfman-operator.txt` - Operator image
- `bpfman-operator-bundle.txt` - Bundle image
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
make transform-catalog
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

# Catalog transformation
hack/openshift/update-catalog.sh \
  --index-file catalog/index.yaml \
  --bundle-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator-bundle.txt)" \
  --operator-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"
```

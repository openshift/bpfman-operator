# OpenShift Distribution Tools

This directory contains tooling specific to the OpenShift downstream distribution of bpfman-operator.

## Purpose

These tools transform upstream bpfman-operator bundles for Red Hat OpenShift distribution by:

- **Rebranding**: Updates display names, provider information, and descriptions for Red Hat
- **Image references**: Replaces upstream Quay.io images with Red Hat registry images
- **Architecture support**: Adds Operator Framework architecture labels (`operatorframework.io/arch.*`) for amd64, arm64, ppc64le, and s390x to inform OLM which platforms the operator supports
- **OpenShift features**: Adds annotations for disconnected environments, FIPS compliance, etc.

## Why Separated?

This tooling is isolated under `hack/openshift/` because:

1. **Downstream-specific**: Only relevant for Red Hat's OpenShift distribution
2. **Konflux integration**: Designed to work with Red Hat's Konflux build system
3. **Clear scope**: Separates upstream development from downstream customisation
4. **Maintainability**: Keeps transformation logic organised and discoverable

## Tools

### `update-bundle.py`
Transforms ClusterServiceVersion (CSV) files with:
- Red Hat branding and provider information
- Operator Framework architecture labels (`operatorframework.io/arch.*` and `operatorframework.io/os.*`)
- OpenShift feature annotations (`features.operators.openshift.io/*`)
- Red Hat image references for operator deployments
- Environment variable image updates

Usage:
```bash
./hack/openshift/update-bundle.py \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec <operator-image>
```

### `update-configmap.py`
Updates ConfigMap files with Red Hat image references for:
- bpfman daemon image
- bpfman-agent image
- Validates and preserves YAML structure

Usage:
```bash
./hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec <agent-image> \
  --bpfman-pullspec <daemon-image>
```

### `update-catalog.sh`
Updates catalog index files with Red Hat image references and timestamps:
- Bundle image references (`registry.redhat.io/bpfman/bpfman-operator-bundle@*`)
- Operator image references in CSV annotations
- CreatedAt timestamps to current time
- Validates YAML structure and preserves formatting

Usage:
```bash
./hack/openshift/update-catalog.sh \
  --index-file catalog/index.yaml \
  --bundle-pullspec <bundle-image> \
  --operator-pullspec <operator-image>
```

### `Makefile`
Provides convenient targets for testing transformations:
- `transform-bundle` - Test bundle CSV transformation
- `transform-configmap` - Test ConfigMap transformation
- `transform-catalog` - Test catalog transformation  
- `transform-all` - Run all transformations
- `container-transform-catalog` - Build catalog container with transformations

## Konflux Integration

### Image Reference Files
The `konflux/images/` directory contains discrete files that are updated by Konflux's build-nudging process:

- `bpfman-operator.txt` - Operator image pullspec
- `bpfman-operator-bundle.txt` - Bundle image pullspec
- `bpfman-agent.txt` - Agent image pullspec
- `bpfman.txt` - Daemon image pullspec

These files are referenced in `.tekton` pipeline files under `build-nudge-files` annotations.

### Build Process
During container builds, the tools read image references from these files:

```dockerfile
RUN hack/openshift/update-bundle.py \
    --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
    --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"
```

This decouples image references from build logic, enabling Konflux to manage image updates automatically whilst keeping transformation code static.

## Local Testing

Test the tools locally without container builds using the provided Makefile targets:

```bash
# Test bundle transformation
make transform-bundle

# Test configmap transformation
make transform-configmap

# Test catalog transformation
make transform-catalog

# Test all transformations
make transform-all
```

From the project root, you can also run:

```bash
# Test from project root using -C flag
make -C hack/openshift/ transform-all
```

Or run the commands directly:

```bash
# Test bundle transformation
hack/openshift/update-bundle.py \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"

# Test configmap transformation
hack/openshift/update-configmap.py \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec "$(cat hack/openshift/konflux/images/bpfman-agent.txt)" \
  --bpfman-pullspec "$(cat hack/openshift/konflux/images/bpfman.txt)"

# Test catalog transformation
hack/openshift/update-catalog.sh \
  --index-file catalog/index.yaml \
  --bundle-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator-bundle.txt)" \
  --operator-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"
```

The transformation tools are kept separate from the image references they consume. This makes local testing straightforward and allows Konflux to update images without touching the build logic.

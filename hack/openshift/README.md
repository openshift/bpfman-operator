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

### `update_bundle.go`
Transforms ClusterServiceVersion (CSV) files with:
- Red Hat branding and provider information
- Operator Framework architecture labels (`operatorframework.io/arch.*` and `operatorframework.io/os.*`)
- OpenShift feature annotations (`features.operators.openshift.io/*`)
- Red Hat image references

Usage:
```bash
go run update_bundle.go --csv-file input.yaml --image-pullspec <operator-image>
```

### `update_configmap.go`
Updates ConfigMap files with Red Hat image references for:
- bpfman daemon image
- bpfman-agent image

Usage:
```bash
go run update_configmap.go --configmap-file input.yaml --agent-pullspec <agent-image> --bpfman-pullspec <daemon-image>
```

## Konflux Integration

### Image Reference Files
The `konflux/images/` directory contains discrete files that are updated by Konflux's build-nudging process:

- `bpfman-operator.txt` - Operator image pullspec
- `bpfman-agent.txt` - Agent image pullspec
- `bpfman.txt` - Daemon image pullspec

These files are referenced in `.tekton` pipeline files under `build-nudge-files` annotations.

### Build Process
During container builds, the tools read image references from these files:

```dockerfile
RUN go run hack/openshift/update_bundle.go \
    --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"
```

This decouples image references from build logic, enabling Konflux to manage image updates automatically whilst keeping transformation code static.

## Local Testing

Test the tools locally without container builds:

```bash
# Test bundle transformation
go run hack/openshift/update_bundle.go --dry-run \
  --csv-file bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
  --image-pullspec "$(cat hack/openshift/konflux/images/bpfman-operator.txt)"

# Test configmap transformation
go run hack/openshift/update_configmap.go --dry-run \
  --configmap-file bundle/manifests/bpfman-config_v1_configmap.yaml \
  --agent-pullspec "$(cat hack/openshift/konflux/images/bpfman-agent.txt)" \
  --bpfman-pullspec "$(cat hack/openshift/konflux/images/bpfman.txt)"
```

## Architecture

```
hack/openshift/
├── README.md                    # This file
├── update_bundle.go             # CSV transformation tool
├── update_configmap.go          # ConfigMap transformation tool
└── konflux/
    └── images/                  # Konflux-managed image references
        ├── bpfman-operator.txt  # Operator image pullspec
        ├── bpfman-agent.txt     # Agent image pullspec
        └── bpfman.txt           # Daemon image pullspec
```

The transformation tools are kept separate from the image references they consume. This makes local testing straightforward and allows Konflux to update images without touching the build logic.

## Dependencies

The tooling requires a single external YAML dependency (`gopkg.in/yaml.v3`). Currently, this dependency is satisfied through the project root's `vendor/` directory and `go.{mod,sum}` files.

Should Kubernetes drop YAML support in the future (though this seems unlikely), we would need to create local `go.mod` and `go.sum` files in this directory and vendor the YAML dependency locally.

## Building

To format and build all tools:

```bash
make
```

This will:
1. Format all Go files with `go fmt ./...`  
2. Build all three tools to `/tmp/`:
   - `/tmp/update_configmap`
   - `/tmp/update_bundle` 
   - `/tmp/update_catalog`

# Konflux Image Nudge Files

This directory contains placeholder files that Konflux populates with image
references during the build process. These files are used as "nudge files" to
trigger rebuilds of dependent components when base images are updated.

## Understanding the Nudge System

The Konflux nudge system coordinates component rebuilds when dependencies
change. The terminology can be confusing, so here's the actual flow:

1. **Component A builds** → produces new image with new SHA
2. **Konflux raises a PR** → updates Component A's `.txt` file with the new SHA
3. **PR merges** → the `.txt` file change triggers builds of components that
   have `build.appstudio.openshift.io/build-nudge-files` watching that file

The annotation `build.appstudio.openshift.io/build-nudge-files` means:
**"When these files change (via PR merge), trigger a rebuild of THIS component"**

## The Problem We're Solving

The bpfman-operator manages multiple components that must work together:
- **bpfman**: The Rust eBPF daemon
- **bpfman-agent**: The Go-based Kubernetes agent
- **bpfman-operator**: The operator that orchestrates them

These components need version synchronisation. The operator deploys the agent
and daemon using image references stored in a ConfigMap. When one component
updates, related components must rebuild to maintain compatibility.

## Image Reference Files

- `bpfman.txt` - The bpfman daemon (Rust component) image reference
- `bpfman-agent.txt` - The bpfman-agent (Go component) image reference
- `bpfman-operator.txt` - The bpfman-operator (Go component) image reference

## Build Dependencies and Nudge Relationships

### Why Each Component Rebuilds When It Does

**bpfman-agent** (triggered by: `bpfman.txt`)
- **Not a build dependency!** The agent is built from source code, not from the bpfman image
- **Why it's triggered by bpfman.txt**: Version synchronisation - when the Rust daemon
  updates, the Go agent rebuilds to ensure they remain compatible
- **Result**: The ConfigMap gets a matched set of daemon + agent versions

**bpfman-operator** (triggered by: nothing `""`)
- **Built from source**: Only rebuilds on code changes
- **Why no nudges**: The operator is the base component that deploys the others;
  it doesn't need to rebuild when other images change
- **Doesn't embed other images**: The operator reads the ConfigMap at runtime to
  get daemon/agent image references - it doesn't need them at build time

### Transformation Builds

**operator-bundle** (triggered by: `bpfman-operator.txt`, `bpfman-agent.txt`, `bpfman.txt`)
- **Purpose**: Packages the operator with a ConfigMap containing image references
- **The ConfigMap is critical**: It tells the operator which daemon and agent
  images to deploy at runtime
- **Why it's triggered by all three images**:
  - When operator changes → bundle rebuilds to update ClusterServiceVersion (CSV)
  - When agent changes → bundle rebuilds to update ConfigMap
  - When daemon changes → bundle rebuilds to update ConfigMap
- **Transformations**:
  - `update-bundle.py` updates ClusterServiceVersion (CSV) with operator image
  - `update-configmap.py` updates ConfigMap with agent and daemon images
- **Confirmed by Makefile**: The `bundle` target shows exactly this:
  ```makefile
  # Sets the operator image itself
  $(KUSTOMIZE) edit set image quay.io/bpfman/bpfman-operator=${BPFMAN_OPERATOR_IMG}
  # Updates ConfigMap with daemon and agent images
  $(SED) -e 's@bpfman\.image=.*@bpfman.image=$(BPFMAN_IMG)@' \
         -e 's@bpfman\.agent\.image=.*@bpfman.agent.image=$(BPFMAN_AGENT_IMG)@'
  ```

## Complete Example Flow

Let's trace what happens when the Rust daemon (bpfman) gets updated:

1. **bpfman daemon rebuilt** (e.g., feature of fix)
   - Konflux builds new daemon image → SHA: abc123
   - Konflux raises PR to update `bpfman.txt` with new SHA
   - PR merges

2. **File change triggers rebuilds**:
   - `bpfman.txt` changed → triggers bpfman-agent rebuild (version sync)
   - `bpfman.txt` changed → triggers bundle rebuild (ConfigMap update)

3. **bpfman-agent rebuilds**
   - Built from source (Go code)
   - Produces new image → SHA: def456
   - Konflux raises PR to update `bpfman-agent.txt`
   - PR merges

4. **More rebuilds triggered**:
   - `bpfman-agent.txt` changed → triggers bundle rebuild again

5. **Bundle rebuilds** (may have already started from step 2)
   - Runs `update-configmap.py` with new daemon and agent SHAs
   - ConfigMap now has matched daemon + agent versions
   - Produces new bundle → SHA: ghi789
   - Note: Catalog updates are now managed separately in the bpfman-catalog repository
   - Catalog includes new bundle with updated ConfigMap

**End result**: The operator can now deploy matched versions of the daemon
and agent that are guaranteed to be compatible.

## Managing Component Transitions

When transitioning between component versions or naming conventions, you may need
to disable older components to prevent unnecessary builds and PR generation.

### Legacy Components (ocp-*)

The following legacy components are being replaced by y-stream equivalents:

**In bpfman repository:**
- `ocp-bpfman` → replaced by `bpfman-daemon-ystream`

**In bpfman-operator repository:**
- `ocp-bpfman-agent` → replaced by `bpfman-agent-ystream`
- `ocp-bpfman-operator` → replaced by `bpfman-operator-ystream`
- `ocp-bpfman-operator-bundle` → replaced by `bpfman-operator-bundle-ystream`
- `ocp-bpfman-operator-catalog` → catalog components remain separate per OCP version
- `ocp-bpfman-operator-catalog-ocp4-18`
- `ocp-bpfman-operator-catalog-ocp4-19`
- `ocp-bpfman-operator-catalog-ocp4-20`

### Y-Stream Components

The y-stream components follow the naming pattern `<component>-ystream` and provide:
- Consistent versioning across related components
- Better alignment with downstream release processes
- Simplified pipeline configurations using shared defaults

Current y-stream components:
- `bpfman-daemon-ystream` (built from bpfman repository)
- `bpfman-agent-ystream` (built from bpfman-operator repository)
- `bpfman-operator-ystream` (built from bpfman-operator repository)
- `bpfman-operator-bundle-ystream` (built from bpfman-operator repository)

### Disabling/Enabling Components

To stop Mintmaker from opening PRs for a component (effectively freezing it),
use the `mintmaker.appstudio.redhat.com/disabled` annotation.

**Important**: The mintmaker annotation only prevents Mintmaker from creating
update PRs. It does NOT prevent PipelinesAsCode from triggering builds when
code changes are pushed. To fully disable a component's pipelines, you must
also set the CEL expression to `"false"` in the `.tekton/*.yaml` files.

#### Disable legacy components:
```bash
# Disable ocp-* components in bpfman
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman mintmaker.appstudio.redhat.com/disabled=true

# Disable ocp-* components in bpfman-operator
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-agent mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator-bundle mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator-catalog mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator-catalog-ocp4-18 mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator-catalog-ocp4-19 mintmaker.appstudio.redhat.com/disabled=true
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman-operator-catalog-ocp4-20 mintmaker.appstudio.redhat.com/disabled=true
```

#### Re-enable components (if needed):
To re-enable a component, use the same command with a `-` after `disabled`:
```bash
oc -n ocp-bpfman-tenant annotate component/ocp-bpfman mintmaker.appstudio.redhat.com/disabled-
```

**Note**: This approach is based on the pattern documented by the
[NetObserv team](https://github.com/netobserv/network-observability-operator/blob/main/docs/Konflux.md#freezing-zstream).

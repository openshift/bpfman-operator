# Konflux Image Reference Files and Build Synchronisation

This directory contains image reference files that coordinate component rebuilds through Konflux's nudging system. Understanding how this works requires distinguishing between two complementary mechanisms that work together to prevent race conditions in bundle builds.

## Two Mechanisms Working Together

### 1. Nudging (Creates PRs via `build-nudges-ref`)

When a component finishes building successfully, Konflux's nudging system can create pull requests that update image reference files in other components' repositories.

**Configuration**: Set via the `build-nudges-ref` field on Konflux components:

```bash
oc get component bpfman-daemon-ystream -n ocp-bpfman-tenant -o jsonpath='{.spec.build-nudges-ref}'
# Output: ["bpfman-operator-ystream"]
```

**What this means**: When `bpfman-daemon-ystream` builds successfully, Konflux creates a PR in the `bpfman-operator-ystream` component's repository updating `hack/konflux/images/bpfman.txt` with the new daemon image digest.

**Key point**: This mechanism only **creates PRs**. It does not trigger builds directly.

### 2. CEL Expressions (Trigger Builds on File Changes)

Pipeline definitions (`.tekton/*-push.yaml`) contain CEL expressions that watch for file changes. When a PR merges and changes one of the watched files, PipelinesAsCode triggers a build.

**Example from** `.tekton/bpfman-operator-ystream-push.yaml`:

```yaml
pipelinesascode.tekton.dev/on-cel-expression: event == "push" && target_branch
  == "main" && (...
  || "hack/konflux/images/bpfman-agent.txt".pathChanged()
  || "hack/konflux/images/bpfman.txt".pathChanged())
```

**What this means**: When a PR merges to `main` that changes `bpfman.txt` or `bpfman-agent.txt`, the operator rebuilds automatically.

**Key point**: This mechanism only **triggers builds on file changes**. It does not create PRs.

## Current Configuration (Post-PR #1097)

### The Race Condition Problem

Before PR #1097, components could nudge the bundle directly, causing race conditions:

```
Agent build completes → nudges bundle → bundle builds with new agent + OLD operator
Operator build completes (later) → nudges bundle → bundle builds again
```

This resulted in inconsistent snapshots where the bundle's internal image references didn't match the component versions in the snapshot.

### The Solution: Synchronisation Through Operator

PR #1097 introduced the operator as a synchronisation point to ensure the bundle always builds with complete, consistent image references:

```
Daemon/Agent build completes → nudges operator → operator rebuilds
Operator completes → nudges bundle → bundle builds with all current components
```

### Nudging Relationships (Who Creates PRs for Whom)

```
bpfman-daemon-ystream → bpfman-operator-ystream
bpfman-agent-ystream → bpfman-operator-ystream
bpfman-operator-ystream → bpfman-operator-bundle-ystream
```

This means:
- Daemon builds → Creates PR updating `hack/konflux/images/bpfman.txt` in operator repo
- Agent builds → Creates PR updating `hack/konflux/images/bpfman-agent.txt` in operator repo
- Operator builds → Creates PR updating `hack/konflux/images/bpfman-operator.txt` in operator repo

**Critical insight**: Agent nudging operator appears redundant since both build from the same repository. However, this nudge acts as a **synchronisation barrier**. Even though they build from the same source change, they finish at different times. The agent→operator nudge ensures the operator waits for the agent to complete before triggering the bundle build.

### CEL Expression Watches (What Triggers Rebuilds on Merge)

**bpfman-daemon-ystream**: No CEL watches (external repo, only rebuilt on code changes)

**bpfman-agent-ystream**: No CEL watches (rebuilt on code changes in bpfman-operator repo)

**bpfman-operator-ystream** watches:
- `hack/konflux/images/bpfman-agent.txt` - Ensures operator rebuilds when agent updates
- `hack/konflux/images/bpfman.txt` - Ensures operator rebuilds when daemon updates
- Code changes (`cmd/***`, `controllers/***`, `Containerfile.bpfman-operator.openshift`, etc.)

**bpfman-operator-bundle-ystream** push pipeline watches:
- `hack/konflux/images/bpfman-operator.txt` - ONLY file that triggers bundle push builds
- Bundle manifests, configurations, etc.

**bpfman-operator-bundle-ystream** pull-request pipeline watches:
- `hack/konflux/images/bpfman-operator.txt` - For validating operator changes
- Bundle manifests, configurations, etc.
- **Does NOT watch** `bpfman-agent.txt` or `bpfman.txt` (optimisation from PR #1100)

**Key insight**: The bundle push pipeline only watches `bpfman-operator.txt`. This creates a single trigger point after all components have synchronised through the operator, preventing multiple bundle rebuilds.

## Image Reference Files

- `bpfman.txt` - The bpfman daemon (Rust component from openshift/bpfman repo) image digest
- `bpfman-agent.txt` - The bpfman-agent (Go component from bpfman-operator repo) image digest
- `bpfman-operator.txt` - The bpfman-operator (Go component from bpfman-operator repo) image digest

These files are updated via PRs created by the nudging system and consumed during builds.

## Monorepo Architecture

The bpfman-operator repository contains code for **both** operator and agent components:

```
bpfman-operator repo:
├── cmd/
│   ├── bpfman-operator/main.go  (operator binary)
│   └── bpfman-agent/main.go     (agent binary)
├── controllers/                  (SHARED - reconciliation logic)
├── pkg/                         (SHARED - common packages)
├── apis/                        (SHARED - CRD definitions)
└── vendor/                      (SHARED - dependencies)
```

**Implications**:
- Code changes typically trigger **both** operator and agent to rebuild
- They build from the same commit but finish at different times
- This is why agent→operator nudging is necessary for synchronisation
- The architecture is standard (Kubernetes itself uses this pattern) but Konflux treats them as independent components

## How The Bundle Uses These Files

The bundle build process reads these files to populate the operator's ClusterServiceVersion and ConfigMap with pinned image digests:

```dockerfile
# In Containerfile.bundle.openshift
RUN hack/openshift/update-bundle.py \
    --csv-file /manifests/bpfman-operator.clusterserviceversion.yaml \
    --image-pullspec "$(cat hack/konflux/images/bpfman-operator.txt)"

RUN hack/openshift/update-configmap.py \
    --configmap-file /manifests/bpfman-config_v1_configmap.yaml \
    --agent-pullspec "$(cat hack/konflux/images/bpfman-agent.txt)" \
    --bpfman-pullspec "$(cat hack/konflux/images/bpfman.txt)"
```

The operator reads these values from the ConfigMap at runtime to deploy the daemon and agent with the correct image references.

**Critical insight**: The bundle reads the image reference files **at build time** and embeds them in the manifests. Snapshots aggregate the **latest promoted images** at snapshot creation time. If the bundle builds before all components finish, the bundle's internal references won't match the snapshot's component list.

## Complete Example: Daemon Update Flow

Let's trace what happens when the daemon updates (e.g., PR #333 from openshift/bpfman repo):

### Step 1: Daemon Code Changes → Daemon Builds

**Event**: PR merges in openshift/bpfman repo

**Automatic rebuild** (via CEL expression):
- `bpfman-daemon-ystream-on-push-wwcfx` starts and completes (19m52s)
- New daemon image: `8837d97`

### Step 2: Daemon Nudges Operator

**Nudging system creates PR #1099**:
- Updates `hack/konflux/images/bpfman.txt` to `8837d97`
- PR targets: `bpfman-operator-ystream` repository

### Step 3: PR Merges → Operator Rebuilds

**PR #1099 merges**:
- File changed: `hack/konflux/images/bpfman.txt`
- Operator CEL expression triggers rebuild
- `bpfman-operator-ystream-on-push-z6bwt` completes (4m20s)
- New operator image: `e9fde1b`

### Step 4: Operator Nudges Bundle

**Nudging system creates PR #1101**:
- Updates `hack/konflux/images/bpfman-operator.txt` to `e9fde1b`
- PR targets: `bpfman-operator-bundle-ystream` repository

### Step 5: PR Merges → Bundle Rebuilds

**PR #1101 merges**:
- File changed: `hack/konflux/images/bpfman-operator.txt`
- Bundle CEL expression triggers rebuild
- `bpfman-operator-bundle-ystream-on-push-d6nx2` completes (2m57s)
- New bundle image: `3748f59`

### Step 6: Snapshot Created with Consistent Versions

**Snapshot `tr6nj` created**:
- daemon: `8837d97` ✓ (matches bundle internal reference)
- operator: `e9fde1b` ✓ (matches bundle internal reference)
- agent: `28908e3` ✓ (matches bundle internal reference)
- bundle: `3748f59`

**Result**: Single bundle build with all consistent component references. The operator synchronisation point prevented the race condition where the bundle might have built with old daemon or old operator references.

## Example: Operator/Agent Update Flow

When code changes in the bpfman-operator repository:

### Step 1: Code Changes → Both Components Build

**Event**: PR merges changing shared code (controllers/, pkg/, etc.)

**Parallel rebuilds** (via CEL expressions):
- `bpfman-agent-ystream-on-push-xxxxx` starts
- `bpfman-operator-ystream-on-push-yyyyy` starts

**They may finish in either order**.

### Step 2: Agent Completes First (Typical Case)

**Agent build completes**:
- New agent image: `abc123`
- Nudging system creates PR updating `hack/konflux/images/bpfman-agent.txt`
- PR targets: `bpfman-operator-ystream`

### Step 3: Agent Nudge PR Merges → Operator Rebuilds

**PR merges**:
- File changed: `hack/konflux/images/bpfman-agent.txt`
- Operator CEL expression triggers rebuild
- Operator was already building from step 1, but now rebuilds again

**This appears wasteful but ensures synchronisation**:
- If operator finished before agent (step 1), the rebuild ensures it doesn't nudge bundle yet
- If operator hasn't finished (step 1), the rebuild may be redundant but harmless
- The critical point: operator only nudges bundle after agent completes

### Step 4: Operator Nudges Bundle

**Final operator build completes**:
- New operator image (with agent `abc123` reference via nudge file)
- Nudging system creates PR updating `hack/konflux/images/bpfman-operator.txt`

### Step 5: Bundle Builds Once

**PR merges → Bundle rebuilds**:
- Bundle reads all current image references
- Produces bundle with consistent operator and agent versions

**Result**: One final bundle build after both components synchronise through operator.

## Why This Architecture?

**The Problem**: Konflux treats operator and agent as independent components, but they build from the same repository and finish at unpredictable times.

**Without Synchronisation**:
```
Agent finishes → nudges bundle → bundle builds with new agent + OLD operator
Operator finishes later → nudges bundle → bundle builds again
```

**With Operator Synchronisation (PR #1097)**:
```
Agent finishes → nudges operator → operator waits/rebuilds
Operator finishes → nudges bundle → bundle builds ONCE with both
```

The agent→operator nudge is a **synchronisation primitive**, not redundancy. It ensures the operator acts as a barrier, collecting all component updates before triggering a single bundle build.

## Viewing Current Configuration

```bash
# Show all nudge relationships
oc get components -n ocp-bpfman-tenant -o json | \
  jq -r '.items[] | select(.spec["build-nudges-ref"]) |
  "\(.metadata.name) → \(.spec["build-nudges-ref"] | join(", "))"'

# Check a specific component's nudge targets
oc get component bpfman-daemon-ystream -n ocp-bpfman-tenant \
  -o jsonpath='{.spec.build-nudges-ref}'

# See CEL expressions in pipeline definitions
grep -A 10 "on-cel-expression" .tekton/*-push.yaml

# Check latest promoted images
oc get component bpfman-operator-ystream -n ocp-bpfman-tenant \
  -o jsonpath='{.status.lastPromotedImage}'
```

## Related Pull Requests

- **PR #1097**: Synchronise bundle builds through operator component - Implemented the operator synchronisation point to prevent race conditions
- **PR #1100**: Remove wasteful bundle validation triggers for component nudge files - Optimised PR validation to skip bundle builds for agent/daemon nudge files
- **PR #333**: Test daemon build nudge mechanism - Validated the daemon→operator→bundle flow
- **PR #1102**: Test operator and agent build nudge mechanism - Validates the operator/agent→bundle flow

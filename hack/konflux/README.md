# Konflux Image Reference Files and Nudging

This directory contains image reference files that coordinate component rebuilds through Konflux's nudging system. Understanding how nudging works requires distinguishing between two complementary mechanisms that work together.

## Two Mechanisms Working Together

### 1. Nudging (Creates PRs via `build-nudges-ref`)

When a component finishes building successfully, Konflux's nudging system can create pull requests that update image reference files in other components' repositories.

**Configuration**: Set via the `build-nudges-ref` field on Konflux components:

```bash
oc get component bpfman-agent-ystream -n ocp-bpfman-tenant -o jsonpath='{.spec.build-nudges-ref}'
# Output: ["bpfman-operator-ystream"]
```

**What this means**: When `bpfman-agent-ystream` builds successfully, Konflux creates a PR in the `bpfman-operator-ystream` component's repository updating `hack/konflux/images/bpfman-agent.txt` with the new agent image digest.

**Key point**: This mechanism only **creates PRs**. It does not trigger builds directly.

### 2. CEL Expressions (Trigger Builds on File Changes)

Pipeline definitions (`.tekton/*-push.yaml`) contain CEL expressions that watch for file changes. When a PR merges and changes one of the watched files, PipelinesAsCode triggers a build.

**Example from** `.tekton/bpfman-operator-ystream-push.yaml`:

```yaml
pipelinesascode.tekton.dev/on-cel-expression: event == "push" && target_branch
  == "main" && (...
  || "hack/konflux/images/bpfman.txt".pathChanged()
  || "hack/konflux/images/bpfman-agent.txt".pathChanged())
```

**What this means**: When a PR merges to `main` that changes either `bpfman.txt` or `bpfman-agent.txt`, the operator rebuilds automatically.

**Key point**: This mechanism only **triggers builds on file changes**. It does not create PRs.

## Current Configuration

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

### CEL Expression Watches (What Triggers Rebuilds on Merge)

**bpfman-daemon-ystream**: No CEL watches (only rebuilt on code changes)

**bpfman-agent-ystream**: No CEL watches (only rebuilt on code changes)

**bpfman-operator-ystream** watches:
- `hack/konflux/images/bpfman.txt`
- `hack/konflux/images/bpfman-agent.txt`
- Code changes (`*.go`, `Containerfile.bpfman-operator.openshift`, etc.)

**bpfman-operator-bundle-ystream** watches:
- `hack/konflux/images/bpfman-operator.txt`
- `hack/konflux/images/bpfman-agent.txt` (after PR #969)
- Bundle manifests, configurations, etc.

## Image Reference Files

- `bpfman.txt` - The bpfman daemon (Rust component) image digest
- `bpfman-agent.txt` - The bpfman-agent (Go component) image digest
- `bpfman-operator.txt` - The bpfman-operator (Go component) image digest

These files are updated via PRs created by the nudging system and consumed during builds.

## How The Bundle Uses These Files

The bundle build process reads these files to populate the operator's ConfigMap with pinned image digests:

```bash
# In hack/openshift/update-configmap.py
configmap["data"]["bpfman.agent.image"] = agent_pullspec  # from bpfman-agent.txt
configmap["data"]["bpfman.image"] = bpfman_pullspec      # from bpfman.txt
```

The operator reads these values from the ConfigMap at runtime (see `controllers/bpfman-operator/configmap.go:368,389`) to deploy the daemon and agent with the correct image references.

**Critical insight**: The operator binary does not embed these image references at build time. It reads them from the ConfigMap at runtime. This is why agent/daemon updates don't require operator rebuilds—only bundle rebuilds to update the ConfigMap.

## Complete Example: Base Image Update

Let's trace what happens when PR #964 merged, updating the go-toolset base image in both operator and agent Containerfiles:

### Step 1: Code Changes Trigger Parallel Rebuilds (CEL Expressions)

**Event**: PR merges changing `Containerfile.bpfman-operator.openshift` and `Containerfile.bpfman-agent.openshift`

**Automatic rebuilds** (via CEL expressions watching Containerfiles):
- `bpfman-operator-ystream-on-push-4nqjg` starts (08:58:10Z)
- `bpfman-agent-ystream-on-push-nnn8j` starts (08:58:12Z)

**No PRs created yet**—these are CEL-triggered builds from code changes.

### Step 2: Builds Complete → Nudging Creates PRs

**Agent build completes** (09:08:00Z):
- New agent image: `5137106`
- Nudging system creates **PR #967**: Updates `hack/konflux/images/bpfman-agent.txt`
- PR targets: `bpfman-operator-ystream` (via `build-nudges-ref`)

**Operator build completes** (09:08:00Z):
- New operator image: `f7b1350`
- Nudging system creates **PR #966**: Updates `hack/konflux/images/bpfman-operator.txt`
- PR targets: `bpfman-operator-bundle-ystream` (via `build-nudges-ref`)

### Step 3: PRs Merge → CEL Expressions Trigger Rebuilds

**PR #966 merges** (09:15:03Z):
- File changed: `hack/konflux/images/bpfman-operator.txt`
- Bundle CEL expression sees the change
- **Bundle rebuilds** (09:15:25Z) with operator `f7b1350`

**PR #967 merges** (09:17:51Z):
- File changed: `hack/konflux/images/bpfman-agent.txt`
- Operator CEL expression sees the change
- **Operator rebuilds** (09:18:11Z) with agent `5137106`

### Step 4: Cascade Continues

**Second operator build completes** (09:27:00Z):
- New operator image: `4c6d667` (now includes agent `5137106`)
- Nudging system creates **PR #968**: Updates `hack/konflux/images/bpfman-operator.txt`
- PR targets: `bpfman-operator-bundle-ystream`

**PR #968 merges**:
- Bundle rebuilds with operator `4c6d667`

### The Inefficiency

Notice the operator rebuilt twice:
1. From the original Containerfile change (step 1)
2. From the agent nudge PR merge (step 3)

The second rebuild was unnecessary because the operator doesn't use `bpfman-agent.txt` at build time—only the bundle needs it for the ConfigMap.

**Solution**: PR #969 changes the agent's `build-nudges-ref` to target the bundle directly instead of the operator, eliminating the redundant operator rebuild.

## Example: Agent-Only Update

Let's trace what happens when only the agent code changes (after PR #969 merges):

### Step 1: Code Changes Trigger Agent Build

**Event**: PR merges changing agent code (not operator code)

**Automatic rebuild** (via CEL expression):
- `bpfman-agent-ystream-on-push-xxxxx` starts

### Step 2: Agent Build Completes → Nudging Creates PR

**Agent build completes**:
- New agent image: `abc123`
- Nudging system creates **PR**: Updates `hack/konflux/images/bpfman-agent.txt`
- PR targets: `bpfman-operator-bundle-ystream` (after PR #969 configuration change)

### Step 3: PR Merges → Bundle Rebuilds

**PR merges**:
- File changed: `hack/konflux/images/bpfman-agent.txt`
- Bundle CEL expression sees the change
- **Bundle rebuilds** with new agent image in ConfigMap

**Result**: Agent update causes exactly one bundle rebuild. Operator does not rebuild.

## Viewing Current Configuration

```bash
# Show all nudge relationships
oc get components -n ocp-bpfman-tenant -o json | \
  jq -r '.items[] | select(.spec["build-nudges-ref"]) |
  "\(.metadata.name) → \(.spec["build-nudges-ref"] | join(", "))"'

# Check a specific component's nudge targets
oc get component bpfman-agent-ystream -n ocp-bpfman-tenant \
  -o jsonpath='{.spec.build-nudges-ref}'

# See CEL expressions in pipeline definitions
grep -A 5 "on-cel-expression" .tekton/*-push.yaml
```

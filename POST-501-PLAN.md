# Downstream tooling changes required after bpfman/bpfman-operator#501

PR https://github.com/bpfman/bpfman-operator/pull/501 removes the
Config CR from the OLM bundle (OLM rejects custom resource instances)
and has the operator bootstrap it at startup from environment
variables on the deployment. Agent and daemon image references move
from a static manifest in the bundle to `BPFMAN_IMG` and
`BPFMAN_AGENT_IMG` env vars on the operator deployment spec in the
CSV.

All downstream tooling that patches the Config CR manifest needs
updating to patch the deployment env vars instead.

## Files to change

### `hack/openshift/update-config.py` -- delete

No Config CR in the bundle. Nothing to patch. The operator reads
image references from env vars at startup.

### `bundle/manifests/bpfman.io_v1alpha1_config.yaml` -- delete

OLM cannot ship custom resource instances. The operator creates the
Config CR itself.

### `hack/openshift/update-bundle.py` -- patch env vars in CSV

Currently replaces the operator image pullspec via string
substitution and does branding replacements. Needs to additionally
patch the `BPFMAN_IMG` and `BPFMAN_AGENT_IMG` environment variables
in the CSV's deployment container spec.

The env vars live at:

    spec.install.spec.deployments[0].spec.template.spec.containers[0].env

Find entries by name and replace their values:

    - name: BPFMAN_IMG
      value: <bpfman-pullspec>
    - name: BPFMAN_AGENT_IMG
      value: <agent-pullspec>

The `--agent-pullspec` and `--bpfman-pullspec` arguments already
exist on this script (used for relatedImages). Use them for the env
var patching too.

### `hack/openshift/Makefile` -- remove transform-config target

Delete the `transform-config` target and its git checkout restore
line. The `transform-bundle` target stays but no longer needs a
separate config transform step.

### `hack/konflux/scripts/validate-snapshot.py` -- read env vars not Config CR

Currently extracts agent and daemon SHAs from the Config CR file in
the bundle (`bpfman.io_v1alpha1_config.yaml`). That file no longer
exists.

Change `extract_bundle_refs` to read the agent and daemon image
references from the CSV's deployment env vars instead. Parse the
`BPFMAN_IMG` and `BPFMAN_AGENT_IMG` env var values from the CSV
YAML rather than from a separate Config CR file.

### `Containerfile.bundle.openshift` -- drop config transform

If the bundle Containerfile runs the config transform during the
image build, remove that step. Only the CSV transform
(`update-bundle.py`) is needed.

## Verification

After making these changes:

1. `make -C hack/openshift transform-bundle` produces a CSV with
   correct Red Hat pullspecs in both the operator image and the
   `BPFMAN_IMG`/`BPFMAN_AGENT_IMG` env vars.

2. `make -C hack/openshift build-bundle-container` builds
   successfully without the Config CR manifest.

3. `validate-snapshot.py` extracts image references from the CSV
   env vars and validates them against the snapshot components.

4. The built bundle image passes `operator-sdk bundle validate`.

#!/usr/bin/env python3
"""
Validate that a Konflux snapshot is self-consistent for OLM bundle releases.

Checks that all component SHAs referenced inside the bundle CSV
match the component SHAs actually present in the snapshot.

Usage:
    # By snapshot name (fetches JSON from the cluster via oc/kubectl):
    ./validate-snapshot.py bpfman-ystream-20260401-095050-000

    # By snapshot JSON:
    ./validate-snapshot.py '{"application":"...","components":[...]}'

    # Via environment variable (integration test pipeline):
    SNAPSHOT='{"application":"...","components":[...]}' ./validate-snapshot.py

    # Via stdin:
    echo '{"application":"...","components":[...]}' | ./validate-snapshot.py
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

NAMESPACE = "ocp-bpfman-tenant"


def fetch_snapshot_json(name, namespace=None):
    """Fetch snapshot spec JSON from the cluster by name."""
    if namespace is None:
        namespace = NAMESPACE
    result = subprocess.run(
        ["oc", "get", "snapshot", name, "-n", namespace, "-o", "jsonpath={.spec}"],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def detect_stream(application_name):
    """Detect stream (ystream/zstream) from application name."""
    if "ystream" in application_name:
        return "ystream"
    elif "zstream" in application_name:
        return "zstream"
    else:
        raise ValueError(f"Cannot detect stream from application name: {application_name}")


def parse_snapshot(snapshot_json):
    """Parse snapshot JSON and extract component information."""
    snapshot = json.loads(snapshot_json)

    application = snapshot.get("application", "")
    stream = detect_stream(application)

    components = {}
    for comp in snapshot.get("components", []):
        name = comp["name"]
        image = comp["containerImage"]
        # Extract sha256 digest from image reference
        if "@" in image:
            sha = image.split("@")[1]
        else:
            sha = None
        components[name] = {"sha": sha, "image": image}

    return components, stream, application


def extract_bundle_refs(bundle_image):
    """Extract component SHAs referenced in the bundle CSV.

    The operator image is found via its pullspec in the CSV. The agent
    and daemon images are found in the BPFMAN_AGENT_IMG and BPFMAN_IMG
    environment variables on the operator deployment spec. There is no
    Config CR in the bundle -- the operator bootstraps it at startup
    from these env vars.
    """
    # Create temporary directory for extraction
    with tempfile.TemporaryDirectory() as tmpdir:
        manifests_dir = os.path.join(tmpdir, "manifests")
        os.makedirs(manifests_dir)

        # Extract manifests from bundle image using oc image extract
        # This works without a container runtime
        subprocess.run(
            [
                "oc", "image", "extract", bundle_image,
                f"--path=/manifests/:{manifests_dir}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )

        # Read CSV
        csv_path = os.path.join(manifests_dir, "bpfman-operator.clusterserviceversion.yaml")
        with open(csv_path) as f:
            csv_content = f.read()

    # Parse operator SHA from CSV (operator image pullspec)
    operator_match = re.search(
        r"registry\.redhat\.io/bpfman/bpfman-rhel9-operator@(sha256:[a-f0-9]+)",
        csv_content,
    )
    operator_sha = operator_match.group(1) if operator_match else None

    # Parse agent and daemon SHAs from the deployment env vars in the
    # CSV. The operator bootstraps its Config CR from BPFMAN_IMG and
    # BPFMAN_AGENT_IMG at startup.
    agent_match = re.search(
        r"name:\s*BPFMAN_AGENT_IMG\s*\n\s*value:\s*\S+@(sha256:[a-f0-9]+)",
        csv_content,
    )
    agent_sha = agent_match.group(1) if agent_match else None

    daemon_match = re.search(
        r"name:\s*BPFMAN_IMG\s*\n\s*value:\s*\S+@(sha256:[a-f0-9]+)",
        csv_content,
    )
    daemon_sha = daemon_match.group(1) if daemon_match else None

    return {
        "operator": operator_sha,
        "agent": agent_sha,
        "daemon": daemon_sha,
        "csv_content": csv_content,
    }


def validate_snapshot(snapshot_json):
    """Validate snapshot self-consistency."""
    # Parse snapshot
    components, stream, application = parse_snapshot(snapshot_json)

    print(f"=== Validating Snapshot ===")
    print(f"Application: {application}")
    print(f"Stream: {stream}")
    print()

    # Get component keys
    operator_key = f"bpfman-operator-{stream}"
    agent_key = f"bpfman-agent-{stream}"
    daemon_key = f"bpfman-daemon-{stream}"
    bundle_key = f"bpfman-operator-bundle-{stream}"

    # Check all required components exist
    missing = []
    for key in [operator_key, agent_key, daemon_key, bundle_key]:
        if key not in components:
            missing.append(key)

    if missing:
        print(f"ERROR: Missing required components: {missing}")
        print()
        print("Available components:")
        for name in components:
            print(f"  - {name}")
        return 1

    print("Snapshot contains:")
    print(f"  Operator: {components[operator_key]['sha']}")
    print(f"  Agent:    {components[agent_key]['sha']}")
    print(f"  Daemon:   {components[daemon_key]['sha']}")
    print(f"  Bundle:   {components[bundle_key]['sha']}")
    print()

    # Extract bundle references
    bundle_image = components[bundle_key]["image"]
    print(f"Extracting bundle manifests from:")
    print(f"  {bundle_image}")
    print()

    try:
        refs = extract_bundle_refs(bundle_image)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to extract bundle: {e}")
        return 2

    print("Bundle references:")
    print(f"  CSV Operator: {refs['operator']}")
    print(f"  CSV Agent:    {refs['agent']}")
    print(f"  CSV Daemon:   {refs['daemon']}")
    print()

    # Compare
    failures = 0
    successes = 0

    print("=== Validation Results ===")

    if refs["operator"] is None:
        print("FAIL: Could not extract operator reference from CSV")
        failures += 1
    elif refs["operator"] != components[operator_key]["sha"]:
        print("FAIL: Operator mismatch")
        print(f"  Bundle wants:  {refs['operator']}")
        print(f"  Snapshot has:  {components[operator_key]['sha']}")
        failures += 1
    else:
        print("PASS: Operator matches")
        successes += 1

    if refs["agent"] is None:
        print("FAIL: Could not extract agent reference from CSV env vars")
        failures += 1
    elif refs["agent"] != components[agent_key]["sha"]:
        print("FAIL: Agent mismatch")
        print(f"  Bundle wants:  {refs['agent']}")
        print(f"  Snapshot has:  {components[agent_key]['sha']}")
        failures += 1
    else:
        print("PASS: Agent matches")
        successes += 1

    if refs["daemon"] is None:
        print("FAIL: Could not extract daemon reference from CSV env vars")
        failures += 1
    elif refs["daemon"] != components[daemon_key]["sha"]:
        print("FAIL: Daemon mismatch")
        print(f"  Bundle wants:  {refs['daemon']}")
        print(f"  Snapshot has:  {components[daemon_key]['sha']}")
        failures += 1
    else:
        print("PASS: Daemon matches")
        successes += 1

    print()
    if failures > 0:
        print(f"FAILED: {failures} mismatch(es), {successes} match(es)")
        print("This snapshot should NOT be released.")
        return 1
    else:
        print(f"PASSED: All {successes} references match")
        print("This snapshot is self-consistent and safe to release.")
        return 0


def resolve_snapshot_json(value, namespace=None):
    """Resolve a snapshot argument to JSON.

    If the value looks like JSON (starts with '{') it is returned
    as-is.  Otherwise it is treated as a snapshot name and fetched
    from the cluster.
    """
    if value.lstrip().startswith("{"):
        return value
    return fetch_snapshot_json(value, namespace=namespace)


def main():
    parser = argparse.ArgumentParser(
        description="Validate Konflux snapshot self-consistency"
    )
    parser.add_argument(
        "snapshot", nargs="?",
        help="Snapshot name or JSON (auto-detected). "
             "Can also be provided via SNAPSHOT env var or stdin."
    )
    parser.add_argument(
        "-n", "--namespace", default=NAMESPACE,
        help=f"Namespace for snapshot lookup (default: {NAMESPACE})"
    )

    args = parser.parse_args()

    raw = None
    if args.snapshot:
        raw = args.snapshot
    elif os.environ.get("SNAPSHOT"):
        raw = os.environ["SNAPSHOT"]
    elif not sys.stdin.isatty():
        raw = sys.stdin.read()

    if not raw:
        parser.error("No snapshot provided. Pass a name, JSON, set SNAPSHOT env var, or pipe to stdin.")

    try:
        snapshot_json = resolve_snapshot_json(raw, namespace=args.namespace)
        sys.exit(validate_snapshot(snapshot_json))
    except subprocess.CalledProcessError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        if e.stderr:
            print(e.stderr.strip(), file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()

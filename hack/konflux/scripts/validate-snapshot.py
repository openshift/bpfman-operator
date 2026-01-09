#!/usr/bin/env python3
"""
Validate that a Konflux snapshot is self-consistent for OLM bundle releases.

Checks that all component SHAs referenced inside the bundle (CSV + ConfigMap)
match the component SHAs actually present in the snapshot.

Usage:
    # From integration test pipeline (JSON via environment variable):
    SNAPSHOT='{"application":"...","components":[...]}' ./validate-snapshot.py

    # Or via stdin:
    echo '{"application":"...","components":[...]}' | ./validate-snapshot.py

    # Or via argument:
    ./validate-snapshot.py --snapshot '{"application":"...","components":[...]}'
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile


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
    """Extract component SHAs referenced in bundle CSV and ConfigMap."""
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

        # Read ConfigMap
        cm_path = os.path.join(manifests_dir, "bpfman-config_v1_configmap.yaml")
        with open(cm_path) as f:
            cm_content = f.read()

    # Parse operator SHA from CSV (in relatedImages)
    operator_match = re.search(
        r"registry\.redhat\.io/bpfman/bpfman-rhel9-operator@(sha256:[a-f0-9]+)",
        csv_content,
    )
    operator_sha = operator_match.group(1) if operator_match else None

    # Parse agent/daemon SHAs from ConfigMap
    agent_match = re.search(r"bpfman\.agent\.image:.*@(sha256:[a-f0-9]+)", cm_content)
    agent_sha = agent_match.group(1) if agent_match else None

    daemon_match = re.search(r"bpfman\.image:.*@(sha256:[a-f0-9]+)", cm_content)
    daemon_sha = daemon_match.group(1) if daemon_match else None

    return {
        "operator": operator_sha,
        "agent": agent_sha,
        "daemon": daemon_sha,
        "csv_content": csv_content,
        "cm_content": cm_content,
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
    print(f"  CSV Operator:     {refs['operator']}")
    print(f"  ConfigMap Agent:  {refs['agent']}")
    print(f"  ConfigMap Daemon: {refs['daemon']}")
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
        print("FAIL: Could not extract agent reference from ConfigMap")
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
        print("FAIL: Could not extract daemon reference from ConfigMap")
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


def main():
    parser = argparse.ArgumentParser(
        description="Validate Konflux snapshot self-consistency"
    )
    parser.add_argument(
        "--snapshot",
        help="Snapshot JSON (can also be provided via SNAPSHOT env var or stdin)"
    )

    args = parser.parse_args()

    # Get snapshot JSON from argument, environment, or stdin
    snapshot_json = None

    if args.snapshot:
        snapshot_json = args.snapshot
    elif os.environ.get("SNAPSHOT"):
        snapshot_json = os.environ["SNAPSHOT"]
    elif not sys.stdin.isatty():
        snapshot_json = sys.stdin.read()

    if not snapshot_json:
        print("ERROR: No snapshot provided", file=sys.stderr)
        print("Provide via --snapshot argument, SNAPSHOT env var, or stdin", file=sys.stderr)
        sys.exit(2)

    try:
        sys.exit(validate_snapshot(snapshot_json))
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()

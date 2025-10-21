#!/usr/bin/env python3

import argparse
import os
import sys
from datetime import datetime
from ruamel.yaml import YAML

yaml = YAML()


def main():
    parser = argparse.ArgumentParser(
        description="Update operator CSV file with Red Hat branding and metadata.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s --csv-file input.yaml --image-pullspec registry.example.com/operator:v1.0.0
  %(prog)s input.yaml output.yaml --image-pullspec registry.example.com/operator:v1.0.0""",
    )

    parser.add_argument("--csv-file", help="Path to the CSV file to update")
    parser.add_argument(
        "--image-pullspec", required=True, help="Operator image pullspec"
    )
    parser.add_argument(
        "--version", help="Version to set in CSV spec.version field"
    )
    parser.add_argument("--output", help="Output file (defaults to input file)")
    parser.add_argument(
        "files",
        nargs="*",
        help="CSV file and optional output file (positional arguments)",
    )

    args = parser.parse_args()

    if args.csv_file is None and len(args.files) > 0:
        args.csv_file = args.files[0]
    if args.output is None and len(args.files) > 1:
        args.output = args.files[1]

    if args.output is None:
        args.output = args.csv_file

    if args.csv_file is None:
        parser.error("CSV file is required")

    args.image_pullspec = args.image_pullspec.strip()

    try:
        with open(args.csv_file, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: File {args.csv_file} not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file {args.csv_file}: {e}", file=sys.stderr)
        sys.exit(1)

    # IMPORTANT: Replacement order matters! More specific patterns should come before
    # general ones to avoid conflicts. The script should be run on the original CSV
    # file, not on previously transformed content.
    replacements = [
        ("quay.io/bpfman/bpfman-operator:latest", f'"{args.image_pullspec}"'),
        ("displayName: Bpfman Operator", "displayName: eBPF Manager Operator"),
        ("The bpfman Operator", "The eBPF manager Operator"),
        ("name: The bpfman Community", "name: Red Hat"),
        ("url: https://bpfman.io", "url: https://www.redhat.com"),
        ("https://github.com/bpfman/bpfman", "https://github.com/openshift/bpfman-operator"),
        ("https://github.com/bpfman/bpfman-operator", "https://github.com/openshift/bpfman-operator"),
        ("https://bpfman.netlify.app/", "https://github.com/openshift/bpfman-operator"),
        ("Support bpfman Community", "Support Red Hat"),
        ("bpfman Community", "Red Hat"),
        ("repository: https://github.com/bpfman/", "repository: https://github.com/openshift/bpfman-operator"),
    ]

    for old, new in replacements:
        content = content.replace(old, new)

    try:
        bpfman_operator_csv = yaml.load(content)
    except Exception as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        sys.exit(1)

    timestamp = int(datetime.now().timestamp())
    datetime_time = datetime.fromtimestamp(timestamp)

    if "metadata" not in bpfman_operator_csv:
        bpfman_operator_csv["metadata"] = {}
    if "labels" not in bpfman_operator_csv["metadata"]:
        bpfman_operator_csv["metadata"]["labels"] = {}
    if "annotations" not in bpfman_operator_csv["metadata"]:
        bpfman_operator_csv["metadata"]["annotations"] = {}

    bpfman_operator_csv["metadata"]["labels"][
        "operatorframework.io/arch.amd64"
    ] = "supported"
    bpfman_operator_csv["metadata"]["labels"][
        "operatorframework.io/arch.arm64"
    ] = "supported"
    bpfman_operator_csv["metadata"]["labels"][
        "operatorframework.io/arch.ppc64le"
    ] = "supported"
    bpfman_operator_csv["metadata"]["labels"][
        "operatorframework.io/arch.s390x"
    ] = "supported"
    bpfman_operator_csv["metadata"]["labels"][
        "operatorframework.io/os.linux"
    ] = "supported"

    # Add annotations.
    bpfman_operator_csv["metadata"]["annotations"]["createdAt"] = (
        datetime_time.strftime("%d %b %Y, %H:%M")
    )
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/disconnected"
    ] = "true"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/fips-compliant"
    ] = "true"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/proxy-aware"
    ] = "false"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/tls-profiles"
    ] = "false"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/token-auth-aws"
    ] = "false"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/token-auth-azure"
    ] = "false"
    bpfman_operator_csv["metadata"]["annotations"][
        "features.operators.openshift.io/token-auth-gcp"
    ] = "false"

    # Update version if provided
    if args.version:
        version = args.version.strip()
        if "spec" not in bpfman_operator_csv:
            bpfman_operator_csv["spec"] = {}
        bpfman_operator_csv["spec"]["version"] = version
        # Update metadata.name to match version (pattern: bpfman-operator.v<version>)
        bpfman_operator_csv["metadata"]["name"] = f"bpfman-operator.v{version}"

    try:
        if args.output == "-":
            yaml.dump(bpfman_operator_csv, sys.stdout)
        else:
            with open(args.output, "w") as f:
                yaml.dump(bpfman_operator_csv, f)
            print(f"CSV file updated successfully: {args.output}")
    except Exception as e:
        print(f"Error writing file {args.output}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

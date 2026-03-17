#!/usr/bin/env python3

"""Update bpfman Config CR with Red Hat image references.

This tool transforms upstream bpfman-operator Config manifests for
Red Hat distribution by replacing upstream image references with Red
Hat registry pullspecs whilst preserving YAML formatting and
structure.
"""

import argparse
import sys
from ruamel.yaml import YAML


def load_yaml_file(file_path):
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = 4096
    try:
        with open(file_path, "r") as f:
            return yaml.load(f)
    except FileNotFoundError:
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error loading YAML file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)


def save_yaml_file(file_path, data):
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = 4096
    try:
        with open(file_path, "w") as f:
            yaml.dump(data, f)
    except Exception as e:
        print(f"Error writing YAML file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)


def update_config(config_file, agent_pullspec, bpfman_pullspec, output_file=None):

    if output_file is None:
        output_file = config_file

    print(f"Updating Config file: {config_file}")

    config = load_yaml_file(config_file)

    if "spec" not in config:
        print("Error: Config file missing 'spec' field", file=sys.stderr)
        sys.exit(1)

    if "agent" not in config["spec"]:
        config["spec"]["agent"] = {}
    config["spec"]["agent"]["image"] = agent_pullspec

    if "daemon" not in config["spec"]:
        config["spec"]["daemon"] = {}
    config["spec"]["daemon"]["image"] = bpfman_pullspec

    save_yaml_file(output_file, config)

    print(f"Config file updated successfully: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Update bpfman Config CR with Red Hat image references.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  %(prog)s --config-file config.yaml --agent-pullspec registry.redhat.io/bpfman/agent@sha256:... --bpfman-pullspec registry.redhat.io/bpfman/bpfman@sha256:...
""",
    )

    parser.add_argument(
        "--config-file", required=True, help="Path to the Config CR file to update"
    )
    parser.add_argument(
        "--agent-pullspec", required=True, help="bpfman-agent image pullspec"
    )
    parser.add_argument(
        "--bpfman-pullspec", required=True, help="bpfman image pullspec"
    )
    parser.add_argument("--output", help="Output file (defaults to input file)")

    args = parser.parse_args()

    agent_pullspec = args.agent_pullspec.strip()
    bpfman_pullspec = args.bpfman_pullspec.strip()

    if not agent_pullspec:
        print("Error: Agent pullspec cannot be empty", file=sys.stderr)
        sys.exit(1)

    if not bpfman_pullspec:
        print("Error: Bpfman pullspec cannot be empty", file=sys.stderr)
        sys.exit(1)

    update_config(args.config_file, agent_pullspec, bpfman_pullspec, args.output)


if __name__ == "__main__":
    main()

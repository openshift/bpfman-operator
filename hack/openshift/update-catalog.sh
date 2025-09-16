#!/usr/bin/env bash

set -eu

usage() {
    cat <<EOF
Usage: ${0##*/} [options]

Update catalog index.yaml with Red Hat image references and timestamps.

Options:
    --index-file FILE             Path to the catalog index.yaml file to update (required)
    --bundle-pullspec PULLSPEC    Bundle image pullspec (required)
    --operator-pullspec PULLSPEC  Operator image pullspec (required)
    --help                        Show this help message

Examples:
    ${0##*/} --index-file catalog/index.yaml \\
       --bundle-pullspec "registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:abc123" \\
       --operator-pullspec "registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:def456"

    ${0##*/} --index-file /configs/bpfman-operator/index.yaml \\
       --bundle-pullspec "\$(cat konflux/images/bpfman-operator-bundle.txt)" \\
       --operator-pullspec "\$(cat konflux/images/bpfman-operator.txt)"
EOF
}

index_file=""
bundle_pullspec=""
operator_pullspec=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --index-file)
            index_file="$2"
            shift 2
            ;;
        --bundle-pullspec)
            bundle_pullspec="$2"
            shift 2
            ;;
        --operator-pullspec)
            operator_pullspec="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$index_file" ]]; then
    echo "Error: --index-file is required" >&2
    usage >&2
    exit 1
fi

if [[ -z "$bundle_pullspec" ]]; then
    echo "Error: --bundle-pullspec is required" >&2
    usage >&2
    exit 1
fi

if [[ -z "$operator_pullspec" ]]; then
    echo "Error: --operator-pullspec is required" >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$index_file" ]]; then
    echo "Error: Index file '$index_file' not found" >&2
    exit 1
fi

echo "Catalog processing started"
echo "Using bundle image: ${bundle_pullspec}"
echo "Using operator image: ${operator_pullspec}"

sed -i -E \
    -e "s|^(\s*-?\s*image:\s*)registry\.redhat\.io/bpfman/bpfman-operator-bundle@.*$|\1${bundle_pullspec}|" \
    -e "s|^(\s*containerImage:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${operator_pullspec}|" \
    -e "s|^(\s*-?\s*image:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${operator_pullspec}|" \
    -e "s|^(\s*createdAt:\s*)(.+)$|\1$(date +'%d %b %Y, %H:%M')|" \
    "$index_file"

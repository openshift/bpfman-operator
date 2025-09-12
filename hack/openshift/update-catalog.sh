#!/usr/bin/env bash

set -eu

usage() {
    cat <<EOF
Usage: ${0##*/} [options]

Update catalog index.yaml with Red Hat image references and timestamps.

Options:
    --index-file FILE       Path to the catalog index.yaml file to update (required)
    --bundle-pullspec IMAGE Bundle image pullspec (required)
    --operator-pullspec IMAGE Operator image pullspec (required)
    --help                 Show this help message

Examples:
    ${0##*/} --index-file catalog/index.yaml \\
       --bundle-pullspec "registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:abc123" \\
       --operator-pullspec "registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:def456"

    ${0##*/} --index-file /configs/bpfman-operator/index.yaml \\
       --bundle-pullspec "\$(cat konflux/images/bpfman-operator-bundle.txt)" \\
       --operator-pullspec "\$(cat konflux/images/bpfman-operator.txt)"
EOF
}

# Parse arguments
INDEX_FILE=""
BUNDLE_PULLSPEC=""
OPERATOR_PULLSPEC=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --index-file)
            INDEX_FILE="$2"
            shift 2
            ;;
        --bundle-pullspec)
            BUNDLE_PULLSPEC="$2"
            shift 2
            ;;
        --operator-pullspec)
            OPERATOR_PULLSPEC="$2"
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

# Validate required arguments
if [[ -z "$INDEX_FILE" ]]; then
    echo "Error: --index-file is required" >&2
    usage >&2
    exit 1
fi

if [[ -z "$BUNDLE_PULLSPEC" ]]; then
    echo "Error: --bundle-pullspec is required" >&2
    usage >&2
    exit 1
fi

if [[ -z "$OPERATOR_PULLSPEC" ]]; then
    echo "Error: --operator-pullspec is required" >&2
    usage >&2
    exit 1
fi

# Check if index file exists
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "Error: Index file '$INDEX_FILE' not found" >&2
    exit 1
fi

# Use the pullspecs directly
BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="$BUNDLE_PULLSPEC"
BPFMAN_OPERATOR_IMAGE_PULLSPEC="$OPERATOR_PULLSPEC"

echo "Catalog processing started"
echo "Using bundle image: ${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}"
echo "Using operator image: ${BPFMAN_OPERATOR_IMAGE_PULLSPEC}"

# Perform the transformations using sed
sed -i -E \
    -e "s|^(\s*-?\s*image:\s*)registry\.redhat\.io/bpfman/bpfman-operator-bundle@.*$|\1${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*containerImage:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${BPFMAN_OPERATOR_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*-?\s*image:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${BPFMAN_OPERATOR_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*createdAt:\s*)(.+)$|\1$(date +'%d %b %Y, %H:%M')|" \
    "$INDEX_FILE"

echo "Successfully updated $INDEX_FILE"

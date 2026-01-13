#!/usr/bin/env bash
#
# Sync nudge files with Konflux lastPromotedImage
#
# This script queries Konflux component status to get the latest
# promoted image SHAs and updates the nudge files accordingly. This
# ensures the bundle builds with the correct image references.
#
# Usage:
#   ./hack/openshift/sync-nudge-files.sh <stream>
#
# Arguments:
#   stream    Either "ystream" or "zstream".
#
# Prerequisites:
#   - oc CLI configured and logged into the Konflux cluster
#   - Access to the ocp-bpfman-tenant namespace
#
# Example:
#   ./hack/openshift/sync-nudge-files.sh ystream

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
nudge_dir="${repo_root}/hack/konflux/images"

namespace="ocp-bpfman-tenant"

usage() {
    echo "Usage: ${0##*/} <stream>" >&2
    echo "  stream: ystream or zstream" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

stream="$1"

if [[ "${stream}" != "ystream" && "${stream}" != "zstream" ]]; then
    echo "Error: stream must be 'ystream' or 'zstream', got '${stream}'" >&2
    exit 1
fi

# Component mappings: component -> registry|nudge_file.
# Uses pipe as delimiter since colon and slash appear in registry paths.
# Konflux builds to quay.io, nudge files reference registry.redhat.io.
declare -A components=(
    ["bpfman-operator"]="registry.redhat.io/bpfman/bpfman-rhel9-operator|bpfman-operator.txt"
    ["bpfman-agent"]="registry.redhat.io/bpfman/bpfman-agent|bpfman-agent.txt"
    ["bpfman-daemon"]="registry.redhat.io/bpfman/bpfman|bpfman.txt"
)

get_last_promoted_sha() {
    local component="$1"
    local image
    image=$(oc get component "${component}" -n "${namespace}" -o jsonpath='{.status.lastPromotedImage}' 2>/dev/null)

    if [[ -z "${image}" ]]; then
        echo "Error: could not get lastPromotedImage for component '${component}'" >&2
        echo "       Ensure you are logged into the Konflux cluster and have access to ${namespace}" >&2
        return 1
    fi

    local sha
    sha="${image##*@}"

    if [[ ! "${sha}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
        echo "Error: invalid SHA format '${sha}' from component '${component}'" >&2
        return 1
    fi

    echo "${sha}"
}

echo "Syncing nudge files for ${stream}..."
echo "Namespace: ${namespace}"
echo ""

echo "Fetching lastPromotedImage from Konflux components..."
for component in "${!components[@]}"; do
    IFS='|' read -r registry nudge_file <<< "${components[$component]}"
    konflux_component="${component}-${stream}"

    sha=$(get_last_promoted_sha "${konflux_component}")
    echo "  ${konflux_component}: ${sha}"

    echo "${registry}@${sha}" > "${nudge_dir}/${nudge_file}"
done

echo ""
echo "Done. Run 'git diff' to review changes."

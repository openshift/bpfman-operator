#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:d3a2e3a98032d24f600cae8f0582112832bfd8f34b0460fb98f77f87df41a1bd"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:f3500bdf3e65134ffa75f48ada91a76ed911de62fc7d6bf4fceb9cd7833e72a3"
#
export INDEX_FILE=/configs/bpfman-operator/index.yaml

echo "Catalog processing started"
echo "Using bundle image: ${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}"
echo "Using operator image: ${BPFMAN_OPERATOR_IMAGE_PULLSPEC}"

echo "BEFORE processing:"
echo "  Image fields:"
grep -n "image:" "${INDEX_FILE}"
echo "  CreatedAt field:"
grep -n "createdAt:" "${INDEX_FILE}"

sed -i -E \
    -e "s|^(\s*-?\s*image:\s*)registry\.redhat\.io/bpfman/bpfman-operator-bundle@.*$|\1${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*containerImage:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${BPFMAN_OPERATOR_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*-?\s*image:\s*)quay\.io/bpfman/bpfman-operator:latest$|\1${BPFMAN_OPERATOR_IMAGE_PULLSPEC}|" \
    -e "s|^(\s*createdAt:\s*)(.+)$|\1$(date +'%d %b %Y, %H:%M')|" \
    "${INDEX_FILE}"

echo "AFTER processing:"
echo "  Image fields:"
grep -n "image:" "${INDEX_FILE}"
echo "  CreatedAt field:"
grep -n "createdAt:" "${INDEX_FILE}"

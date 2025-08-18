#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:583be720b1bf41c8f9802beb2a9af3290e05862f30c0f62490376385d14026c4"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:87940c44179f8ba550f3fee0e1a25462801604ce42a7aed6e9370da913582c1c"
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

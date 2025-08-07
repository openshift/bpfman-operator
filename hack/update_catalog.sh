#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:01ea9958a4bb3949072bce78269830eac6f92ba3565e03ad76d72a341a095002"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:ac960b12cf9a1dfdea7206256475674c5528edc5017300f10d403552e7cd5c29"
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

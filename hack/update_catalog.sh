#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:316a6b318bf5583280a8ac7fe75575b41740351b888e36a43c58ee4387ead94d"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:608b53515b54894c41c4a42e2dc22eacd3ab967cd6ea7f0c3353ead3586812d6"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"


cat $INDEX_FILE

#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:875d7a2681211650004c29737d7767d4e4b55c2c0c1d6dc73d9075961561161d"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:608b53515b54894c41c4a42e2dc22eacd3ab967cd6ea7f0c3353ead3586812d6"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"


cat $INDEX_FILE

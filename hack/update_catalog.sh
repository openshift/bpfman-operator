#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:80ae915b10c3f31a28bab954209ea4a720abe45cc9f60497a303f848e8df5666"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:608b53515b54894c41c4a42e2dc22eacd3ab967cd6ea7f0c3353ead3586812d6"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"


cat $INDEX_FILE

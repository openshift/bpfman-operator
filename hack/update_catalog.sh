#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:ac3943fb05ca5f3752c15133d361615ece79321f99b614d3290d5d28366ea382"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:ad56de649370fee537bdb40f952e2d49b54ccf52393825e088529626b8b179a4"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"


cat $INDEX_FILE

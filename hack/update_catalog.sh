#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:3c0bacd791ad1d205b8a947a7bcf1c9de3a45453887c32558c83f2279f1f802c"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:ad56de649370fee537bdb40f952e2d49b54ccf52393825e088529626b8b179a4"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"


cat $INDEX_FILE

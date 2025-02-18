#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:e4343c612841475bb4363d2c60add7c6c42ecf2e8b2dbbb8c16533d80a4cad10"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:c3d878d77091bed03d99f72943d9b78e210e2f6194ea4b5cd2aa23f8d48f3f61"

export INDEX_FILE=/configs/bpfman-operator/index.yaml

sed -i -e "s|quay.io/bpfman/bpfman-operator:v.*|\"${BPFMAN_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

sed -i -e "s|quay.io/bpfman/bpfman-operator-bundle:v.*|\"${BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC}\"|g" \
	"${INDEX_FILE}"

# time for some direct modifications to the csv
python3 - << INDEX_FILE_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return list(yaml.load_all(f))
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump_all(manifest, f)
   return

manifest = load_manifest(os.getenv('INDEX_FILE'))

if manifest is not None:
    # Iterate over the loaded manifest and update the 'image' field
    for index_file in manifest:
        index_file['image'] = os.getenv('BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC', '')
    # Dump the updated manifest back into the file
    dump_manifest(os.getenv('INDEX_FILE'), manifest)

INDEX_FILE_UPDATE

cat $INDEX_FILE

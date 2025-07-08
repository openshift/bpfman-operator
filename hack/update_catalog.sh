#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:f23e346edb420913eb83bf921f56dfab1ef7a5719224238a7c6113d16e6da220"
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:a2cb70e9537d24371b6678f916f44b3a90d8268494e2b00c195fea18068ff120"


export INDEX_FILE=/configs/bpfman-operator/index.yaml

# Create backup for diff
cp "${INDEX_FILE}" "${INDEX_FILE}.bak"

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

if command -v diff >/dev/null 2>&1; then
    echo "Changes made:"
    diff -u "${INDEX_FILE}.bak" "${INDEX_FILE}" || true
else
    echo "Changes made (diff utility not available for detailed comparison)"
fi

# Clean up backup
rm "${INDEX_FILE}.bak"

cat $INDEX_FILE

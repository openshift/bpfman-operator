#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:2ceef871e3f3d715daa1da40dca3c9d36c463298fd9e54027ba6a3fce2f393be"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:8519e7d7194bdcf3c45cd466493d1bc38f7e7d0ce74abcb7febb2f0ee70d7cd6"
#
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

# Update catalog timestamp
hack/patch_catalog_build_date.py "${INDEX_FILE}"

if command -v diff >/dev/null 2>&1; then
    echo "Changes made:"
    diff -u "${INDEX_FILE}.bak" "${INDEX_FILE}" || true
else
    echo "Changes made (diff utility not available for detailed comparison)"
fi

# Clean up backup
rm "${INDEX_FILE}.bak"

cat $INDEX_FILE

#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:726c1329c7ec62bec2164073957a40ed1a8568af6ee8e5285a970c41b5fac83c"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:7a8d074fb5ec90884e75348c066e45cdc14b61cb0c228e99cf81e9b4382d2da9"
#
# Copy catalog to writable location for processing
cp -r /configs/bpfman-operator /tmp/
export INDEX_FILE=/tmp/bpfman-operator/index.yaml

# Process catalog files directly

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

echo "Catalog processing completed"

# Copy processed catalog back to final location
cp -r /tmp/bpfman-operator/* /configs/bpfman-operator/

cat $INDEX_FILE

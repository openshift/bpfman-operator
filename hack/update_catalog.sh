#!/usr/bin/env bash
set -eu

# Do not remove empty lines, they are there to reduce conflicts.
export BPFMAN_OPERATOR_BUNDLE_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-operator-bundle@sha256:f904b47cab595b2c3ed5559601997e7746c00606b408a6a5766dac44b0fceda3"
#
export BPFMAN_OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:2813695d490410c0818cf6c260562150fc564e091a86d405ebd1be487271f38d"
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

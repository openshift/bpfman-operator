#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_AGENT_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-agent@sha256:ef8889498aac25e6130a644e9c7bb4f63af0cbf44c01c50616bc74bc4157cb44"

export BPFMAN_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman@sha256:eebd4df63328f0e56c8484ea981e325f3b1e0224bc5c8d695a45ba2d69404ca0"

export CONFIG_MAP=/manifests/bpfman-config_v1_configmap.yaml

sed -i -e "s|quay.io/bpfman/bpfman-agent:latest*|\"${BPFMAN_AGENT_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/bpfman/bpfman:latest*|\"${BPFMAN_IMAGE_PULLSPEC}\"|g" \
	"${CONFIG_MAP}"

# time for some direct modifications to the csv
python3 - << CM_UPDATE
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
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
# update configmap
bpfman_operator_cm = load_manifest(os.getenv('CONFIG_MAP'))
bpfman_operator_cm['data']['bpfman.agent.image'] =  os.getenv('BPFMAN_AGENT_IMAGE_PULLSPEC', '')
bpfman_operator_cm['data']['bpfman.image'] =  os.getenv('BPFMAN_IMAGE_PULLSPEC', '')

dump_manifest(os.getenv('CONFIG_MAP'), bpfman_operator_cm)
CM_UPDATE

cat $CONFIG_MAP

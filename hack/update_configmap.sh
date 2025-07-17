#!/usr/bin/env bash
set -eu

#!/usr/bin/env bash

export BPFMAN_AGENT_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman-agent@sha256:7dea09c206ce549db97855b6bc54863b10f172b2a434e5a440e1ecf106d630bc"

export BPFMAN_IMAGE_PULLSPEC="registry.redhat.io/bpfman/bpfman@sha256:076efb5843543ec0d9d5897db48195d1297db4d263efe367702c50fba080d857"

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

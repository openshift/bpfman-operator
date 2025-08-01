#!/usr/bin/env python3

import os
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()

# Configuration
BPFMAN_OPERATOR_IMAGE_PULLSPEC = "registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:84314fd013ffb523050fd1649c687b9a7a111030b5ecd9c048cacde0c851cc47"
CSV_FILE = "/manifests/bpfman-operator.clusterserviceversion.yaml"

def main():
    # Perform sed replacements on CSV file
    print("Updating CSV file...")
    
    with open(CSV_FILE, 'r') as f:
        content = f.read()
    
    # Apply sed-like replacements
    replacements = [
        (r'quay.io/bpfman/bpfman-operator:v.*', f'"{BPFMAN_OPERATOR_IMAGE_PULLSPEC}"'),
        (r'quay.io/bpfman/bpfman-operator:latest.*', f'"{BPFMAN_OPERATOR_IMAGE_PULLSPEC}"'),
        ('displayName: Bpfman Operator', 'displayName: eBPF Manager Operator'),
        ('The bpfman Operator', 'The eBPF manager Operator'),
        ('name: The bpfman Community', 'name: Red Hat'),
        ('url: https://bpfman.io', 'url: https://www.redhat.com'),
    ]
    
    for old, new in replacements:
        content = content.replace(old, new)
    
    with open(CSV_FILE, 'w') as f:
        f.write(content)
    
    # Load CSV for Python modifications
    with open(CSV_FILE, 'r') as f:
        bpfman_operator_csv = yaml.load(f)
    
    # Set timestamp
    timestamp = int(datetime.now().timestamp())
    datetime_time = datetime.fromtimestamp(timestamp)
    
    # Always add all architecture support labels (we build for all 4 architectures)
    if 'metadata' not in bpfman_operator_csv:
        bpfman_operator_csv['metadata'] = {}
    if 'labels' not in bpfman_operator_csv['metadata']:
        bpfman_operator_csv['metadata']['labels'] = {}
    if 'annotations' not in bpfman_operator_csv['metadata']:
        bpfman_operator_csv['metadata']['annotations'] = {}
    
    # Add architecture support labels (always all 4 since we build for all)
    bpfman_operator_csv['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
    bpfman_operator_csv['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
    bpfman_operator_csv['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
    bpfman_operator_csv['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
    bpfman_operator_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
    
    # Add annotations
    bpfman_operator_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
    bpfman_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
    
    # Write back the modified CSV
    with open(CSV_FILE, 'w') as f:
        yaml.dump(bpfman_operator_csv, f)
    
    print("CSV file updated successfully")

if __name__ == "__main__":
    main()
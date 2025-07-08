#!/usr/bin/env python3

import os
import sys
from datetime import datetime
from ruamel.yaml import YAML

def update_catalog_timestamp(catalog_file):
    """Update the createdAt timestamp in a catalog file"""
    yaml = YAML()

    with open(catalog_file, 'r') as f:
        docs = list(yaml.load_all(f))

    current_time = datetime.now().strftime('%d %b %Y, %H:%M')

    for doc in docs:
        if doc and doc.get('schema') == 'olm.bundle':
            # The createdAt field is in properties -> olm.csv.metadata -> value -> annotations
            if 'properties' in doc:
                for prop in doc['properties']:
                    if prop.get('type') == 'olm.csv.metadata':
                        if 'value' in prop and 'annotations' in prop['value']:
                            annotations = prop['value']['annotations']
                            if 'createdAt' in annotations:
                                annotations['createdAt'] = current_time

    with open(catalog_file, 'w') as f:
        yaml.dump_all(docs, f)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: patch_catalog_build_date.py <catalog_file>", file=sys.stderr)
        sys.exit(1)

    update_catalog_timestamp(sys.argv[1])

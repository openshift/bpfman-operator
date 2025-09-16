.DEFAULT_GOAL := help

help:
	@echo "Available targets:"
	@echo "  transform-bundle             Transform bundle CSV with Red Hat images"
	@echo "  transform-bundle-container   Build bundle container with transformations"
	@echo "  transform-configmap          Update ConfigMap with Red Hat images"
	@echo "  transform-catalog            Update catalog index with Red Hat images"
	@echo "  transform-catalog-container  Build catalog container with transformations"
	@echo "  transform-all-container      Build all containers with transformations"
	@echo "  generate-rpm-lockfile        Generate rpms.lock.yaml for Konflux builds"
	@echo "  format                       Format Python files with Black"
	@echo "  format-check                 Check Python formatting"

transform-bundle:
	./update-bundle.py \
		--csv-file ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
		--image-pullspec "$$(cat ../konflux/images/bpfman-operator.txt)"

transform-configmap:
	./update-configmap.py \
		--configmap-file ../../bundle/manifests/bpfman-config_v1_configmap.yaml \
		--agent-pullspec "$$(cat ../konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat ../konflux/images/bpfman.txt)"

transform-catalog:
	./update-catalog.sh \
		--index-file ../../catalog/index.yaml \
		--bundle-pullspec "$$(cat ../konflux/images/bpfman-operator-bundle.txt)" \
		--operator-pullspec "$$(cat ../konflux/images/bpfman-operator.txt)"

# Container-based transformation targets
# Run these with: make -C hack/openshift/ transform-*-container
transform-bundle-container:
	podman build -f ../../Containerfile.bundle.openshift -t bpfman-operator-transform ../../

transform-catalog-container:
	podman build -f ../../Containerfile.catalog.openshift-4.20 -t bpfman-catalog ../../

transform-all-container: transform-bundle-container transform-catalog-container

# Sync VERSION from upstream to all OpenShift Containerfiles. Run this
# after merging from upstream or when VERSION changes.
set-version:
	@echo "Syncing upstream VERSION to OpenShift Containerfiles..."
	@./sync-version.sh

# Generate RPM lockfile for Konflux builds
generate-rpm-lockfile:
	cd ../.. && hack/openshift/generate-rpm-lockfile.sh

# Format Python files with Black
format:
	black *.py

# Check Python formatting without changing files
format-check:
	black --check *.py

.PHONY: help transform-bundle transform-configmap transform-catalog transform-bundle-container transform-catalog-container transform-all-container generate-rpm-lockfile format format-check

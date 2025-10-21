.DEFAULT_GOAL := help

help:
	@echo "Available targets:"
	@echo "  transform-bundle             Transform bundle CSV with Red Hat images"
	@echo "  transform-bundle-container   Build bundle container with transformations"
	@echo "  transform-configmap          Update ConfigMap with Red Hat images"
	@echo "  generate-rpm-lockfile        Generate rpms.lock.yaml for Konflux builds"
	@echo "  format                       Format Python files with Black"
	@echo "  format-check                 Check Python formatting"

transform-bundle:
	@echo "Restoring CSV file from git to ensure clean baseline..."
	git checkout HEAD -- ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml
	./update-bundle.py \
		--csv-file ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
		--image-pullspec "$$(cat ../konflux/images/bpfman-operator.txt)" \
		--version "$$(grep BUILDVERSION ../../OPENSHIFT-VERSION | cut -d= -f2)"

transform-configmap:
	@echo "Restoring ConfigMap file from git to ensure clean baseline..."
	git checkout HEAD -- ../../bundle/manifests/bpfman-config_v1_configmap.yaml
	./update-configmap.py \
		--configmap-file ../../bundle/manifests/bpfman-config_v1_configmap.yaml \
		--agent-pullspec "$$(cat ../konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat ../konflux/images/bpfman.txt)"

# Container-based transformation targets
# Run these with: make -C hack/openshift/ transform-*-container
transform-bundle-container:
	podman build --build-arg-file ../../OPENSHIFT-VERSION -f ../../Containerfile.bundle.openshift -t bpfman-operator-transform ../../

# Generate RPM lockfile for Konflux builds
generate-rpm-lockfile:
	cd ../.. && hack/openshift/generate-rpm-lockfile.sh

# Format Python files with Black
format:
	black *.py

# Check Python formatting without changing files
format-check:
	black --check *.py

.PHONY: help transform-bundle transform-configmap transform-bundle-container generate-rpm-lockfile format format-check

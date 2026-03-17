.DEFAULT_GOAL := help

help:
	@echo "Available targets:"
	@echo "  build-operator-container     Build operator container with Red Hat images"
	@echo "  build-bundle-container       Build bundle container with transformations"
	@echo "  transform-bundle             Transform bundle CSV with Red Hat images"
	@echo "  transform-config             Update Config CR with Red Hat images"
	@echo "  generate-rpm-lockfile        Generate rpms.lock.yaml for Konflux builds"
	@echo "  format                       Format Python files with Black"
	@echo "  format-check                 Check Python formatting"

transform-bundle:
	@echo "Restoring CSV file from git to ensure clean baseline..."
	git checkout HEAD -- ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml
	./update-bundle.py \
		--csv-file ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
		--image-pullspec "$$(cat ../konflux/images/bpfman-operator.txt)" \
		--agent-pullspec "$$(cat ../konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat ../konflux/images/bpfman.txt)" \
		--csi-pullspec "$$(grep CSI_NODE_DRIVER_REGISTRAR_IMAGE ../../OPENSHIFT-VERSION | cut -d= -f2)" \
		--version "$$(grep BUILDVERSION ../../OPENSHIFT-VERSION | cut -d= -f2)"

transform-config:
	@echo "Restoring Config CR file from git to ensure clean baseline..."
	git checkout HEAD -- ../../bundle/manifests/bpfman.io_v1alpha1_config.yaml
	./update-config.py \
		--config-file ../../bundle/manifests/bpfman.io_v1alpha1_config.yaml \
		--agent-pullspec "$$(cat ../konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat ../konflux/images/bpfman.txt)"

# Container-based build targets
# Run these with: make -C hack/openshift/ build-*-container
build-operator-container:
	podman build --build-arg-file ../../OPENSHIFT-VERSION -f ../../Containerfile.bpfman-operator.openshift -t bpfman-operator-test ../../

build-bundle-container:
	podman build --build-arg-file ../../OPENSHIFT-VERSION -f ../../Containerfile.bundle.openshift -t bpfman-operator-bundle-test ../../

# Legacy alias
transform-bundle-container: build-bundle-container

# Generate RPM lockfile for Konflux builds
generate-rpm-lockfile:
	cd ../.. && hack/openshift/generate-rpm-lockfile.sh

# Format Python files with Black
format:
	black *.py

# Check Python formatting without changing files
format-check:
	black --check *.py

.PHONY: help transform-bundle transform-config build-operator-container build-bundle-container transform-bundle-container generate-rpm-lockfile format format-check

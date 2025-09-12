all: transform-all-python

transform-bundle:
	./update-bundle.py \
		--csv-file ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
		--image-pullspec "$$(cat konflux/images/bpfman-operator.txt)"

transform-configmap:
	./update-configmap.py \
		--configmap-file ../../bundle/manifests/bpfman-config_v1_configmap.yaml \
		--agent-pullspec "$$(cat konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat konflux/images/bpfman.txt)"

transform-catalog:
	./update-catalog.sh \
		--index-file ../../catalog/index.yaml \
		--bundle-pullspec "$$(cat konflux/images/bpfman-operator-bundle.txt)" \
		--operator-pullspec "$$(cat konflux/images/bpfman-operator.txt)"

transform-all-python: transform-bundle transform-configmap transform-catalog

# Alias for backwards compatibility
transform-all: transform-all-python

# Container-based transformation targets
# Run these with: make -C hack/openshift/ container-transform-*
container-transform-bundle:
	podman build -f ../../Containerfile.bundle.openshift -t bpfman-operator-transform ../../

container-transform-catalog:
	podman build -f ../../Containerfile.catalog.openshift-4.20 -t bpfman-catalog ../../

container-transform-all: container-transform-bundle container-transform-catalog

.PHONY: all transform-bundle transform-configmap transform-catalog transform-all transform-all-python container-transform-bundle container-transform-catalog container-transform-all

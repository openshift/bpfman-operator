all:
	go fmt ./...
	go build -o /tmp/update_configmap update_configmap.go
	go build -o /tmp/update_bundle update_bundle.go
	go build -o /tmp/update_catalog update_catalog.go

test-bundle:
	go run update_bundle.go --dry-run \
		--csv-file ../../bundle/manifests/bpfman-operator.clusterserviceversion.yaml \
		--image-pullspec "$$(cat konflux/images/bpfman-operator.txt)"

test-configmap:
	go run update_configmap.go --dry-run \
		--configmap-file ../../bundle/manifests/bpfman-config_v1_configmap.yaml \
		--agent-pullspec "$$(cat konflux/images/bpfman-agent.txt)" \
		--bpfman-pullspec "$$(cat konflux/images/bpfman.txt)"

test-all: test-bundle test-configmap

.PHONY: all test-bundle test-configmap test-all
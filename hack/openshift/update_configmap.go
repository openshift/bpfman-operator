package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	defaultAgentPullspec  = "registry.redhat.io/bpfman/bpfman-agent@sha256:4105eb14731e7f41c177f8a5ac0be7447967f4ec3338967e15f398d3147225b3"
	defaultBpfmanPullspec = "registry.redhat.io/bpfman/bpfman@sha256:4c31043d37cd20bb43fcb64d38b9c8cdfb8d1c9317d7d8b24051f9005abd7112"
)

func main() {
	var (
		configMapFile  = flag.String("configmap-file", "", "Path to the ConfigMap file to update")
		agentPullspec  = flag.String("agent-pullspec", defaultAgentPullspec, "bpfman-agent image pullspec")
		bpfmanPullspec = flag.String("bpfman-pullspec", defaultBpfmanPullspec, "bpfman image pullspec")
		outputFile     = flag.String("output", "", "Output file (defaults to input file)")
		dryRun         = flag.Bool("dry-run", false, "Show what would be changed without modifying files")
		help           = flag.Bool("help", false, "Show help message")
	)

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <configmap-file> [output-file]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Update bpfman ConfigMap with Red Hat image references.\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  %s --configmap-file input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --dry-run input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s input.yaml output.yaml\n", os.Args[0])
	}

	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	// Sanitize pullspecs by removing leading/trailing whitespace and newlines
	*agentPullspec = strings.TrimSpace(*agentPullspec)
	*bpfmanPullspec = strings.TrimSpace(*bpfmanPullspec)

	// Handle positional arguments
	args := flag.Args()
	if *configMapFile == "" && len(args) > 0 {
		*configMapFile = args[0]
	}
	if *outputFile == "" && len(args) > 1 {
		*outputFile = args[1]
	}

	// Default output to input file if not specified
	if *outputFile == "" {
		*outputFile = *configMapFile
	}

	if *configMapFile == "" {
		fmt.Fprintf(os.Stderr, "Error: ConfigMap file is required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *dryRun {
		fmt.Printf("Dry run mode: would update %s\n", *configMapFile)
		if *outputFile != *configMapFile {
			fmt.Printf("Output would be written to: %s\n", *outputFile)
		}
		fmt.Printf("Agent pullspec: %s\n", *agentPullspec)
		fmt.Printf("Bpfman pullspec: %s\n", *bpfmanPullspec)
	}

	fmt.Printf("Updating ConfigMap file: %s\n", *configMapFile)

	content, err := os.ReadFile(*configMapFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", *configMapFile, err)
		os.Exit(1)
	}

	contentStr := string(content)

	replacements := map[string]string{
		"quay.io/bpfman/bpfman-agent:latest": fmt.Sprintf("\"%s\"", *agentPullspec),
		"quay.io/bpfman/bpfman:latest":       fmt.Sprintf("\"%s\"", *bpfmanPullspec),
	}

	if *dryRun {
		fmt.Println("\nString replacements that would be made:")
		for old, new := range replacements {
			if strings.Contains(contentStr, old) {
				fmt.Printf("  %s -> %s\n", old, new)
			}
		}
		fmt.Println("\nWould also update ConfigMap data fields.")
		os.Exit(0)
	}

	for old, new := range replacements {
		contentStr = strings.ReplaceAll(contentStr, old, new)
	}

	// Parse YAML for structured modifications
	var configMap map[string]interface{}
	err = yaml.Unmarshal([]byte(contentStr), &configMap)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing YAML: %v\n", err)
		os.Exit(1)
	}

	// Ensure data section exists
	data, ok := configMap["data"].(map[string]interface{})
	if !ok {
		data = make(map[string]interface{})
		configMap["data"] = data
	}

	// Update the data fields
	data["bpfman.agent.image"] = *agentPullspec
	data["bpfman.image"] = *bpfmanPullspec

	output, err := yaml.Marshal(configMap)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshalling YAML: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile(*outputFile, output, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file %s: %v\n", *outputFile, err)
		os.Exit(1)
	}

	fmt.Printf("ConfigMap file updated successfully: %s\n", *outputFile)
}

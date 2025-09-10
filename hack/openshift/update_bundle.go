package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	defaultImagePullspec = "registry.redhat.io/bpfman/bpfman-rhel9-operator@sha256:277681e5eecc8ef1c21ec7f0668ba28be660f561c6f46feb0fac3f79b473ab5c"
)

func main() {
	var (
		csvFile       = flag.String("csv-file", "", "Path to the CSV file to update")
		imagePullspec = flag.String("image-pullspec", defaultImagePullspec, "Operator image pullspec")
		outputFile    = flag.String("output", "", "Output file (defaults to input file)")
		dryRun        = flag.Bool("dry-run", false, "Show what would be changed without modifying files")
		help          = flag.Bool("help", false, "Show help message")
	)

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <csv-file> [output-file]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Update operator CSV file with Red Hat branding and metadata.\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  %s --csv-file input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --dry-run input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s input.yaml output.yaml\n", os.Args[0])
	}

	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	// Sanitize pullspec by removing leading/trailing whitespace and newlines
	*imagePullspec = strings.TrimSpace(*imagePullspec)

	// Handle positional arguments
	args := flag.Args()
	if *csvFile == "" && len(args) > 0 {
		*csvFile = args[0]
	}
	if *outputFile == "" && len(args) > 1 {
		*outputFile = args[1]
	}

	// Default output to input file if not specified
	if *outputFile == "" {
		*outputFile = *csvFile
	}

	if *csvFile == "" {
		fmt.Fprintf(os.Stderr, "Error: CSV file is required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *dryRun {
		fmt.Printf("Dry run mode: would update %s\n", *csvFile)
		if *outputFile != *csvFile {
			fmt.Printf("Output would be written to: %s\n", *outputFile)
		}
		fmt.Printf("Image pullspec: %s\n", *imagePullspec)
	}

	fmt.Printf("Updating CSV file: %s\n", *csvFile)

	content, err := os.ReadFile(*csvFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", *csvFile, err)
		os.Exit(1)
	}

	contentStr := string(content)

	replacements := map[string]string{
		"quay.io/bpfman/bpfman-operator:latest": fmt.Sprintf("\"%s\"", *imagePullspec),
		"displayName: Bpfman Operator":          "displayName: eBPF Manager Operator",
		"The bpfman Operator":                   "The eBPF manager Operator",
		"name: The bpfman Community":            "name: Red Hat",
		"url: https://bpfman.io":                "url: https://www.redhat.com",
	}

	if *dryRun {
		fmt.Println("\nString replacements that would be made:")
		for old, new := range replacements {
			if strings.Contains(contentStr, old) {
				fmt.Printf("  %s -> %s\n", old, new)
			}
		}
		fmt.Println("\nWould also add architecture labels and OpenShift feature annotations.")
		os.Exit(0)
	}

	for old, new := range replacements {
		contentStr = strings.ReplaceAll(contentStr, old, new)
	}

	// Parse YAML for structured modifications
	var bpfmanOperatorCSV map[string]interface{}
	err = yaml.Unmarshal([]byte(contentStr), &bpfmanOperatorCSV)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing YAML: %v\n", err)
		os.Exit(1)
	}

	timestamp := time.Now()

	metadata, ok := bpfmanOperatorCSV["metadata"].(map[string]interface{})
	if !ok {
		metadata = make(map[string]interface{})
		bpfmanOperatorCSV["metadata"] = metadata
	}

	labels, ok := metadata["labels"].(map[string]interface{})
	if !ok {
		labels = make(map[string]interface{})
		metadata["labels"] = labels
	}

	annotations, ok := metadata["annotations"].(map[string]interface{})
	if !ok {
		annotations = make(map[string]interface{})
		metadata["annotations"] = annotations
	}

	labels["operatorframework.io/arch.amd64"] = "supported"
	labels["operatorframework.io/arch.arm64"] = "supported"
	labels["operatorframework.io/arch.ppc64le"] = "supported"
	labels["operatorframework.io/arch.s390x"] = "supported"
	labels["operatorframework.io/os.linux"] = "supported"

	annotations["createdAt"] = timestamp.Format("02 Jan 2006, 15:04")
	annotations["features.operators.openshift.io/disconnected"] = "true"
	annotations["features.operators.openshift.io/fips-compliant"] = "true"
	annotations["features.operators.openshift.io/proxy-aware"] = "false"
	annotations["features.operators.openshift.io/tls-profiles"] = "false"
	annotations["features.operators.openshift.io/token-auth-aws"] = "false"
	annotations["features.operators.openshift.io/token-auth-azure"] = "false"
	annotations["features.operators.openshift.io/token-auth-gcp"] = "false"

	output, err := yaml.Marshal(bpfmanOperatorCSV)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshalling YAML: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile(*outputFile, output, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file %s: %v\n", *outputFile, err)
		os.Exit(1)
	}

	fmt.Printf("CSV file updated successfully: %s\n", *outputFile)
}

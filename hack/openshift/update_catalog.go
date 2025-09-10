package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

func main() {
	var (
		indexFile        = flag.String("index-file", "", "Path to the catalog index file to update")
		bundlePullspec   = flag.String("bundle-pullspec", "", "Bundle image pullspec")
		operatorPullspec = flag.String("operator-pullspec", "", "Operator image pullspec")
		outputFile       = flag.String("output", "", "Output file (defaults to input file)")
		dryRun           = flag.Bool("dry-run", false, "Show what would be changed without modifying files")
		help             = flag.Bool("help", false, "Show help message")
	)

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <index-file> [output-file]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Update catalog index file with Red Hat image references and timestamps.\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  %s --index-file input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --dry-run input.yaml\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s input.yaml output.yaml\n", os.Args[0])
	}

	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	// Sanitize pullspecs by removing leading/trailing whitespace and newlines
	*bundlePullspec = strings.TrimSpace(*bundlePullspec)
	*operatorPullspec = strings.TrimSpace(*operatorPullspec)

	// Handle positional arguments
	args := flag.Args()
	if *indexFile == "" && len(args) > 0 {
		*indexFile = args[0]
	}
	if *outputFile == "" && len(args) > 1 {
		*outputFile = args[1]
	}

	// Default output to input file if not specified
	if *outputFile == "" {
		*outputFile = *indexFile
	}

	if *indexFile == "" {
		fmt.Fprintf(os.Stderr, "Error: Index file is required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *bundlePullspec == "" {
		fmt.Fprintf(os.Stderr, "Error: Bundle pullspec is required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *operatorPullspec == "" {
		fmt.Fprintf(os.Stderr, "Error: Operator pullspec is required\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *dryRun {
		fmt.Printf("Dry run mode: would update %s\n", *indexFile)
		if *outputFile != *indexFile {
			fmt.Printf("Output would be written to: %s\n", *outputFile)
		}
		fmt.Printf("Bundle pullspec: %s\n", *bundlePullspec)
		fmt.Printf("Operator pullspec: %s\n", *operatorPullspec)
	}

	fmt.Printf("Updating catalog index file: %s\n", *indexFile)

	content, err := os.ReadFile(*indexFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", *indexFile, err)
		os.Exit(1)
	}

	contentStr := string(content)

	// Show before state if dry run
	if *dryRun {
		fmt.Println("\nBEFORE processing:")
		showImageFields(contentStr)
		showCreatedAtFields(contentStr)
	}

	replacements := map[string]string{
		"registry.redhat.io/bpfman/bpfman-operator-bundle@": *bundlePullspec,
		"quay.io/bpfman/bpfman-operator:latest":             *operatorPullspec,
	}

	if *dryRun {
		fmt.Println("\nString replacements that would be made:")
		for pattern, replacement := range replacements {
			if strings.Contains(contentStr, pattern) || strings.Contains(contentStr, "quay.io/bpfman/bpfman-operator:latest") {
				fmt.Printf("  Images matching %s -> %s\n", pattern, replacement)
			}
		}
		fmt.Printf("  createdAt timestamps -> %s\n", time.Now().Format("02 Jan 2006, 15:04"))
		os.Exit(0)
	}

	// Apply string transformations
	contentStr = updateImageReferences(contentStr, *bundlePullspec, *operatorPullspec)
	contentStr = updateTimestamps(contentStr)

	err = os.WriteFile(*outputFile, []byte(contentStr), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file %s: %v\n", *outputFile, err)
		os.Exit(1)
	}

	fmt.Printf("Catalog index file updated successfully: %s\n", *outputFile)

	// Show after state
	fmt.Println("\nAFTER processing:")
	showImageFields(string(contentStr))
	showCreatedAtFields(string(contentStr))
}

func updateImageReferences(content, bundlePullspec, operatorPullspec string) string {
	lines := strings.Split(content, "\n")

	for i, line := range lines {
		// Update bundle image references (preserve existing SHA if present)
		if strings.Contains(line, "image:") && strings.Contains(line, "registry.redhat.io/bpfman/bpfman-operator-bundle@") {
			// Replace the entire SHA part with new pullspec
			parts := strings.Split(line, "registry.redhat.io/bpfman/bpfman-operator-bundle@")
			if len(parts) == 2 {
				prefix := parts[0] + "registry.redhat.io/bpfman/bpfman-operator-bundle@"
				lines[i] = prefix + strings.Split(bundlePullspec, "@")[1]
			}
		} else if strings.Contains(line, "containerImage:") && strings.Contains(line, "quay.io/bpfman/bpfman-operator:latest") {
			// Replace quay.io operator image with Red Hat version
			lines[i] = strings.ReplaceAll(line, "quay.io/bpfman/bpfman-operator:latest", operatorPullspec)
		} else if strings.Contains(line, "image:") && strings.Contains(line, "quay.io/bpfman/bpfman-operator:latest") {
			// Replace quay.io operator image with Red Hat version
			lines[i] = strings.ReplaceAll(line, "quay.io/bpfman/bpfman-operator:latest", operatorPullspec)
		}
	}

	return strings.Join(lines, "\n")
}

func updateTimestamps(content string) string {
	lines := strings.Split(content, "\n")
	timestamp := time.Now().Format("02 Jan 2006, 15:04")

	for i, line := range lines {
		if strings.Contains(line, "createdAt:") {
			// Extract the indentation and replace the timestamp
			parts := strings.SplitN(line, "createdAt:", 2)
			if len(parts) == 2 {
				lines[i] = parts[0] + "createdAt: " + timestamp
			}
		}
	}

	return strings.Join(lines, "\n")
}

func showImageFields(content string) {
	lines := strings.Split(content, "\n")
	fmt.Println("  Image fields:")
	for i, line := range lines {
		if strings.Contains(line, "image:") {
			fmt.Printf("    %d: %s\n", i+1, strings.TrimSpace(line))
		}
	}
}

func showCreatedAtFields(content string) {
	lines := strings.Split(content, "\n")
	fmt.Println("  CreatedAt fields:")
	for i, line := range lines {
		if strings.Contains(line, "createdAt:") {
			fmt.Printf("    %d: %s\n", i+1, strings.TrimSpace(line))
		}
	}
}

package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"epubzip/internal/epub"
)

const version = "0.1.0"

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		printUsage(stderr)
		return 2
	}

	var err error
	switch args[0] {
	case "pack":
		err = runPack(args[1:], stdout, stderr)
	case "unpack":
		err = runUnpack(args[1:], stdout, stderr)
	case "check":
		err = runCheck(args[1:], stdout, stderr)
	case "auto":
		err = runAuto(args[1:], stdout, stderr)
	case "version", "--version", "-version":
		fmt.Fprintf(stdout, "epubzip %s\n", version)
		return 0
	case "help", "--help", "-h":
		printUsage(stdout)
		return 0
	default:
		// A bare path behaves like the original droplet: directories are packed
		// and .epub files are unpacked.
		err = runAuto(args, stdout, stderr)
	}

	if err != nil {
		fmt.Fprintf(stderr, "epubzip: %v\n", err)
		if errors.Is(err, epub.ErrInvalidEPUB) {
			return 1
		}
		return 2
	}
	return 0
}

func runPack(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("pack", flag.ContinueOnError)
	fs.SetOutput(stderr)
	output := fs.String("o", "", "output .epub path (default: beside the source directory)")
	force := fs.Bool("force", false, "replace an existing output file")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("usage: epubzip pack [options] <directory>")
	}

	src := fs.Arg(0)
	dst := *output
	if dst == "" {
		dst = epub.DefaultPackedPath(src)
	}
	if err := epub.Pack(src, dst, epub.PackOptions{Force: *force}); err != nil {
		return err
	}
	fmt.Fprintf(stdout, "created %s\n", dst)
	return nil
}

func runUnpack(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("unpack", flag.ContinueOnError)
	fs.SetOutput(stderr)
	output := fs.String("o", "", "output directory (default: beside the EPUB)")
	force := fs.Bool("force", false, "replace an existing output directory")
	packageDir := fs.Bool("package", false, "name output as <book>_pkg.epub")
	maxFiles := fs.Int("max-files", epub.DefaultLimits.MaxFiles, "maximum archive entries")
	maxFileSize := fs.Int64("max-file-size", epub.DefaultLimits.MaxFileSize, "maximum uncompressed bytes per file")
	maxTotalSize := fs.Int64("max-total-size", epub.DefaultLimits.MaxTotalSize, "maximum total uncompressed bytes")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("usage: epubzip unpack [options] <book.epub>")
	}

	src := fs.Arg(0)
	dst := *output
	if dst == "" {
		dst = epub.DefaultUnpackedPath(src, *packageDir)
	}
	limits := epub.DefaultLimits
	limits.MaxFiles = *maxFiles
	limits.MaxFileSize = *maxFileSize
	limits.MaxTotalSize = *maxTotalSize
	if err := epub.Unpack(src, dst, epub.UnpackOptions{Force: *force, Limits: limits}); err != nil {
		return err
	}
	fmt.Fprintf(stdout, "extracted %s\n", dst)
	return nil
}

func runCheck(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("check", flag.ContinueOnError)
	fs.SetOutput(stderr)
	asJSON := fs.Bool("json", false, "emit machine-readable JSON")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("usage: epubzip check [--json] <book.epub>")
	}

	report, err := epub.Inspect(fs.Arg(0))
	if err != nil {
		return err
	}
	if *asJSON {
		enc := json.NewEncoder(stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(report); err != nil {
			return err
		}
	} else {
		status := "valid"
		if !report.Valid {
			status = "invalid"
		}
		fmt.Fprintf(stdout, "%s: %s (%d entries)\n", status, report.Path, report.EntryCount)
		for _, issue := range report.Issues {
			fmt.Fprintf(stdout, "- %s [%s]: %s\n", issue.Level, issue.Code, issue.Message)
		}
		if len(report.Rootfiles) > 0 {
			fmt.Fprintf(stdout, "rootfiles: %s\n", strings.Join(report.Rootfiles, ", "))
		}
	}
	if !report.Valid {
		return fmt.Errorf("%w: container checks failed", epub.ErrInvalidEPUB)
	}
	return nil
}

func runAuto(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("auto", flag.ContinueOnError)
	fs.SetOutput(stderr)
	force := fs.Bool("force", false, "replace existing outputs")
	packageDir := fs.Bool("package", false, "unpack EPUB files as <book>_pkg.epub")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() == 0 {
		return fmt.Errorf("usage: epubzip auto [options] <path>...")
	}

	for _, input := range fs.Args() {
		info, err := os.Stat(input)
		if err != nil {
			return err
		}
		if info.IsDir() {
			dst := epub.DefaultPackedPath(input)
			if err := epub.Pack(input, dst, epub.PackOptions{Force: *force}); err != nil {
				return fmt.Errorf("pack %s: %w", input, err)
			}
			fmt.Fprintf(stdout, "created %s\n", dst)
			continue
		}
		if !strings.EqualFold(filepath.Ext(input), ".epub") {
			return fmt.Errorf("%s: expected a directory or .epub file", input)
		}
		dst := epub.DefaultUnpackedPath(input, *packageDir)
		if err := epub.Unpack(input, dst, epub.UnpackOptions{Force: *force, Limits: epub.DefaultLimits}); err != nil {
			return fmt.Errorf("unpack %s: %w", input, err)
		}
		fmt.Fprintf(stdout, "extracted %s\n", dst)
	}
	return nil
}

func printUsage(w io.Writer) {
	fmt.Fprintln(w, `epubzip safely packs, unpacks, and checks EPUB containers.

Usage:
  epubzip pack [options] <directory>
  epubzip unpack [options] <book.epub>
  epubzip check [--json] <book.epub>
  epubzip auto [options] <path>...
  epubzip <path>...

Run "epubzip <command> -h" for command options.`)
}

// Command coursegen is the content-pipeline CLI: it imports the vendored
// Fast-Kubernetes snapshot into scaffolded Canonical Markdown, generates
// idempotent SQL fixtures from Canonical Markdown, and audits that every
// vendored upstream file is cited by at least one canonical document's
// source: list.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "generate":
		err = runGenerate(os.Args[2:])
	case "audit":
		err = runAudit(os.Args[2:])
	case "import":
		err = runImport(os.Args[2:])
	case "-h", "--help", "help":
		usage()
		return
	default:
		fmt.Fprintf(os.Stderr, "coursegen: unknown subcommand %q\n\n", os.Args[1])
		usage()
		os.Exit(2)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "coursegen %s: %v\n", os.Args[1], err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `coursegen — MindForge content pipeline CLI

Usage:
  coursegen generate [--in DIR] [--out FILE]
      Render Canonical Markdown under --in into an idempotent SQL fixture at --out.
      Defaults: --in content/courses/fast-kubernetes --out backend/db/fixtures/k8s_fastkube.generated.sql

  coursegen audit [--vendor DIR] [--canonical DIR]
      Cross-check every canonical document's source: list against the vendored
      upstream tree. Exits non-zero and lists any vendored file with zero
      canonical coverage.
      Defaults: --vendor content/fast-kubernetes --canonical content/courses/fast-kubernetes

  coursegen import [--vendor DIR] [--out DIR]
      Scaffold Canonical Markdown from the vendored Fast-Kubernetes snapshot.
      Defaults: --vendor content/fast-kubernetes --out content/courses/fast-kubernetes
`)
}

// newFlagSet returns a flag.FlagSet configured to print this command's own
// usage (via ContinueOnError + a custom Usage func) rather than flag's
// default os.Exit(2)-on-parse-error path swallowing the subcommand name.
func newFlagSet(name string) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	return fs
}

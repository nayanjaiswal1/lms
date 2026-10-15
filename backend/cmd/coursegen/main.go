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
	case "blocks":
		err = runBlocks(os.Args[2:])
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
      Defaults: --in ../content/courses/fast-kubernetes --out db/fixtures/k8s_fastkube.generated.sql

  coursegen audit [--vendor DIR] [--canonical DIR]
      Cross-check every canonical document's source: list against the vendored
      upstream tree. Exits non-zero and lists any vendored file with zero
      canonical coverage.
      Defaults: --vendor ../content/fast-kubernetes --canonical ../content/courses/fast-kubernetes

  coursegen import [--vendor DIR] [--out DIR]
      Scaffold Canonical Markdown from the vendored Fast-Kubernetes snapshot.
      Defaults: --vendor ../content/fast-kubernetes --out ../content/courses/fast-kubernetes

  coursegen blocks sync [--in DIR] [--out FILE] [--dry-run] [--no-upload]
      Validate every lab-authoring block (block.yaml) under --in, upload block
      payloads to the private bundle store (MINIO_* env), and write an
      idempotent SQL fixture at --out. Apply it with scripts/db-seed-courses.sh.
      Same version + different content is a hard error at apply time: bump the version.
      Defaults: --in ../content/lab-blocks --out db/fixtures/lab-blocks.generated.sql

  coursegen blocks verify [--in DIR] [--parallel N] [--report FILE] RECIPE.yaml...
      Build and verify platform recipes against the block tree in local Docker,
      exactly like the lab.recipe_build/lab.recipe_verify jobs (renderer, full
      verification matrix, clean-room grader). Needs the lab image built locally
      (scripts/push-lab-images.sh) and the mindforge-labs network. Exits non-zero
      if any recipe fails. --report writes the JSON reports.

  coursegen blocks verify --artifact DIR [--cache DIR] [--cached-only] [--runtime-id ID]
                          [--courses DIR] [--git-sha SHA] [--ci-build N] [RECIPE.yaml...]
      Same verification, then write a labset to DIR (manifest.json + bundles/):
      the platform-lab release artifact. With no RECIPE args, every recipe a lab
      document under --courses uses. --cache reuses entries
      <recipe_hash>-<runtime_id> instead of verifying again; --cached-only
      assembles from the cache without Docker. The runtime id defaults to the
      stamp in the local lab image. The labset holds graders, fixes and cheat
      overlays: treat it as a secret.
      Defaults: --courses ../content/courses

  coursegen blocks import --expect-runtime-id ID [--partial] DIR|-
      Import a labset ("-" = a tar on stdin) into DATABASE_URL and the private
      bundle store (MINIO_*): checks every sha256 and the runtime id, refuses a
      stale/invalid recipe or a missing platform recipe (--partial lifts only
      the last check, for authoring), uploads the bundles, then records and
      publishes every lab in one transaction. Re-running is a no-op; importing
      an older labset rolls back.
`)
}

// newFlagSet returns a flag.FlagSet that reports parse errors to the caller
// instead of exiting, so main can print them prefixed with the subcommand name.
func newFlagSet(name string) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	return fs
}

// Package importer reads the vendored Fast-Kubernetes snapshot
// (content/fast-kubernetes/) and writes scaffolded canonical markdown files
// under content/courses/fast-kubernetes/. It is a scaffolding aid, not a
// finished-content generator: lesson prose and lab starter files are
// produced at full fidelity, but every lab stub's tasks: list is left
// intentionally empty with a TODO hand-off comment, since verification
// scripts, hints, and explanations require domain judgment this importer
// cannot infer from upstream prose or YAML manifests alone.
package importer

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// defaultLabSetupScript is the placeholder setup_script written into every
// generated lab stub. It only asserts the sandbox's control plane is ready;
// the files: block (populated from the matching labs/<dir>/* manifests) is
// what actually seeds the student's starting workdir once the fixture
// generator writes it into the real setup_script at generation time.
const defaultLabSetupScript = `#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
`

// Import reads the vendored upstream snapshot at vendorDir (expected to be
// content/fast-kubernetes/) and writes one lesson.md plus zero or more
// lab-*.md stubs per Sections entry under outDir (expected to be
// content/courses/fast-kubernetes/), following the hardcoded course/section
// grouping table in sections.go.
//
// This exact signature is depended on by the coursegen import CLI
// subcommand (a parallel workstream) — do not change it without updating
// that caller.
func Import(vendorDir, outDir string) error {
	for _, sec := range Sections {
		lesson, err := buildLesson(vendorDir, sec)
		if err != nil {
			return fmt.Errorf("importer: building lesson for section %q: %w", sec.Slug, err)
		}
		if err := writeLessonFile(outDir, sec, lesson); err != nil {
			return fmt.Errorf("importer: writing lesson for section %q: %w", sec.Slug, err)
		}

		for i, labMeta := range sec.Labs {
			position := i + 1 // lesson occupies position 0 within the section
			labDoc, err := buildLabStub(vendorDir, sec, labMeta, position)
			if err != nil {
				return fmt.Errorf("importer: building lab stub %q for section %q: %w", labMeta.Dir, sec.Slug, err)
			}
			// File numbering: 01 is always the lesson, labs follow in
			// position order (02, 03, ...).
			if err := writeLabFile(outDir, sec, labDoc, labMeta, position+1); err != nil {
				return fmt.Errorf("importer: writing lab stub %q for section %q: %w", labMeta.Dir, sec.Slug, err)
			}
		}
	}
	return nil
}

// buildLesson assembles the canonical.Lesson for sec: its body is the
// concatenation of every file in sec.LessonSources (each preceded by a
// "## <filename>" heading when more than one source is merged), plus, for
// cluster-ops, every create_real_cluster/** script as a fenced reference
// block. Every upstream filename touched is recorded in Source.
func buildLesson(vendorDir string, sec Section) (*canonical.Lesson, error) {
	body, source, err := buildLessonBody(vendorDir, sec)
	if err != nil {
		return nil, err
	}
	return &canonical.Lesson{
		Common: canonical.Common{
			Kind:             canonical.KindLesson,
			IDKey:            fmt.Sprintf("k8s/%s/lesson", sec.Slug),
			Course:           courseSlug,
			Section:          sec.Slug,
			SectionTitle:     sec.Title,
			SectionPosition:  sec.Position,
			Title:            sec.Title,
			Position:         0,
			EstimatedMinutes: estimateLessonMinutes(sec),
			Source:           source,
		},
		Body: body,
	}, nil
}

func buildLessonBody(vendorDir string, sec Section) (string, []string, error) {
	var body strings.Builder
	source := make([]string, 0, len(sec.LessonSources)+len(sec.SourceOnly))

	multi := len(sec.LessonSources) > 1
	for i, fname := range sec.LessonSources {
		content, err := os.ReadFile(filepath.Join(vendorDir, fname))
		if err != nil {
			return "", nil, fmt.Errorf("reading lesson source %q: %w", fname, err)
		}
		if i > 0 {
			body.WriteString("\n\n")
		}
		if multi {
			body.WriteString("## " + humanizeSourceFilename(fname) + "\n\n")
		}
		body.Write(bytes.TrimRight(content, "\n"))
		body.WriteString("\n")
		source = append(source, fname)
	}

	if sec.IncludeClusterScripts {
		scripts, err := clusterScriptFiles(vendorDir)
		if err != nil {
			return "", nil, fmt.Errorf("listing create_real_cluster scripts: %w", err)
		}
		body.WriteString("\n\n## Cluster Setup Reference Scripts\n\n")
		body.WriteString("The scripts below are the upstream repository's `create_real_cluster/` install and master scripts, included verbatim as read-only reference material. Provisioning a real multi-node kubeadm cluster requires bare-metal or multi-VM infrastructure that is out of scope for the single-container lab sandbox, so this content is provided for study rather than wrapped in a graded interactive lab.\n\n")
		for _, rel := range scripts {
			content, err := os.ReadFile(filepath.Join(vendorDir, "create_real_cluster", rel))
			if err != nil {
				return "", nil, fmt.Errorf("reading cluster script %q: %w", rel, err)
			}
			relSlash := filepath.ToSlash(rel)
			body.WriteString(fmt.Sprintf("### create_real_cluster/%s\n\n```%s\n%s\n```\n\n", relSlash, scriptLangFor(rel), strings.TrimRight(string(content), "\n")))
			source = append(source, "create_real_cluster/"+relSlash)
		}
	}

	source = append(source, sec.SourceOnly...)

	return strings.TrimRight(body.String(), "\n") + "\n", source, nil
}

// clusterScriptFiles walks vendorDir/create_real_cluster and returns every
// file's path relative to that directory, sorted for deterministic output.
func clusterScriptFiles(vendorDir string) ([]string, error) {
	root := filepath.Join(vendorDir, "create_real_cluster")
	var rels []string
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, relErr := filepath.Rel(root, path)
		if relErr != nil {
			return relErr
		}
		rels = append(rels, rel)
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(rels)
	return rels, nil
}

func scriptLangFor(rel string) string {
	switch filepath.Ext(rel) {
	case ".sh":
		return "bash"
	case ".ps1":
		return "powershell"
	default:
		return ""
	}
}

// humanizeSourceFilename turns an upstream lesson source filename like
// "K8s-Deployment.md" into a readable merge-point heading ("K8s Deployment")
// instead of leaking the raw filename (with its .md extension) into rendered
// lesson content.
func humanizeSourceFilename(fname string) string {
	name := strings.TrimSuffix(fname, filepath.Ext(fname))
	name = strings.NewReplacer("-", " ", "_", " ").Replace(name)
	return name
}

func estimateLessonMinutes(sec Section) int {
	n := len(sec.LessonSources)
	if n == 0 {
		n = 1
	}
	minutes := 15 * n
	if sec.IncludeClusterScripts {
		minutes += 15
	}
	if minutes < 20 {
		minutes = 20
	}
	return minutes
}

// buildLabStub assembles a WIP canonical.Lab for one labs/<Dir> subdirectory:
// every file in that directory becomes a starter LabFile (path + verbatim
// content) and a Source entry, but Tasks is left empty — grading logic
// requires domain judgment about what to actually verify, which is the
// explicit hand-off point to the content-authoring workstream.
func buildLabStub(vendorDir string, sec Section, labMeta LabMeta, position int) (*canonical.Lab, error) {
	dir := filepath.Join(vendorDir, "labs", labMeta.Dir)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("reading lab directory %q: %w", dir, err)
	}

	var files []canonical.LabFile
	var source []string
	for _, e := range entries {
		if e.IsDir() {
			// Upstream labs/* subdirectories are flat in the vendored
			// snapshot; skip defensively in case that ever changes.
			continue
		}
		content, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return nil, fmt.Errorf("reading lab file %q: %w", e.Name(), err)
		}
		files = append(files, canonical.LabFile{Path: e.Name(), Content: string(content)})
		// source: is checked against paths relative to vendorDir (see
		// coursegen audit), not the bare filename used for LabFile.Path
		// (which is the in-container workdir path, correctly just the name).
		source = append(source, filepath.ToSlash(filepath.Join("labs", labMeta.Dir, e.Name())))
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	sort.Strings(source)

	return &canonical.Lab{
		Common: canonical.Common{
			Kind:             canonical.KindLab,
			IDKey:            fmt.Sprintf("k8s/%s/lab-%s", sec.Slug, labMeta.Dir),
			Course:           courseSlug,
			Section:          sec.Slug,
			SectionTitle:     sec.Title,
			SectionPosition:  sec.Position,
			Title:            fmt.Sprintf("Lab: %s", labMeta.Title),
			Position:         position,
			EstimatedMinutes: 30,
			Source:           source,
		},
		LabType:        "terminal",
		Environment:    "mindforge/lab-k8s:1.31",
		MaxDuration:    60,
		MaxResets:      3,
		HintPenaltyPct: 10,
		IsRequired:     true,
		SetupScript:    defaultLabSetupScript,
		Files:          files,
		Tasks:          []canonical.Task{},
	}, nil
}

// writeLessonFile serializes lesson to canonical markdown and writes it to
// outDir/<section-slug>/01-lesson.md.
func writeLessonFile(outDir string, sec Section, lesson *canonical.Lesson) error {
	fm, err := yaml.Marshal(lesson)
	if err != nil {
		return fmt.Errorf("marshaling lesson frontmatter: %w", err)
	}
	path := filepath.Join(outDir, sec.Slug, "01-lesson.md")
	return writeCanonicalFile(path, fm, lesson.Body)
}

// writeLabFile serializes lab to canonical markdown, injects the
// TODO(authoring) hand-off comment above the empty tasks: [] key, and writes
// it to outDir/<section-slug>/<nn>-lab-<dir>.md.
func writeLabFile(outDir string, sec Section, lab *canonical.Lab, labMeta LabMeta, nn int) error {
	fm, err := yaml.Marshal(lab)
	if err != nil {
		return fmt.Errorf("marshaling lab frontmatter %q: %w", lab.IDKey, err)
	}
	fm = addTasksTODOComment(fm, labMeta.Dir)
	filename := fmt.Sprintf("%02d-lab-%s.md", nn, labMeta.Dir)
	path := filepath.Join(outDir, sec.Slug, filename)
	return writeCanonicalFile(path, fm, "")
}

// addTasksTODOComment inserts the explicit authoring hand-off comment
// immediately above the "tasks: []" line yaml.Marshal produced for an empty
// Tasks slice. This is the only place TODO markers are permitted in this
// pipeline: inside generated markdown content, never in Go source.
func addTasksTODOComment(fmYAML []byte, labDir string) []byte {
	comment := fmt.Sprintf("# TODO(authoring): add tasks — see content/fast-kubernetes/labs/%s/ for the source manifests this lab is based on\n", labDir)
	s := string(fmYAML)
	const marker = "tasks: []"
	idx := strings.Index(s, marker)
	if idx == -1 {
		// Defensive fallback: still emit the comment so the hand-off is
		// never silently dropped, even if yaml.v3's empty-slice rendering
		// ever changes.
		return []byte(s + comment)
	}
	return []byte(s[:idx] + comment + s[idx:])
}

// writeCanonicalFile writes a canonical markdown file: "---\n" + frontmatter
// + "---\n" + an optional blank-line-separated body, matching the shape
// canonical.SplitFrontmatter expects to parse back.
func writeCanonicalFile(path string, frontmatter []byte, body string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("creating output directory for %q: %w", path, err)
	}

	var buf bytes.Buffer
	buf.WriteString("---\n")
	buf.Write(frontmatter)
	if !bytes.HasSuffix(frontmatter, []byte("\n")) {
		buf.WriteString("\n")
	}
	buf.WriteString("---\n")
	if body != "" {
		buf.WriteString("\n")
		buf.WriteString(body)
		if !strings.HasSuffix(body, "\n") {
			buf.WriteString("\n")
		}
	}

	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		return fmt.Errorf("writing %q: %w", path, err)
	}
	return nil
}

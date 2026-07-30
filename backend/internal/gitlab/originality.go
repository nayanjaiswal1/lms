package gitlab

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"path/filepath"
	"strings"
)

// shingleK is the number of consecutive normalized source lines grouped into
// one shingle for the originality scan's Jaccard comparison. 5 is a
// deliberate middle ground: large enough that a shingle captures real
// structure (a single renamed variable inside a 5-line block still leaves
// the surrounding lines matching), small enough that it survives a student
// inserting or deleting a line or two without destroying every shingle in
// the file (a whole-file or whole-function shingle would break on any single
// edit). Per kind-herding-cookie.md §0.6, this is the whole engine — no
// MOSS, no winnowing; if shingling proves gameable in practice the
// documented upgrade path is winnowing fingerprints (subsampling shingles by
// hash instead of keeping all of them), which is orthogonal to this constant.
const shingleK = 5

// originalityMatchThreshold is the minimum Jaccard similarity between two
// files' shingle sets for a match to be persisted. 0.6 is deliberately
// conservative: normalized-line shingling already tolerates reformatting and
// variable renames, so two independently-written solutions to the same
// assignment (sharing only template boilerplate) rarely cross 0.5; above
// 0.6, either a substantial contiguous block or the whole file has been
// copied.
const originalityMatchThreshold = 0.6

// NormalizeSourceLines reduces src to the sequence of lines this package's
// shingling actually compares: trimmed, internal whitespace collapsed to a
// single space (so pure reformatting/re-indentation doesn't change a line's
// identity), blank lines dropped, and single-line-comment-only lines dropped
// (//, #, --, and common block-comment delimiter lines) so an added or
// reworded comment doesn't masquerade as changed content. Deliberately not
// language-aware — no per-language parser, no block-comment state machine —
// per kind-herding-cookie.md §0.6's "don't over-engineer language-aware
// parsing." A determined student could dodge this by reflowing a block
// comment differently; that's exactly the gap the winnowing-fingerprints
// upgrade path exists for, not something this function needs to close.
func NormalizeSourceLines(src string) []string {
	rawLines := strings.Split(src, "\n")
	out := make([]string, 0, len(rawLines))
	for _, line := range rawLines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || isCommentOnlyLine(trimmed) {
			continue
		}
		out = append(out, strings.Join(strings.Fields(trimmed), " "))
	}
	return out
}

func isCommentOnlyLine(trimmed string) bool {
	switch {
	case strings.HasPrefix(trimmed, "//"),
		strings.HasPrefix(trimmed, "#"),
		strings.HasPrefix(trimmed, "--"),
		strings.HasPrefix(trimmed, "/*"),
		strings.HasPrefix(trimmed, "*/"),
		strings.HasPrefix(trimmed, "*"):
		return true
	default:
		return false
	}
}

// Shingles groups normalized lines into overlapping k-line windows and
// returns the set of distinct windows (joined by "\n" as the set key) — the
// standard k-shingling representation used for near-duplicate text
// detection. A file with fewer than k lines produces one shingle of
// everything it has (rather than an empty set), so short files stay
// comparable instead of silently contributing nothing.
func Shingles(lines []string, k int) map[string]struct{} {
	set := map[string]struct{}{}
	if len(lines) == 0 {
		return set
	}
	if k <= 0 {
		k = 1
	}
	if len(lines) <= k {
		set[strings.Join(lines, "\n")] = struct{}{}
		return set
	}
	for i := 0; i+k <= len(lines); i++ {
		set[strings.Join(lines[i:i+k], "\n")] = struct{}{}
	}
	return set
}

// IntersectionSize counts shingles present in both sets — iterates the
// smaller set for a cheap constant-factor speedup, which matters here since
// RunOriginalityScan calls this O(files_a * files_b) times per team pair.
func IntersectionSize(a, b map[string]struct{}) int {
	small, big := a, b
	if len(big) < len(small) {
		small, big = big, small
	}
	count := 0
	for k := range small {
		if _, ok := big[k]; ok {
			count++
		}
	}
	return count
}

// JaccardSimilarity is |A∩B| / |A∪B| for two shingle sets. Zero when either
// side is empty — two empty (or entirely comment/whitespace) files are not
// "100% similar," they're both trivially empty, and treating that as 1.0
// would false-positive on every pair of near-blank files.
func JaccardSimilarity(a, b map[string]struct{}) float64 {
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	inter := IntersectionSize(a, b)
	union := len(a) + len(b) - inter
	if union == 0 {
		return 0
	}
	return float64(inter) / float64(union)
}

// CompareSource is the pure, zero-dependency entrypoint: normalize both
// blobs, shingle both, and return their Jaccard similarity plus the number
// of shingles they share (the originality_test.go unit test calls this
// directly — no DB, no GitLab client, no archive involved).
func CompareSource(a, b string) (similarity float64, matchedShingles int) {
	setA := Shingles(NormalizeSourceLines(a), shingleK)
	setB := Shingles(NormalizeSourceLines(b), shingleK)
	return JaccardSimilarity(setA, setB), IntersectionSize(setA, setB)
}

// ─── archive extraction (stdlib archive/tar + compress/gzip) ───────────────

const (
	// maxOriginalityFileBytes skips any single file over this size — binary
	// assets and vendored bundles are the overwhelmingly common case above
	// this size, not source a student wrote by hand.
	// ponytail: raise if a legitimate large source file gets skipped.
	maxOriginalityFileBytes = 512 * 1024

	// maxOriginalityFilesPerProject bounds the pairwise file-compare cost per
	// project pair (comparisons are O(files_a * files_b)).
	// ponytail: raise, or move to MinHash bucketing, if a real assignment's
	// repo legitimately exceeds this file count.
	maxOriginalityFilesPerProject = 300
)

// binaryExtensions is a small denylist of common non-source file types —
// deliberately not exhaustive (see isLikelyText for the fallback sniff).
var binaryExtensions = map[string]bool{
	".png": true, ".jpg": true, ".jpeg": true, ".gif": true, ".ico": true, ".svg": true,
	".pdf": true, ".zip": true, ".gz": true, ".tar": true, ".woff": true, ".woff2": true,
	".ttf": true, ".eot": true, ".mp4": true, ".mp3": true, ".wasm": true, ".exe": true,
	".dll": true, ".so": true, ".dylib": true, ".class": true, ".jar": true, ".lock": true,
}

// skipPathSegments excludes common dependency/build-output directories that
// would otherwise dominate every comparison with template-identical noise
// neither team actually wrote.
var skipPathSegments = []string{"/.git/", "/node_modules/", "/vendor/", "/dist/", "/build/", "/.next/", "/target/"}

// ExtractSourceFiles reads a GitLab repository archive (tar.gz, as returned
// by Client.DownloadArchive) and returns a path -> content map of the files
// worth originality-scanning. Filters are deliberately simple, not
// language-aware source detection: skip directory entries, skip common
// binary/asset extensions and dependency/build directories, skip anything
// over maxOriginalityFileBytes, and cap the total file count at
// maxOriginalityFilesPerProject. GitLab's archive wraps every entry in a
// single top-level "<project>-<sha>/" directory, stripped here so paths
// compare cleanly across two different projects' archives of "the same"
// file (e.g. both projects' "src/main.go").
func ExtractSourceFiles(archive []byte) (map[string]string, error) {
	gz, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		return nil, fmt.Errorf("gitlab: open archive gzip stream: %w", err)
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	out := map[string]string{}
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("gitlab: read archive entry: %w", err)
		}
		if hdr.Typeflag != tar.TypeReg {
			continue
		}
		if hdr.Size <= 0 || hdr.Size > maxOriginalityFileBytes {
			continue
		}
		path := stripArchiveRoot(hdr.Name)
		if path == "" || shouldSkipPath(path) || len(out) >= maxOriginalityFilesPerProject {
			continue
		}
		content, err := io.ReadAll(io.LimitReader(tr, maxOriginalityFileBytes))
		if err != nil {
			return nil, fmt.Errorf("gitlab: read archive file %q: %w", hdr.Name, err)
		}
		if !isLikelyText(content) {
			continue
		}
		out[path] = string(content)
	}
	return out, nil
}

// stripArchiveRoot drops GitLab archive's single top-level
// "<project>-<sha>/" directory component. Returns "" for anything that is
// only that root itself (no path left).
func stripArchiveRoot(name string) string {
	parts := strings.SplitN(name, "/", 2)
	if len(parts) != 2 || parts[1] == "" {
		return ""
	}
	return parts[1]
}

func shouldSkipPath(path string) bool {
	if binaryExtensions[strings.ToLower(filepath.Ext(path))] {
		return true
	}
	withSlashes := "/" + path + "/"
	for _, seg := range skipPathSegments {
		if strings.Contains(withSlashes, seg) {
			return true
		}
	}
	return false
}

// isLikelyText is a cheap binary sniff (a NUL byte anywhere in the first
// chunk) rather than a full content-type detector — good enough to catch
// binary files the extension denylist misses (e.g. an extension-less
// binary).
func isLikelyText(content []byte) bool {
	limit := len(content)
	if limit > 8000 {
		limit = 8000
	}
	for _, b := range content[:limit] {
		if b == 0 {
			return false
		}
	}
	return true
}

// Package canonical is the schema authority for Canonical Markdown, the
// frontmatter+body format MindForge course content is authored in. Both the
// importer (upstream repo -> canonical markdown) and the generator (canonical
// markdown -> SQL fixtures) depend on this package, so it stays a leaf: no
// imports of other backend domain packages, content-agnostic (no
// Kubernetes-specific logic).
package canonical

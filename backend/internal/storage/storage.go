package storage

import (
	"context"
	"io"
	"time"
)

// StorageClient is the provider-agnostic interface for object storage.
type StorageClient interface {
	// Upload stores the content of r under key and returns its public URL.
	Upload(ctx context.Context, key, contentType string, r io.Reader, size int64) (string, error)
	// Download reads back the full object stored at key — used server-side
	// (e.g. the captures pipeline reading an uploaded image/PDF for AI
	// processing) where a redirect-to-browser presigned URL doesn't apply.
	Download(ctx context.Context, key string) ([]byte, error)
	// Delete removes key. Returns nil if the key does not exist.
	Delete(ctx context.Context, key string) error
	// PresignedPutURL returns a time-limited URL for a client to PUT an object directly.
	PresignedPutURL(ctx context.Context, key, mimeType string, maxBytes int64) (string, error)
	// PresignedGetURL returns a time-limited URL for a client to GET an object.
	PresignedGetURL(ctx context.Context, key string, ttl time.Duration) (string, error)
}

// ErrStorageUnavailable is returned by NoopClient presigned methods.
var ErrStorageUnavailable = errStorageUnavailable{}

type errStorageUnavailable struct{}

func (e errStorageUnavailable) Error() string { return "storage: unavailable" }

// PrivateStore is a narrower interface than StorageClient for objects that
// must never be reachable by a public bucket policy or a presigned URL — the
// lab-kind bundle store (docs/debug-labs.md §B5): grader bundles contain
// hidden tests and reference fixes, and workspace bundles are only ever
// streamed server-side into a container, never fetched by a browser.
// Deliberately has no presigned-URL methods: the only way data moves through
// this interface is a server-side Upload/Download/Delete call.
type PrivateStore interface {
	// Upload stores r under key (idempotent — callers use a content-addressed
	// key, e.g. "lab-bundles/<sha256>.tar.gz", so re-uploading identical
	// content is a safe no-op overwrite of the same bytes).
	Upload(ctx context.Context, key, contentType string, r io.Reader, size int64) error
	// Download reads back the full object stored at key.
	Download(ctx context.Context, key string) ([]byte, error)
	// Delete removes key. Returns nil if the key does not exist.
	Delete(ctx context.Context, key string) error
	// List returns every object whose key starts with prefix — used only by
	// the orphan-GC job.
	List(ctx context.Context, prefix string) ([]PrivateObject, error)
}

// PrivateObject is one listed object in a PrivateStore.
type PrivateObject struct {
	Key          string
	LastModified time.Time
}

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

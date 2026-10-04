package storage

import (
	"context"
	"io"
	"time"
)

type NoopClient struct{}

func (n *NoopClient) Upload(_ context.Context, key, _ string, _ io.Reader, _ int64) (string, error) {
	return "https://test-storage/" + key, nil
}

func (n *NoopClient) Download(_ context.Context, _ string) ([]byte, error) {
	return nil, ErrStorageUnavailable
}

func (n *NoopClient) Delete(_ context.Context, _ string) error {
	return nil
}

func (n *NoopClient) PresignedPutURL(_ context.Context, key, _ string, _ int64) (string, error) {
	return "", ErrStorageUnavailable
}

func (n *NoopClient) PresignedGetURL(_ context.Context, key string, _ time.Duration) (string, error) {
	return "https://test-storage/" + key, nil
}

// NoopPrivateClient implements PrivateStore when MinIO isn't configured
// (MinioAccessKey empty — see config.Config's doc comment). Lab-kind builds
// simply cannot upload/grade bundles in that deploy, same degrade-gracefully
// policy every other storage-backed feature already follows.
type NoopPrivateClient struct{}

func (n *NoopPrivateClient) Upload(_ context.Context, _, _ string, _ io.Reader, _ int64) error {
	return ErrStorageUnavailable
}

func (n *NoopPrivateClient) Download(_ context.Context, _ string) ([]byte, error) {
	return nil, ErrStorageUnavailable
}

func (n *NoopPrivateClient) Delete(_ context.Context, _ string) error {
	return nil
}

func (n *NoopPrivateClient) List(_ context.Context, _ string) ([]PrivateObject, error) {
	return nil, nil
}

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

func (n *NoopClient) Delete(_ context.Context, _ string) error {
	return nil
}

func (n *NoopClient) PresignedPutURL(_ context.Context, key, _ string, _ int64) (string, error) {
	return "", ErrStorageUnavailable
}

func (n *NoopClient) PresignedGetURL(_ context.Context, key string, _ time.Duration) (string, error) {
	return "https://test-storage/" + key, nil
}

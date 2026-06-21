package storage

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type MinioClient struct {
	client   *minio.Client
	bucket   string
	endpoint string
	useSSL   bool
}

func NewMinioClient(cfg *config.Config) (*MinioClient, error) {
	client, err := minio.New(cfg.MinioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinioAccessKey, cfg.MinioSecretKey, ""),
		Secure: cfg.MinioUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("storage: minio init: %w", err)
	}
	return &MinioClient{
		client:   client,
		bucket:   cfg.MinioBucket,
		endpoint: cfg.MinioEndpoint,
		useSSL:   cfg.MinioUseSSL,
	}, nil
}

func (m *MinioClient) EnsureBucket(ctx context.Context) error {
	exists, err := m.client.BucketExists(ctx, m.bucket)
	if err != nil {
		return fmt.Errorf("storage: check bucket %q: %w", m.bucket, err)
	}
	if exists {
		return nil
	}
	if err := m.client.MakeBucket(ctx, m.bucket, minio.MakeBucketOptions{}); err != nil {
		return fmt.Errorf("storage: create bucket %q: %w", m.bucket, err)
	}
	policy := `{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::` + m.bucket + `/*"]}]}`
	if err := m.client.SetBucketPolicy(ctx, m.bucket, policy); err != nil {
		return fmt.Errorf("storage: set bucket policy: %w", err)
	}
	return nil
}

func (m *MinioClient) Upload(ctx context.Context, key, contentType string, r io.Reader, size int64) (string, error) {
	_, err := m.client.PutObject(ctx, m.bucket, key, r, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("storage: upload %q: %w", key, err)
	}
	scheme := "http"
	if m.useSSL {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s/%s/%s", scheme, m.endpoint, m.bucket, key), nil
}

func (m *MinioClient) Delete(ctx context.Context, key string) error {
	err := m.client.RemoveObject(ctx, m.bucket, key, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("storage: delete %q: %w", key, err)
	}
	return nil
}

func (m *MinioClient) PresignedPutURL(ctx context.Context, key, mimeType string, maxBytes int64) (string, error) {
	params := url.Values{}
	params.Set("Content-Type", mimeType)
	u, err := m.client.PresignedPutObject(ctx, m.bucket, key, 30*time.Minute)
	if err != nil {
		return "", fmt.Errorf("storage: presigned put %q: %w", key, err)
	}
	return u.String(), nil
}

func (m *MinioClient) PresignedGetURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	u, err := m.client.PresignedGetObject(ctx, m.bucket, key, ttl, nil)
	if err != nil {
		return "", fmt.Errorf("storage: presigned get %q: %w", key, err)
	}
	return u.String(), nil
}

package courses

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"regexp"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/storage"
)

type Service struct {
	repo  *Repo
	store storage.StorageClient
	ai    ai.LLMProvider
	cfg   *config.Config
}

func NewService(repo *Repo, store storage.StorageClient, aiProvider ai.LLMProvider, cfg *config.Config) *Service {
	return &Service{repo: repo, store: store, ai: aiProvider, cfg: cfg}
}

// GetModuleContent verifies access and returns module content + presigned URL when needed.
func (s *Service) GetModuleContent(ctx context.Context, orgID, userID, moduleID string) (ModuleContent, error) {
	m, err := s.repo.GetModule(ctx, orgID, moduleID)
	if err != nil {
		return ModuleContent{}, err
	}

	if !m.IsFreePreview {
		enrolled, err := s.repo.IsEnrolled(ctx, userID, m.CourseID)
		if err != nil {
			return ModuleContent{}, err
		}
		if !enrolled {
			return ModuleContent{}, ErrForbidden
		}
	}

	mc := ModuleContent{Module: m}

	if m.StorageKey != nil && *m.StorageKey != "" {
		url, err := s.store.PresignedGetURL(ctx, *m.StorageKey, time.Hour)
		if err == nil {
			mc.ContentURL = &url
		}
	}

	return mc, nil
}

// PresignedUploadURL returns a presigned PUT URL and the resulting storage key for a course asset.
func (s *Service) PresignedUploadURL(ctx context.Context, orgID, courseID, moduleID, mimeType string) (string, string, error) {
	ext := mimeExtension(mimeType)
	key := "orgs/" + orgID + "/courses/" + courseID + "/modules/" + moduleID + "/" + randomHex(8) + ext
	url, err := s.store.PresignedPutURL(ctx, key, mimeType, 2*1024*1024*1024)
	if err != nil {
		return "", "", err
	}
	return url, key, nil
}

// UploadAsset stores an uploaded file and returns its public URL and storage key.
func (s *Service) UploadAsset(ctx context.Context, orgID, filename, contentType string, size int64, r io.Reader) (string, string, error) {
	ext := mimeExtension(contentType)
	if ext == "" {
		if i := strings.LastIndex(filename, "."); i >= 0 && i < len(filename)-1 {
			ext = filename[i:]
		}
	}
	key := "orgs/" + orgID + "/uploads/" + randomHex(16) + ext
	url, err := s.store.Upload(ctx, key, contentType, r, size)
	if err != nil {
		return "", "", fmt.Errorf("upload asset: %w", err)
	}
	return url, key, nil
}

var mimeExtMap = map[string]string{
	"video/mp4":       ".mp4",
	"video/webm":      ".webm",
	"application/pdf": ".pdf",
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
	"image/webp":      ".webp",
}

func mimeExtension(mimeType string) string {
	if ext, ok := mimeExtMap[strings.ToLower(mimeType)]; ok {
		return ext
	}
	return ""
}

func randomHex(n int) string {
	buf := make([]byte, n)
	rand.Read(buf)
	return hex.EncodeToString(buf)
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

// Slugify produces a URL-safe slug with a random suffix to avoid collisions.
func Slugify(s string) string {
	base := slugRe.ReplaceAllString(strings.ToLower(strings.TrimSpace(s)), "-")
	base = strings.Trim(base, "-")
	if base == "" {
		base = "course"
	}
	if len(base) > 60 {
		base = base[:60]
	}
	return base + "-" + randomHex(4)
}

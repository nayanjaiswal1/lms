package profile

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	_ "image/png" // register PNG decoder
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/storage"
)

const (
	maxAvatarBytes   = 5 << 20 // 5 MB
	avatarOutputSize = 256
	avatarKeyPrefix  = "avatars"
)

var (
	slugNonAlphaNum = regexp.MustCompile(`[^a-z0-9-]+`)
	slugMultiHyphen = regexp.MustCompile(`-{2,}`)
)

// Service implements the profile domain business logic.
type Service struct {
	repo    *Repo
	storage storage.StorageClient
	cfg     *config.Config
}

// NewService constructs a Service.
func NewService(repo *Repo, store storage.StorageClient, cfg *config.Config) *Service {
	return &Service{repo: repo, storage: store, cfg: cfg}
}

// ─── GetMyProfile ─────────────────────────────────────────────────────────────

// GetMyProfile returns the full private profile for userID, including skills,
// social links, stats, and a computed completion score.
func (s *Service) GetMyProfile(ctx context.Context, userID string) (*Profile, error) {
	prof, err := s.repo.GetProfile(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get my profile: %w", err)
	}

	skills, err := s.repo.GetSkills(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get skills: %w", err)
	}
	prof.Skills = skills

	socialLinks, err := s.repo.GetSocialLinks(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get social links: %w", err)
	}
	prof.SocialLinks = socialLinks

	stats, err := s.repo.GetStats(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("profile: get stats: %w", err)
	}
	prof.Stats = stats

	prof.CompletionScore = computeCompletion(prof)
	return prof, nil
}

// ─── UpdateProfile ────────────────────────────────────────────────────────────

// UpdateProfile validates input, writes the profile (and optionally social
// links) inside a transaction when social link fields are present, then returns
// the refreshed profile.
func (s *Service) UpdateProfile(ctx context.Context, userID string, input UpdateProfileInput) (*Profile, error) {
	if err := validateProfileInput(input); err != nil {
		return nil, err
	}

	hasSocialLinks := input.LinkedIn != nil || input.GitHub != nil || input.Portfolio != nil

	// When display_name is being set, derive and persist the slug first.
	var slug string
	if input.DisplayName != nil && *input.DisplayName != "" {
		var err error
		slug, err = s.generateSlug(ctx, *input.DisplayName)
		if err != nil {
			return nil, fmt.Errorf("profile: generate slug: %w", err)
		}
	}

	if hasSocialLinks {
		// Write profile + social links atomically inside a transaction.
		if err := s.repo.txUpdateWithLinks(ctx, userID, input, slug); err != nil {
			return nil, err
		}
	} else {
		if err := s.repo.UpsertProfile(ctx, nil, userID, input); err != nil {
			return nil, err
		}
		if slug != "" {
			if err := s.repo.UpsertProfileSlug(ctx, userID, slug); err != nil {
				return nil, err
			}
		}
	}

	return s.GetMyProfile(ctx, userID)
}

// ─── UploadAvatar ─────────────────────────────────────────────────────────────

// UploadAvatar reads, validates, resizes, and uploads an avatar image.
// Replaces any existing avatar in storage. Returns the new public URL.
func (s *Service) UploadAvatar(ctx context.Context, userID string, r io.Reader, size int64) (string, error) {
	if size > maxAvatarBytes {
		return "", fmt.Errorf("profile: avatar must be under 5 MB")
	}

	// Read into memory (bounded by maxAvatarBytes + 1 to catch oversized uploads).
	limited := io.LimitReader(r, maxAvatarBytes+1)
	data, err := io.ReadAll(limited)
	if err != nil {
		return "", fmt.Errorf("profile: read avatar bytes: %w", err)
	}
	if int64(len(data)) > maxAvatarBytes {
		return "", fmt.Errorf("profile: avatar must be under 5 MB")
	}

	// Detect MIME type from the first 512 bytes.
	detected := http.DetectContentType(data[:min(512, len(data))])
	if detected != "image/jpeg" && detected != "image/png" && detected != "image/webp" {
		return "", fmt.Errorf("profile: only JPEG, PNG, and WebP avatars are supported")
	}

	// Generate a unique key.
	rndHex, err := randomHex(16)
	if err != nil {
		return "", fmt.Errorf("profile: generate avatar key: %w", err)
	}

	// WebP images cannot be decoded by the standard library — upload the validated
	// bytes as-is without resizing. JPEG and PNG are normalised to a square JPEG.
	var uploadData []byte
	var uploadMime string
	var ext string
	if detected == "image/webp" {
		uploadData = data
		uploadMime = "image/webp"
		ext = ".webp"
	} else {
		// Decode the image.
		img, _, err := image.Decode(bytes.NewReader(data))
		if err != nil {
			return "", fmt.Errorf("profile: decode avatar image: %w", err)
		}

		// Resize to avatarOutputSize x avatarOutputSize using nearest-neighbor scaling.
		resized := resizeNearest(img, avatarOutputSize, avatarOutputSize)

		// Encode as JPEG at quality 85.
		var buf bytes.Buffer
		if err := jpeg.Encode(&buf, resized, &jpeg.Options{Quality: 85}); err != nil {
			return "", fmt.Errorf("profile: encode avatar jpeg: %w", err)
		}
		uploadData = buf.Bytes()
		uploadMime = "image/jpeg"
		ext = ".jpg"
	}

	// Delete old avatar from storage (fire-and-forget if it fails — old object stays).
	oldURL, err := s.repo.getOldAvatarURL(ctx, userID)
	if err != nil {
		return "", fmt.Errorf("profile: read old avatar url: %w", err)
	}

	key := fmt.Sprintf("%s/%s/%s%s", avatarKeyPrefix, userID, rndHex, ext)

	// Upload to storage.
	publicURL, err := s.storage.Upload(ctx, key, uploadMime, bytes.NewReader(uploadData), int64(len(uploadData)))
	if err != nil {
		return "", fmt.Errorf("profile: upload avatar: %w", err)
	}

	// Persist new URL.
	if err := s.repo.UpdateAvatar(ctx, userID, publicURL); err != nil {
		// Best-effort delete the just-uploaded object to avoid orphans.
		_ = s.storage.Delete(ctx, key)
		return "", fmt.Errorf("profile: save avatar url: %w", err)
	}

	// Remove old object from storage after the DB is updated.
	if oldURL != "" {
		oldKey := extractMinioKey(oldURL)
		if oldKey != "" {
			_ = s.storage.Delete(ctx, oldKey)
		}
	}

	return publicURL, nil
}

// ─── DeleteAvatar ─────────────────────────────────────────────────────────────

// DeleteAvatar removes the user's avatar from both storage and the DB.
func (s *Service) DeleteAvatar(ctx context.Context, userID string) error {
	oldURL, err := s.repo.DeleteAvatar(ctx, userID)
	if err != nil {
		return fmt.Errorf("profile: delete avatar db: %w", err)
	}
	if oldURL == "" {
		return nil
	}
	key := extractMinioKey(oldURL)
	if key == "" {
		return nil
	}
	if err := s.storage.Delete(ctx, key); err != nil {
		return fmt.Errorf("profile: delete avatar storage: %w", err)
	}
	return nil
}

// ─── Skills ───────────────────────────────────────────────────────────────────

// AddSkill validates and adds a skill to the user's profile.
func (s *Service) AddSkill(ctx context.Context, userID string, input AddSkillInput) (*Skill, error) {
	input.SkillName = strings.TrimSpace(input.SkillName)
	if input.SkillName == "" {
		return nil, fmt.Errorf("profile: skill name is required")
	}
	if len(input.SkillName) > 100 {
		return nil, fmt.Errorf("profile: skill name must be 100 characters or fewer")
	}
	if !contains(ValidSkillLevels, input.SkillLevel) {
		return nil, fmt.Errorf("profile: skill level must be one of: %s", strings.Join(ValidSkillLevels, ", "))
	}

	skill, err := s.repo.AddSkill(ctx, userID, input)
	if err != nil {
		if errors.Is(err, ErrConflict) {
			return nil, fmt.Errorf("profile: skill already added: %w", ErrConflict)
		}
		return nil, fmt.Errorf("profile: add skill: %w", err)
	}
	return skill, nil
}

// RemoveSkill deletes a skill by ID from the user's profile.
func (s *Service) RemoveSkill(ctx context.Context, userID, skillID string) error {
	if err := s.repo.RemoveSkill(ctx, userID, skillID); err != nil {
		return fmt.Errorf("profile: remove skill: %w", err)
	}
	return nil
}

// ─── Public profile ───────────────────────────────────────────────────────────

// GetPublicProfile returns the public-facing profile for the given slug.
// Returns ErrNotFound when public_enabled is false (hides existence).
func (s *Service) GetPublicProfile(ctx context.Context, slug string) (*PublicProfile, error) {
	prof, err := s.repo.GetBySlug(ctx, slug)
	if err != nil {
		return nil, fmt.Errorf("profile: get by slug: %w", err)
	}
	if !prof.PublicEnabled {
		return nil, ErrNotFound
	}

	pub := &PublicProfile{
		Name:            prof.Name,
		DisplayName:     prof.DisplayName,
		AvatarURL:       prof.AvatarURL,
		Bio:             prof.Bio,
		ExperienceLevel: prof.ExperienceLevel,
		CurrentRole:     prof.CurrentRole,
	}

	if prof.ShowSkills {
		skills, err := s.repo.GetSkills(ctx, prof.UserID)
		if err != nil {
			return nil, fmt.Errorf("profile: get public skills: %w", err)
		}
		pub.Skills = skills
	}

	if prof.ShowActivity {
		stats, err := s.repo.GetStats(ctx, prof.UserID)
		if err != nil {
			return nil, fmt.Errorf("profile: get public stats: %w", err)
		}
		pub.Stats = stats
	}

	// Social links are always public contact info when present.
	socialLinks, err := s.repo.GetSocialLinks(ctx, prof.UserID)
	if err != nil {
		return nil, fmt.Errorf("profile: get public social links: %w", err)
	}
	pub.SocialLinks = socialLinks

	return pub, nil
}

// ─── GetUserProfile ───────────────────────────────────────────────────────────

// GetUserProfile returns the full profile for targetUserID. The requester must
// be the target themselves, a super_admin, or an org admin.
func (s *Service) GetUserProfile(ctx context.Context, requesterUserID, requesterPlatformRole, requesterOrgRole, targetUserID string) (*Profile, error) {
	if requesterUserID == targetUserID {
		return s.GetMyProfile(ctx, targetUserID)
	}
	if requesterPlatformRole == "super_admin" || requesterOrgRole == "admin" {
		return s.GetMyProfile(ctx, targetUserID)
	}
	return nil, ErrForbidden
}

// ─── computeCompletion ────────────────────────────────────────────────────────

// computeCompletion scores the profile 0–100 based on filled-in sections.
//
//   - Avatar:          10 pts
//   - Bio:             10 pts
//   - Skills ≥ 1:      10 pts;  Skills ≥ 3: +15 pts (25 total)
//   - LearningGoal:    25 pts
//   - TopicsInterest:  20 pts
//   - SocialLinks:     10 pts
func computeCompletion(p *Profile) int {
	var score int

	if p.AvatarURL != nil && *p.AvatarURL != "" {
		score += 10
	}
	if p.Bio != nil && *p.Bio != "" {
		score += 10
	}
	skillCount := len(p.Skills)
	if skillCount >= 1 {
		score += 10
	}
	if skillCount >= 3 {
		score += 15
	}
	if p.LearningGoal != nil && *p.LearningGoal != "" {
		score += 25
	}
	if len(p.TopicsInterest) >= 1 {
		score += 20
	}
	if p.SocialLinks != nil && (p.SocialLinks.LinkedIn != nil || p.SocialLinks.GitHub != nil || p.SocialLinks.Portfolio != nil) {
		score += 10
	}

	if score > 100 {
		score = 100
	}
	return score
}

// ─── generateSlug ─────────────────────────────────────────────────────────────

// generateSlug derives a unique URL-safe slug from displayName.
// Tries slug, slug-2, ..., slug-10 before appending a random suffix.
func (s *Service) generateSlug(ctx context.Context, displayName string) (string, error) {
	base := strings.ToLower(displayName)
	base = strings.ReplaceAll(base, " ", "-")
	base = slugNonAlphaNum.ReplaceAllString(base, "")
	base = slugMultiHyphen.ReplaceAllString(base, "-")
	base = strings.Trim(base, "-")

	if base == "" {
		rnd, err := randomHex(4)
		if err != nil {
			return "", fmt.Errorf("profile: generate random slug: %w", err)
		}
		return "user-" + rnd, nil
	}

	// Try the base slug first.
	taken, err := s.repo.SlugExists(ctx, base)
	if err != nil {
		return "", fmt.Errorf("profile: check slug: %w", err)
	}
	if !taken {
		return base, nil
	}

	// Try base-2 through base-10.
	for i := 2; i <= 10; i++ {
		candidate := fmt.Sprintf("%s-%d", base, i)
		taken, err := s.repo.SlugExists(ctx, candidate)
		if err != nil {
			return "", fmt.Errorf("profile: check slug: %w", err)
		}
		if !taken {
			return candidate, nil
		}
	}

	// All collide — append random suffix.
	rnd, err := randomHex(4)
	if err != nil {
		return "", fmt.Errorf("profile: generate slug suffix: %w", err)
	}
	return base + "-" + rnd, nil
}

// ─── extractMinioKey ─────────────────────────────────────────────────────────

// extractMinioKey derives the object key from a public MinIO URL.
// e.g. "http://minio:9000/mindforge/avatars/abc.jpg" → "avatars/abc.jpg"
func extractMinioKey(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	// Path is /<bucket>/<key>; strip the leading "/" and the bucket segment.
	parts := strings.SplitN(strings.TrimPrefix(u.Path, "/"), "/", 2)
	if len(parts) < 2 {
		return ""
	}
	return parts[1]
}

// ─── resizeNearest ───────────────────────────────────────────────────────────

// resizeNearest scales src to dstW×dstH using nearest-neighbor interpolation.
// Uses only the standard library image/draw package.
func resizeNearest(src image.Image, dstW, dstH int) image.Image {
	srcBounds := src.Bounds()
	srcW := srcBounds.Max.X - srcBounds.Min.X
	srcH := srcBounds.Max.Y - srcBounds.Min.Y

	if srcW == dstW && srcH == dstH {
		// No resize needed — draw into an RGBA to normalise the format.
		dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
		draw.Draw(dst, dst.Bounds(), src, srcBounds.Min, draw.Src)
		return dst
	}

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	for y := 0; y < dstH; y++ {
		srcY := srcBounds.Min.Y + (y*srcH)/dstH
		for x := 0; x < dstW; x++ {
			srcX := srcBounds.Min.X + (x*srcW)/dstW
			r, g, b, a := src.At(srcX, srcY).RGBA()
			dst.SetRGBA(x, y, color.RGBA{
				R: uint8(r >> 8),
				G: uint8(g >> 8),
				B: uint8(b >> 8),
				A: uint8(a >> 8),
			})
		}
	}
	return dst
}

// ─── validateProfileInput ────────────────────────────────────────────────────

func validateProfileInput(input UpdateProfileInput) error {
	if input.ExperienceLevel != nil && !contains(ValidExperienceLevels, *input.ExperienceLevel) {
		return fmt.Errorf("profile: experience_level must be one of: %s", strings.Join(ValidExperienceLevels, ", "))
	}
	if input.PreferredLearningStyle != nil && !contains(ValidLearningStyles, *input.PreferredLearningStyle) {
		return fmt.Errorf("profile: preferred_learning_style must be one of: %s", strings.Join(ValidLearningStyles, ", "))
	}
	if input.YearsOfExperience != nil && (*input.YearsOfExperience < 0 || *input.YearsOfExperience > 50) {
		return fmt.Errorf("profile: years_of_experience must be between 0 and 50")
	}
	if input.Bio != nil && len(*input.Bio) > 500 {
		return fmt.Errorf("profile: bio must be 500 characters or fewer")
	}
	if input.WeeklyGoalHrs != nil && (*input.WeeklyGoalHrs < 1 || *input.WeeklyGoalHrs > 168) {
		return fmt.Errorf("profile: weekly_goal_hrs must be between 1 and 168")
	}
	if input.LinkedIn != nil {
		if err := validateHTTPSURL(*input.LinkedIn); err != nil {
			return fmt.Errorf("profile: linkedin: %w", err)
		}
	}
	if input.GitHub != nil {
		if err := validateHTTPSURL(*input.GitHub); err != nil {
			return fmt.Errorf("profile: github: %w", err)
		}
	}
	if input.Portfolio != nil {
		if err := validateHTTPSURL(*input.Portfolio); err != nil {
			return fmt.Errorf("profile: portfolio: %w", err)
		}
	}
	return nil
}

func validateHTTPSURL(raw string) error {
	u, err := url.ParseRequestURI(raw)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		return fmt.Errorf("must be a valid URL")
	}
	return nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func contains(slice []string, val string) bool {
	for _, s := range slice {
		if s == val {
			return true
		}
	}
	return false
}

func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

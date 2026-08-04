package privacy

import (
	"context"
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"

	"github.com/mindforge/backend/internal/authz"
)

// ErrWrongPassword is returned when the password re-entry required to delete
// a password-based account doesn't match.
var ErrWrongPassword = errors.New("privacy: wrong password")

// deletionReason is stored in users.status_reason — operator-facing context
// for why the account is deactivated, same field admin-triggered lock/
// suspend already use (see authz.AdminRepo.SetUserStatus).
const deletionReason = "self-service account deletion (data erasure request)"

type Service struct {
	repo      *Repo
	adminRepo *authz.AdminRepo
}

func NewService(repo *Repo, adminRepo *authz.AdminRepo) *Service {
	return &Service{repo: repo, adminRepo: adminRepo}
}

// Export returns the caller's full exportable data bundle.
func (s *Service) Export(ctx context.Context, userID string) (map[string]any, error) {
	return s.repo.ExportData(ctx, userID)
}

// DeleteAccount anonymizes userID's personal data and kills every active
// session. password is required and verified when the account has one
// (password_hash set); social/passkey-only accounts have nothing to verify
// against, so the caller's already-authenticated session is the boundary —
// the same posture the platform already takes for POST /api/auth/logout-all.
//
// Uses authz.AdminRepo.SetUserStatus directly rather than authz.AdminService
// —AdminService.SetUserStatus refuses to act on the caller's own account (an
// admin locking themselves out is never intended), but self-service deletion
// is exactly that case, legitimately.
func (s *Service) DeleteAccount(ctx context.Context, userID, password string) error {
	hash, err := s.repo.PasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	if hash != nil && *hash != "" {
		if err := bcrypt.CompareHashAndPassword([]byte(*hash), []byte(password)); err != nil {
			return ErrWrongPassword
		}
	}

	if err := s.repo.AnonymizeAndDeletePII(ctx, userID); err != nil {
		return err
	}

	if _, err := s.adminRepo.SetUserStatus(ctx, userID, "deactivated", deletionReason); err != nil {
		return fmt.Errorf("privacy: deactivate after anonymize: %w", err)
	}
	return nil
}

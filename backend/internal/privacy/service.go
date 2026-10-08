package privacy

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/authz"
)

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
// session. The handler has already re-verified the caller (auth.StepUp).
//
// Uses authz.AdminRepo.SetUserStatus directly rather than authz.AdminService
// —AdminService.SetUserStatus refuses to act on the caller's own account (an
// admin locking themselves out is never intended), but self-service deletion
// is exactly that case, legitimately.
func (s *Service) DeleteAccount(ctx context.Context, userID string) error {
	if err := s.repo.AnonymizeAndDeletePII(ctx, userID); err != nil {
		return err
	}

	if _, err := s.adminRepo.SetUserStatusUnscoped(ctx, userID, "deactivated", deletionReason); err != nil {
		return fmt.Errorf("privacy: deactivate after anonymize: %w", err)
	}
	return nil
}

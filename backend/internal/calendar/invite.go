package calendar

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/auth"
)

// inviteTokenTTL mirrors orgs.InviteService's 7-day org-invite window
// (backend/internal/orgs/invite.go) — no reason for a calendar event invite
// to expire on a different schedule.
const inviteTokenTTL = 7 * 24 * time.Hour

// generateRawToken and hashToken duplicate orgs.generateRawToken /
// hashInviteToken (backend/internal/orgs/invite.go) at the statement level:
// 32 random bytes, hex-encoded, sha256'd. Six lines of stdlib glue isn't
// worth exporting from another package and taking a cross-package dependency
// for — every domain package in this codebase that hashes a token
// (orgs, here) keeps its own copy rather than sharing a "tokens" package.
func generateRawToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("rand read: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

func hashToken(payload string) string {
	sum := sha256.Sum256([]byte(payload))
	return hex.EncodeToString(sum[:])
}

// newFeedToken mints a fresh personal-feed token payload ("userID:orgID:rawHex")
// and its hash. Embedding userID/orgID in the hashed payload (rather than
// looking them up purely by hash) costs nothing and matches the
// invite_id:rawHex shape orgs invites use.
func newFeedToken(userID, orgID string) (rawToken, hash string, err error) {
	raw, err := generateRawToken()
	if err != nil {
		return "", "", err
	}
	payload := userID + ":" + orgID + ":" + raw
	return payload, hashToken(payload), nil
}

// InviteExternal issues a bare-email invite to eventID. Only an existing
// owner/editor attendee or a calendar.events.manage holder may invite others
// (same gate as any other mutation on the event — an invite changes who can
// see/edit it, so it IS a mutation). Returns the created invite row and the
// one-time deliverable token (id:rawHex) — the caller is responsible for
// sending it (email, UI copy-link, etc.); only its hash is ever stored.
func (s *Service) InviteExternal(ctx context.Context, orgID, eventID, callerID, email, role string) (EventInvite, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return EventInvite{}, "", fmt.Errorf("%w: email is required", ErrInvalid)
	}
	if !IsValidInviteRole(role) {
		return EventInvite{}, "", fmt.Errorf("%w: role must be editor or viewer", ErrInvalid)
	}

	// Confirms eventID actually belongs to orgID before anything else — the
	// same order UpdateEvent/DeleteEvent use (org-scoped existence check
	// before the mutate-permission check).
	if _, err := s.repo.GetByID(ctx, orgID, eventID); err != nil {
		return EventInvite{}, "", err
	}

	allowed, err := s.canMutate(ctx, orgID, eventID, callerID)
	if err != nil {
		return EventInvite{}, "", err
	}
	if !allowed {
		return EventInvite{}, "", ErrForbidden
	}

	// Inserted with a placeholder hash first (mirrors orgs.InviteService.Create)
	// so the invite's own generated ID can be folded into the real token
	// payload before it's hashed.
	created, err := s.repo.CreateInvite(ctx, EventInvite{
		EventID:   eventID,
		Email:     email,
		Role:      role,
		TokenHash: "pending",
		ExpiresAt: time.Now().Add(inviteTokenTTL),
	})
	if err != nil {
		return EventInvite{}, "", err
	}

	rawHex, err := generateRawToken()
	if err != nil {
		return EventInvite{}, "", fmt.Errorf("calendar: generate invite token: %w", err)
	}
	deliverableToken := created.ID + ":" + rawHex
	tokenHash := hashToken(deliverableToken)

	created, err = s.repo.SetInviteTokenHash(ctx, created.ID, tokenHash)
	if err != nil {
		return EventInvite{}, "", err
	}

	return created, deliverableToken, nil
}

// AcceptInvite validates rawToken ("inviteID:rawHex"), provisions a minimal
// passwordless account for the invited email if none exists yet (reusing
// auth.FindOrCreateUserByEmail — see that function's doc comment for why this
// is not a second ad-hoc user-creation path), adds that user as an attendee
// of the invite's event with the invite's role, and marks the invite
// accepted. All of the attendee insert + accepted-at update happens in one
// transaction.
func (s *Service) AcceptInvite(ctx context.Context, rawToken string) (Event, error) {
	parts := strings.SplitN(rawToken, ":", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return Event{}, fmt.Errorf("%w: invalid invite token", ErrInvalid)
	}
	inviteID := parts[0]
	expectedHash := hashToken(inviteID + ":" + parts[1])

	inv, err := s.repo.GetInviteByTokenHash(ctx, expectedHash)
	if err != nil {
		return Event{}, err
	}
	if inv.ID != inviteID {
		return Event{}, fmt.Errorf("%w: invalid invite token", ErrInvalid)
	}
	if inv.AcceptedAt != nil {
		return Event{}, fmt.Errorf("%w: invite already accepted", ErrInvalid)
	}
	if time.Now().After(inv.ExpiresAt) {
		return Event{}, fmt.Errorf("%w: invite expired", ErrInvalid)
	}

	event, err := s.repo.GetEventUnscoped(ctx, inv.EventID)
	if err != nil {
		return Event{}, err
	}

	userID, err := auth.FindOrCreateUserByEmail(ctx, s.repo.pool, event.OrgID, inv.Email, nameFromEmail(inv.Email))
	if err != nil {
		return Event{}, fmt.Errorf("calendar: accept invite: provision user: %w", err)
	}

	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		if txErr := s.repo.AddAttendeeTx(ctx, tx, event.ID, userID, inv.Role); txErr != nil {
			return txErr
		}
		return s.repo.AcceptInviteTx(ctx, tx, inv.ID)
	})
	if err != nil {
		return Event{}, err
	}
	return event, nil
}

// nameFromEmail derives a display name from a bare-email invite (no real
// name is known until the invited user sets one) — the local-part of the
// address, e.g. "jane.doe" from "jane.doe@example.com".
func nameFromEmail(email string) string {
	if at := strings.IndexByte(email, '@'); at > 0 {
		return email[:at]
	}
	return email
}

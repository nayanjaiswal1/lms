package privacy

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// ErrAIConsentRequired is returned by AI-backed features that send a user's
// own content to a third-party model provider when the user has not opted in.
var ErrAIConsentRequired = errors.New("privacy: AI processing consent required")

// ErrInvalidNominee signals a nominee payload that failed validation.
var ErrInvalidNominee = errors.New("privacy: invalid nominee")

const maxNomineeFieldLen = 200

// Nominee is the person a user designates to exercise their data rights
// (DPDP s.14).
type Nominee struct {
	Name         string `json:"name"`
	Relationship string `json:"relationship"`
	Contact      string `json:"contact"`
}

// Settings is the caller's privacy configuration.
type Settings struct {
	AIConsent   bool       `json:"ai_consent"`
	AIConsentAt *time.Time `json:"ai_consent_at"`
	Nominee     *Nominee   `json:"nominee"`
}

// rowQuerier is satisfied by *pgxpool.Pool and pgx.Tx.
type rowQuerier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// HasAIConsent reports whether userID has opted in to AI processing of their
// content. Shared by every AI path that sends user text to a provider.
func HasAIConsent(ctx context.Context, q rowQuerier, userID string) (bool, error) {
	var ok bool
	if err := q.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM user_privacy_settings WHERE user_id = $1 AND ai_consent_at IS NOT NULL)`,
		userID,
	).Scan(&ok); err != nil {
		return false, fmt.Errorf("privacy: check ai consent: %w", err)
	}
	return ok, nil
}

// RequireAIConsent returns ErrAIConsentRequired unless userID has opted in.
func RequireAIConsent(ctx context.Context, q rowQuerier, userID string) error {
	ok, err := HasAIConsent(ctx, q, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrAIConsentRequired
	}
	return nil
}

// GetSettings returns userID's privacy settings; a user with no row has
// everything off/unset.
func (r *Repo) GetSettings(ctx context.Context, userID string) (Settings, error) {
	var s Settings
	var name, rel, contact *string
	err := r.pool.QueryRow(ctx,
		`SELECT ai_consent_at, nominee_name, nominee_relationship, nominee_contact
		 FROM user_privacy_settings WHERE user_id = $1`, userID,
	).Scan(&s.AIConsentAt, &name, &rel, &contact)
	if errors.Is(err, pgx.ErrNoRows) {
		return s, nil
	}
	if err != nil {
		return s, fmt.Errorf("privacy: get settings: %w", err)
	}
	s.AIConsent = s.AIConsentAt != nil
	if name != nil && rel != nil && contact != nil {
		s.Nominee = &Nominee{Name: *name, Relationship: *rel, Contact: *contact}
	}
	return s, nil
}

// SetAIConsent records or withdraws userID's AI processing consent.
func (r *Repo) SetAIConsent(ctx context.Context, userID string, consent bool) error {
	if _, err := r.pool.Exec(ctx,
		`INSERT INTO user_privacy_settings (user_id, ai_consent_at)
		 VALUES ($1, CASE WHEN $2 THEN now() END)
		 ON CONFLICT (user_id) DO UPDATE
		 SET ai_consent_at = CASE WHEN $2 THEN COALESCE(user_privacy_settings.ai_consent_at, now()) END,
		     updated_at = now()`,
		userID, consent,
	); err != nil {
		return fmt.Errorf("privacy: set ai consent: %w", err)
	}
	return nil
}

// SetNominee stores userID's nominee; nil clears it.
func (r *Repo) SetNominee(ctx context.Context, userID string, n *Nominee) error {
	var name, rel, contact *string
	if n != nil {
		name, rel, contact = &n.Name, &n.Relationship, &n.Contact
	}
	if _, err := r.pool.Exec(ctx,
		`INSERT INTO user_privacy_settings (user_id, nominee_name, nominee_relationship, nominee_contact)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (user_id) DO UPDATE
		 SET nominee_name = $2, nominee_relationship = $3, nominee_contact = $4, updated_at = now()`,
		userID, name, rel, contact,
	); err != nil {
		return fmt.Errorf("privacy: set nominee: %w", err)
	}
	return nil
}

// normalizeNominee trims and validates a nominee payload. A nil or fully
// blank payload means "clear the nominee".
func normalizeNominee(n *Nominee) (*Nominee, error) {
	if n == nil {
		return nil, nil
	}
	out := Nominee{
		Name:         strings.TrimSpace(n.Name),
		Relationship: strings.TrimSpace(n.Relationship),
		Contact:      strings.TrimSpace(n.Contact),
	}
	if out == (Nominee{}) {
		return nil, nil
	}
	for _, v := range []string{out.Name, out.Relationship, out.Contact} {
		if v == "" || len(v) > maxNomineeFieldLen {
			return nil, fmt.Errorf("%w: name, relationship and contact are all required (max %d characters each)", ErrInvalidNominee, maxNomineeFieldLen)
		}
	}
	return &out, nil
}

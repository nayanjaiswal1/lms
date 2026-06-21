package assessment

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

func (r *Repo) CreateBatch(ctx context.Context, b Batch) (Batch, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO batches (org_id, name, slug, description, mentor_id, created_by)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING id, status, created_at`,
		b.OrgID, b.Name, b.Slug, b.Description, b.MentorID, b.CreatedBy,
	).Scan(&b.ID, &b.Status, &b.CreatedAt)
	if err != nil {
		return Batch{}, fmt.Errorf("assessment: create batch: %w", err)
	}
	return b, nil
}

func (r *Repo) ListBatches(ctx context.Context, orgID string) ([]Batch, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT b.id, b.org_id, b.name, b.slug, b.description, b.mentor_id, b.status,
		        b.created_by, b.created_at,
		        (SELECT count(*) FROM batch_members m WHERE m.batch_id = b.id) AS member_count
		 FROM batches b
		 WHERE b.org_id = $1 AND b.status = 'active'
		 ORDER BY b.created_at DESC`, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list batches: %w", err)
	}
	defer rows.Close()

	out := []Batch{}
	for rows.Next() {
		var b Batch
		if err := rows.Scan(&b.ID, &b.OrgID, &b.Name, &b.Slug, &b.Description, &b.MentorID,
			&b.Status, &b.CreatedBy, &b.CreatedAt, &b.MemberCount); err != nil {
			return nil, fmt.Errorf("assessment: scan batch: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r *Repo) GetBatch(ctx context.Context, orgID, id string) (Batch, error) {
	var b Batch
	err := r.pool.QueryRow(ctx,
		`SELECT b.id, b.org_id, b.name, b.slug, b.description, b.mentor_id, b.status,
		        b.created_by, b.created_at,
		        (SELECT count(*) FROM batch_members m WHERE m.batch_id = b.id)
		 FROM batches b WHERE b.id = $1 AND b.org_id = $2`, id, orgID,
	).Scan(&b.ID, &b.OrgID, &b.Name, &b.Slug, &b.Description, &b.MentorID,
		&b.Status, &b.CreatedBy, &b.CreatedAt, &b.MemberCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Batch{}, ErrNotFound
		}
		return Batch{}, fmt.Errorf("assessment: get batch: %w", err)
	}
	return b, nil
}

// AddBatchMembers adds users to a batch in a single query, ignoring duplicates
// and silently skipping any user who is not an org member. It validates the
// batch belongs to the org before inserting.
func (r *Repo) AddBatchMembers(ctx context.Context, orgID, batchID string, userIDs []string) error {
	if len(userIDs) == 0 {
		return nil
	}
	return r.tx(ctx, func(tx pgx.Tx) error {
		var exists bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM batches WHERE id = $1 AND org_id = $2)`,
			batchID, orgID).Scan(&exists); err != nil {
			return fmt.Errorf("assessment: verify batch: %w", err)
		}
		if !exists {
			return ErrNotFound
		}

		// Single INSERT: filter to org members in one subquery, skip duplicates.
		// $1 = batchID, $2 = orgID, $3 = userIDs array.
		if _, err := tx.Exec(ctx,
			`INSERT INTO batch_members (batch_id, user_id)
			 SELECT $1, om.user_id
			 FROM org_members om
			 WHERE om.org_id = $2
			   AND om.user_id = ANY($3::uuid[])
			 ON CONFLICT (batch_id, user_id) DO NOTHING`,
			batchID, orgID, userIDs); err != nil {
			return fmt.Errorf("assessment: add batch members: %w", err)
		}
		return nil
	})
}

func (r *Repo) RemoveBatchMember(ctx context.Context, orgID, batchID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM batch_members
		 WHERE batch_id = $1 AND user_id = $2
		   AND EXISTS (SELECT 1 FROM batches WHERE id = $1 AND org_id = $3)`,
		batchID, userID, orgID)
	if err != nil {
		return fmt.Errorf("assessment: remove batch member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// BatchMember is a lightweight view of a batch participant.
type BatchMember struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
	Email  string `json:"email"`
}

func (r *Repo) ListBatchMembers(ctx context.Context, orgID, batchID string) ([]BatchMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email
		 FROM batch_members m
		 JOIN users u ON u.id = m.user_id
		 JOIN batches b ON b.id = m.batch_id
		 WHERE m.batch_id = $1 AND b.org_id = $2
		 ORDER BY u.name`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list batch members: %w", err)
	}
	defer rows.Close()

	out := []BatchMember{}
	for rows.Next() {
		var m BatchMember
		if err := rows.Scan(&m.UserID, &m.Name, &m.Email); err != nil {
			return nil, fmt.Errorf("assessment: scan batch member: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ─── Batch enhancements ───────────────────────────────────────────────────────

var (
	ErrInvitationExpired         = errors.New("assessment: invitation expired")
	ErrInvitationAlreadyAccepted = errors.New("assessment: invitation already accepted")
	ErrInvitationAlreadyDeclined = errors.New("assessment: invitation already declined")
	ErrUserNotFound              = errors.New("assessment: user not found")
	ErrEmailMismatch             = errors.New("assessment: invitation email does not match your account")
)

type BatchMentor struct {
	ID      string    `json:"id"`
	UserID  string    `json:"user_id"`
	Name    string    `json:"name"`
	Email   string    `json:"email"`
	AddedAt time.Time `json:"added_at"`
}

type BatchCourse struct {
	ID         string    `json:"id"`
	CourseID   string    `json:"course_id"`
	Title      string    `json:"title"`
	Slug       string    `json:"slug"`
	AssignedAt time.Time `json:"assigned_at"`
}

type BatchInvitation struct {
	ID         string     `json:"id"`
	Email      string     `json:"email"`
	InvitedAt  time.Time  `json:"invited_at"`
	ExpiresAt  time.Time  `json:"expires_at"`
	AcceptedAt *time.Time `json:"accepted_at"`
	DeclinedAt *time.Time `json:"declined_at"`
	ResentAt   *time.Time `json:"resent_at"`
}

type MemberProgress struct {
	UserID           string `json:"user_id"`
	Name             string `json:"name"`
	Email            string `json:"email"`
	CoursesEnrolled  int    `json:"courses_enrolled"`
	CoursesCompleted int    `json:"courses_completed"`
	TestsPassed      int    `json:"tests_passed"`
}

type InvitationToken struct {
	Email string `json:"email"`
	Token string `json:"token"`
}

type InvitationPreview struct {
	Email     string    `json:"email"`
	BatchName string    `json:"batch_name"`
	OrgName   string    `json:"org_name"`
	ExpiresAt time.Time `json:"expires_at"`
	Status    string    `json:"status"`
}

func newInvitationToken() (rawToken, tokenHash string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", "", fmt.Errorf("assessment: generate token: %w", err)
	}
	rawToken = hex.EncodeToString(b)
	sum := sha256.Sum256([]byte(rawToken))
	tokenHash = hex.EncodeToString(sum[:])
	return rawToken, tokenHash, nil
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func (r *Repo) AddBatchMentor(ctx context.Context, orgID, batchID, userID, addedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO batch_mentors (batch_id, user_id, added_by)
		 SELECT $1, $2, $3
		 WHERE EXISTS (SELECT 1 FROM batches WHERE id = $1 AND org_id = $4)
		 ON CONFLICT (batch_id, user_id) DO NOTHING`,
		batchID, userID, addedBy, orgID)
	if err != nil {
		return fmt.Errorf("assessment: add batch mentor: %w", err)
	}
	return nil
}

func (r *Repo) RemoveBatchMentor(ctx context.Context, orgID, batchID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM batch_mentors
		 WHERE batch_id = $1 AND user_id = $2
		   AND EXISTS (SELECT 1 FROM batches WHERE id = $1 AND org_id = $3)`,
		batchID, userID, orgID)
	if err != nil {
		return fmt.Errorf("assessment: remove batch mentor: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) ListBatchMentors(ctx context.Context, orgID, batchID string) ([]BatchMentor, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT bm.id, bm.user_id, u.name, u.email, bm.added_at
		 FROM batch_mentors bm
		 JOIN users u ON u.id = bm.user_id
		 WHERE bm.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 ORDER BY bm.added_at`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list batch mentors: %w", err)
	}
	defer rows.Close()
	out := []BatchMentor{}
	for rows.Next() {
		var m BatchMentor
		if err := rows.Scan(&m.ID, &m.UserID, &m.Name, &m.Email, &m.AddedAt); err != nil {
			return nil, fmt.Errorf("assessment: scan batch mentor: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *Repo) AssignBatchCourse(ctx context.Context, orgID, batchID, courseID, assignedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO batch_courses (batch_id, course_id, assigned_by)
		 SELECT $1, $2, $3
		 WHERE EXISTS (SELECT 1 FROM batches WHERE id = $1 AND org_id = $4)
		   AND EXISTS (SELECT 1 FROM courses WHERE id = $2 AND org_id = $4)
		 ON CONFLICT (batch_id, course_id) DO NOTHING`,
		batchID, courseID, assignedBy, orgID)
	if err != nil {
		return fmt.Errorf("assessment: assign batch course: %w", err)
	}
	return nil
}

func (r *Repo) UnassignBatchCourse(ctx context.Context, orgID, batchID, courseID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM batch_courses
		 WHERE batch_id = $1 AND course_id = $2
		   AND EXISTS (SELECT 1 FROM batches WHERE id = $1 AND org_id = $3)`,
		batchID, courseID, orgID)
	if err != nil {
		return fmt.Errorf("assessment: unassign batch course: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) ListBatchCourses(ctx context.Context, orgID, batchID string) ([]BatchCourse, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT bc.id, bc.course_id, c.title, c.slug, bc.assigned_at
		 FROM batch_courses bc
		 JOIN courses c ON c.id = bc.course_id
		 WHERE bc.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 ORDER BY bc.assigned_at`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list batch courses: %w", err)
	}
	defer rows.Close()
	out := []BatchCourse{}
	for rows.Next() {
		var c BatchCourse
		if err := rows.Scan(&c.ID, &c.CourseID, &c.Title, &c.Slug, &c.AssignedAt); err != nil {
			return nil, fmt.Errorf("assessment: scan batch course: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const invitationTTL = 7 * 24 * time.Hour

func (r *Repo) CreateBatchInvitations(ctx context.Context, orgID, batchID, invitedBy string, emails []string) ([]InvitationToken, error) {
	expiresAt := time.Now().Add(invitationTTL)
	out := make([]InvitationToken, 0, len(emails))

	// Pre-generate all tokens before opening the transaction so crypto work
	// doesn't hold a DB connection longer than necessary.
	type pendingInvitation struct {
		email string
		raw   string
		hash  string
	}
	pending := make([]pendingInvitation, 0, len(emails))
	for _, email := range emails {
		raw, hash, err := newInvitationToken()
		if err != nil {
			return nil, err
		}
		pending = append(pending, pendingInvitation{email: email, raw: raw, hash: hash})
		out = append(out, InvitationToken{Email: email, Token: raw})
	}

	// Collect parallel slices for unnest — one DB round-trip for all rows.
	emails2 := make([]string, len(pending))
	hashes := make([]string, len(pending))
	for i, p := range pending {
		emails2[i] = p.email
		hashes[i] = p.hash
	}

	err := r.tx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx,
			`INSERT INTO batch_invitations (batch_id, org_id, email, invited_by, token_hash, expires_at)
			 SELECT $1, $2, u.email, $3, u.hash, $4
			 FROM unnest($5::text[], $6::text[]) AS u(email, hash)
			 ON CONFLICT (batch_id, email) DO UPDATE
			   SET token_hash  = EXCLUDED.token_hash,
			       expires_at  = EXCLUDED.expires_at,
			       accepted_at = NULL,
			       declined_at = NULL,
			       resent_at   = NULL`,
			batchID, orgID, invitedBy, expiresAt, emails2, hashes)
		if err != nil {
			return fmt.Errorf("assessment: upsert invitations: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *Repo) ListBatchInvitations(ctx context.Context, orgID, batchID string) ([]BatchInvitation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT bi.id, bi.email, bi.invited_at, bi.expires_at, bi.accepted_at, bi.declined_at, bi.resent_at
		 FROM batch_invitations bi
		 WHERE bi.batch_id = $1 AND bi.org_id = $2
		 ORDER BY bi.invited_at DESC`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list invitations: %w", err)
	}
	defer rows.Close()
	out := []BatchInvitation{}
	for rows.Next() {
		var inv BatchInvitation
		if err := rows.Scan(&inv.ID, &inv.Email, &inv.InvitedAt, &inv.ExpiresAt,
			&inv.AcceptedAt, &inv.DeclinedAt, &inv.ResentAt); err != nil {
			return nil, fmt.Errorf("assessment: scan invitation: %w", err)
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

func (r *Repo) RevokeInvitation(ctx context.Context, orgID, invID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM batch_invitations
		 WHERE id = $1 AND org_id = $2 AND accepted_at IS NULL`,
		invID, orgID)
	if err != nil {
		return fmt.Errorf("assessment: revoke invitation: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) ResendInvitation(ctx context.Context, orgID, invID string) (InvitationToken, error) {
	raw, hash, err := newInvitationToken()
	if err != nil {
		return InvitationToken{}, err
	}
	expiresAt := time.Now().Add(invitationTTL)
	var email string
	err = r.pool.QueryRow(ctx,
		`UPDATE batch_invitations
		 SET token_hash = $1, expires_at = $2, resent_at = now(), accepted_at = NULL, declined_at = NULL
		 WHERE id = $3 AND org_id = $4
		 RETURNING email`,
		hash, expiresAt, invID, orgID).Scan(&email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return InvitationToken{}, ErrNotFound
		}
		return InvitationToken{}, fmt.Errorf("assessment: resend invitation: %w", err)
	}
	return InvitationToken{Email: email, Token: raw}, nil
}

func (r *Repo) GetInvitationPreview(ctx context.Context, rawToken string) (InvitationPreview, error) {
	tokenHash := hashToken(rawToken)
	var p InvitationPreview
	var acceptedAt, declinedAt *time.Time
	err := r.pool.QueryRow(ctx,
		`SELECT bi.email, ba.name, o.name, bi.expires_at, bi.accepted_at, bi.declined_at
		 FROM batch_invitations bi
		 JOIN batches ba ON ba.id = bi.batch_id
		 JOIN organizations o ON o.id = bi.org_id
		 WHERE bi.token_hash = $1`, tokenHash,
	).Scan(&p.Email, &p.BatchName, &p.OrgName, &p.ExpiresAt, &acceptedAt, &declinedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return InvitationPreview{}, ErrNotFound
		}
		return InvitationPreview{}, fmt.Errorf("assessment: preview invitation: %w", err)
	}
	switch {
	case acceptedAt != nil:
		p.Status = "accepted"
	case declinedAt != nil:
		p.Status = "declined"
	case time.Now().After(p.ExpiresAt):
		p.Status = "expired"
	default:
		p.Status = "pending"
	}
	return p, nil
}

func (r *Repo) AcceptInvitation(ctx context.Context, rawToken, userID, userEmail string) (batchID string, orgID string, err error) {
	tokenHash := hashToken(rawToken)
	return batchID, orgID, r.tx(ctx, func(tx pgx.Tx) error {
		var invID, invEmail string
		var expiresAt time.Time
		var acceptedAt, declinedAt *time.Time
		if err := tx.QueryRow(ctx,
			`SELECT id, batch_id, org_id, email, expires_at, accepted_at, declined_at
			 FROM batch_invitations WHERE token_hash = $1`, tokenHash,
		).Scan(&invID, &batchID, &orgID, &invEmail, &expiresAt, &acceptedAt, &declinedAt); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("assessment: lookup invitation: %w", err)
		}
		if invEmail != userEmail {
			return ErrEmailMismatch
		}
		if acceptedAt != nil {
			return ErrInvitationAlreadyAccepted
		}
		if declinedAt != nil {
			return ErrInvitationAlreadyDeclined
		}
		if time.Now().After(expiresAt) {
			return ErrInvitationExpired
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, 'student')
			 ON CONFLICT (org_id, user_id) DO NOTHING`, orgID, userID); err != nil {
			return fmt.Errorf("assessment: add org member: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO batch_members (batch_id, user_id) VALUES ($1, $2)
			 ON CONFLICT (batch_id, user_id) DO NOTHING`, batchID, userID); err != nil {
			return fmt.Errorf("assessment: add batch member: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`UPDATE batch_invitations SET accepted_at = now() WHERE id = $1`, invID); err != nil {
			return fmt.Errorf("assessment: mark invitation accepted: %w", err)
		}
		return nil
	})
}

func (r *Repo) DeclineInvitation(ctx context.Context, rawToken string) error {
	tokenHash := hashToken(rawToken)
	var expiresAt time.Time
	var acceptedAt, declinedAt *time.Time
	var invID string
	if err := r.pool.QueryRow(ctx,
		`SELECT id, expires_at, accepted_at, declined_at FROM batch_invitations WHERE token_hash = $1`,
		tokenHash).Scan(&invID, &expiresAt, &acceptedAt, &declinedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("assessment: lookup invitation: %w", err)
	}
	if acceptedAt != nil {
		return ErrInvitationAlreadyAccepted
	}
	if declinedAt != nil {
		return ErrInvitationAlreadyDeclined
	}
	if _, err := r.pool.Exec(ctx,
		`UPDATE batch_invitations SET declined_at = now() WHERE id = $1`, invID); err != nil {
		return fmt.Errorf("assessment: decline invitation: %w", err)
	}
	return nil
}

func (r *Repo) GetBatchProgress(ctx context.Context, orgID, batchID string) ([]MemberProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email,
		        COUNT(DISTINCT e.course_id) AS courses_enrolled,
		        COUNT(DISTINCT CASE WHEN e.completed_at IS NOT NULL THEN e.course_id END) AS courses_completed,
		        COUNT(DISTINCT aa.id) FILTER (WHERE aa.passed = true) AS tests_passed
		 FROM batch_members bm
		 JOIN users u ON u.id = bm.user_id
		 LEFT JOIN enrollments e ON e.user_id = u.id AND e.batch_id = $1
		 LEFT JOIN assessment_attempts aa ON aa.user_id = u.id AND aa.status = 'evaluated'
		 WHERE bm.batch_id = $1
		   AND EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)
		 GROUP BY u.id, u.name, u.email
		 ORDER BY u.name`, batchID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: get batch progress: %w", err)
	}
	defer rows.Close()
	out := []MemberProgress{}
	for rows.Next() {
		var m MemberProgress
		if err := rows.Scan(&m.UserID, &m.Name, &m.Email,
			&m.CoursesEnrolled, &m.CoursesCompleted, &m.TestsPassed); err != nil {
			return nil, fmt.Errorf("assessment: scan member progress: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

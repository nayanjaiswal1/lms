package sessions

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrNotFound is returned when a row does not exist, or exists in another
	// org (the two are indistinguishable to a caller by design).
	ErrNotFound = errors.New("sessions: not found")

	// ErrForbidden is returned when the caller may not act on a session that
	// isn't theirs.
	ErrForbidden = errors.New("sessions: forbidden")

	// ErrInvalid signals a request that failed validation before reaching the
	// database. The handler maps it to 422 with the message attached.
	ErrInvalid = errors.New("sessions: invalid input")

	// ErrSlotTaken is returned when the mentor_sessions_no_overlap /
	// _student_no_overlap exclusion constraint rejects a booking — someone
	// else took the slot between the availability read and this write. The
	// handler maps it to 409 so the UI can refresh the grid.
	ErrSlotTaken = errors.New("sessions: slot no longer available")

	// ErrInsufficientCredits is returned when the org requires credits and
	// the student's ledger balance is zero.
	ErrInsufficientCredits = errors.New("sessions: insufficient session credits")

	// ErrBookingDisabled is returned when the org has session booking turned
	// off entirely.
	ErrBookingDisabled = errors.New("sessions: booking is disabled for this organization")

	// ErrTooManyUpcoming is returned when the student already holds the org's
	// maximum number of scheduled sessions.
	ErrTooManyUpcoming = errors.New("sessions: too many upcoming sessions")
)

// exclusionViolation reports whether err is a Postgres exclusion-constraint
// violation (SQLSTATE 23P01) — the double-booking guard firing.
func exclusionViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23P01"
}

// uniqueViolation reports whether err is a Postgres unique violation (23505).
func uniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, committing on success and rolling back on
// any error. Mirrors mentoring.Repo's tx helper.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("sessions: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := fn(tx); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("sessions: commit tx: %w", err)
	}
	return nil
}

// ─── config ────────────────────────────────────────────────────────────────

// GetConfig returns the org's booking policy by reading org_settings.session_booking jsonb,
// falling back to DefaultConfig when no row exists or the jsonb is empty.
func (r *Repo) GetConfig(ctx context.Context, orgID string) (Config, error) {
	cfg := DefaultConfig(orgID)

	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(session_booking, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return cfg, nil
	}
	if err != nil {
		return Config{}, fmt.Errorf("sessions: get config: %w", err)
	}

	// Unmarshal the jsonb into the config struct. If jsonb is empty ({}),
	// json.Unmarshal leaves all fields at their zero values, so we fall back
	// to DefaultConfig's filled-in values via COALESCE-like logic below.
	type sessionBookingJSON struct {
		Enabled               *bool   `json:"enabled"`
		RequireCredits        *bool   `json:"require_credits"`
		CancelCutoffHours     *int    `json:"cancel_cutoff_hours"`
		MinNoticeHours        *int    `json:"min_notice_hours"`
		BookingHorizonDays    *int    `json:"booking_horizon_days"`
		MaxUpcomingPerStudent *int    `json:"max_upcoming_per_student"`
		DefaultDuration       *int    `json:"default_duration_minutes"`
	}

	var parsed sessionBookingJSON
	if len(raw) > 2 { // Skip empty {}
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return Config{}, fmt.Errorf("sessions: unmarshal session booking config: %w", err)
		}
	}

	// Apply parsed values, falling back to defaults if nil
	if parsed.Enabled != nil {
		cfg.Enabled = *parsed.Enabled
	}
	if parsed.RequireCredits != nil {
		cfg.RequireCredits = *parsed.RequireCredits
	}
	if parsed.CancelCutoffHours != nil {
		cfg.CancelCutoffHours = *parsed.CancelCutoffHours
	}
	if parsed.MinNoticeHours != nil {
		cfg.MinNoticeHours = *parsed.MinNoticeHours
	}
	if parsed.BookingHorizonDays != nil {
		cfg.BookingHorizonDays = *parsed.BookingHorizonDays
	}
	if parsed.MaxUpcomingPerStudent != nil {
		cfg.MaxUpcomingPerStudent = *parsed.MaxUpcomingPerStudent
	}
	if parsed.DefaultDuration != nil {
		cfg.DefaultDuration = *parsed.DefaultDuration
	}

	return cfg, nil
}

// UpsertConfig writes the org's booking policy to org_settings.session_booking jsonb.
func (r *Repo) UpsertConfig(ctx context.Context, c Config) (Config, error) {
	cfgJSON, err := json.Marshal(map[string]interface{}{
		"enabled":                    c.Enabled,
		"require_credits":            c.RequireCredits,
		"cancel_cutoff_hours":        c.CancelCutoffHours,
		"min_notice_hours":           c.MinNoticeHours,
		"booking_horizon_days":       c.BookingHorizonDays,
		"max_upcoming_per_student":   c.MaxUpcomingPerStudent,
		"default_duration_minutes":   c.DefaultDuration,
	})
	if err != nil {
		return Config{}, fmt.Errorf("sessions: marshal config: %w", err)
	}

	err = r.pool.QueryRow(ctx,
		`INSERT INTO org_settings (org_id, session_booking, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET session_booking = EXCLUDED.session_booking, updated_at = now()
		 RETURNING updated_at`,
		c.OrgID, string(cfgJSON),
	).Scan(&c.UpdatedAt)
	if err != nil {
		return Config{}, fmt.Errorf("sessions: upsert config: %w", err)
	}
	return c, nil
}

// ─── availability ──────────────────────────────────────────────────────────

// ListRules returns a mentor's weekly availability rules, active first.
func (r *Repo) ListRules(ctx context.Context, orgID, mentorID string) ([]AvailabilityRule, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, mentor_id, weekday, start_minute, end_minute,
		        slot_minutes, timezone, active, created_at, updated_at
		   FROM mentor_availability_rules
		  WHERE org_id = $1 AND mentor_id = $2
		  ORDER BY weekday, start_minute`,
		orgID, mentorID,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list rules: %w", err)
	}
	defer rows.Close()

	out := []AvailabilityRule{}
	for rows.Next() {
		var a AvailabilityRule
		if err := rows.Scan(&a.ID, &a.OrgID, &a.MentorID, &a.Weekday, &a.StartMinute, &a.EndMinute,
			&a.SlotMinutes, &a.Timezone, &a.Active, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, fmt.Errorf("sessions: scan rule: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ReplaceRules swaps a mentor's entire weekly pattern in one transaction.
// A whole-pattern replace rather than per-row CRUD: the editor UI is a weekly
// grid the mentor saves as a unit, and diffing it client-side into
// create/update/delete calls is three ways to leave it half-applied.
func (r *Repo) ReplaceRules(ctx context.Context, orgID, mentorID string, rules []AvailabilityRule) ([]AvailabilityRule, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx,
			`DELETE FROM mentor_availability_rules WHERE org_id = $1 AND mentor_id = $2`,
			orgID, mentorID,
		); err != nil {
			return fmt.Errorf("sessions: clear rules: %w", err)
		}
		for _, rule := range rules {
			if _, err := tx.Exec(ctx,
				`INSERT INTO mentor_availability_rules
				   (org_id, mentor_id, weekday, start_minute, end_minute, slot_minutes, timezone, active)
				 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
				orgID, mentorID, rule.Weekday, rule.StartMinute, rule.EndMinute,
				rule.SlotMinutes, rule.Timezone, rule.Active,
			); err != nil {
				return fmt.Errorf("sessions: insert rule: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return r.ListRules(ctx, orgID, mentorID)
}

// ListExceptions returns a mentor's one-off overrides overlapping [from, to].
// The date filter is deliberately loose by a day either side: on_date is a
// local date and the caller's window is in UTC, so an exception on the
// boundary date can still overlap the window once its zone is applied.
func (r *Repo) ListExceptions(ctx context.Context, orgID, mentorID string, from, to time.Time) ([]AvailabilityException, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, mentor_id, to_char(on_date, 'YYYY-MM-DD'), start_minute, end_minute,
		        is_blocked, slot_minutes, timezone, note, created_at
		   FROM mentor_availability_exceptions
		  WHERE org_id = $1 AND mentor_id = $2
		    AND on_date BETWEEN ($3::timestamptz - interval '1 day')::date
		                    AND ($4::timestamptz + interval '1 day')::date
		  ORDER BY on_date, start_minute NULLS FIRST`,
		orgID, mentorID, from, to,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list exceptions: %w", err)
	}
	defer rows.Close()

	out := []AvailabilityException{}
	for rows.Next() {
		var e AvailabilityException
		if err := rows.Scan(&e.ID, &e.OrgID, &e.MentorID, &e.OnDate, &e.StartMinute, &e.EndMinute,
			&e.IsBlocked, &e.SlotMinutes, &e.Timezone, &e.Note, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("sessions: scan exception: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// CreateException inserts a one-off availability override.
func (r *Repo) CreateException(ctx context.Context, e AvailabilityException) (AvailabilityException, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_availability_exceptions
		   (org_id, mentor_id, on_date, start_minute, end_minute, is_blocked, slot_minutes, timezone, note)
		 VALUES ($1, $2, $3::date, $4, $5, $6, $7, $8, $9)
		 RETURNING id, created_at`,
		e.OrgID, e.MentorID, e.OnDate, e.StartMinute, e.EndMinute, e.IsBlocked, e.SlotMinutes, e.Timezone, e.Note,
	).Scan(&e.ID, &e.CreatedAt)
	if err != nil {
		return AvailabilityException{}, fmt.Errorf("sessions: create exception: %w", err)
	}
	return e, nil
}

// DeleteException removes one override, scoped to its owning mentor so a
// mentor can never delete someone else's day off.
func (r *Repo) DeleteException(ctx context.Context, orgID, mentorID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM mentor_availability_exceptions WHERE id = $1 AND org_id = $2 AND mentor_id = $3`,
		id, orgID, mentorID,
	)
	if err != nil {
		return fmt.Errorf("sessions: delete exception: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// BusyRanges returns a mentor's scheduled sessions overlapping [from, to] —
// what marks a computed slot Taken.
func (r *Repo) BusyRanges(ctx context.Context, orgID, mentorID string, from, to time.Time) ([]timeRange, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT starts_at, ends_at
		   FROM mentor_sessions
		  WHERE org_id = $1 AND mentor_id = $2 AND status = 'scheduled'
		    AND starts_at < $4 AND ends_at > $3`,
		orgID, mentorID, from, to,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: busy ranges: %w", err)
	}
	defer rows.Close()

	out := []timeRange{}
	for rows.Next() {
		var tr timeRange
		if err := rows.Scan(&tr.Start, &tr.End); err != nil {
			return nil, fmt.Errorf("sessions: scan busy range: %w", err)
		}
		out = append(out, tr)
	}
	return out, rows.Err()
}

// ─── credits ───────────────────────────────────────────────────────────────

// lockUserCredits takes a transaction-scoped advisory lock on one user's
// credit balance. The ledger has no single row to SELECT ... FOR UPDATE (a
// balance is an aggregate over many rows), so without this two concurrent
// bookings can both read balance=1 and both insert a -1, overdrawing the
// student. Held until the transaction ends; no explicit unlock needed.
func (r *Repo) lockUserCredits(ctx context.Context, tx pgx.Tx, orgID, userID string) error {
	if _, err := tx.Exec(ctx,
		`SELECT pg_advisory_xact_lock(hashtextextended($1 || ':' || $2, 0))`,
		userID, orgID,
	); err != nil {
		return fmt.Errorf("sessions: lock credits: %w", err)
	}
	return nil
}

// CreditBalance returns SUM(delta) over a user's ledger — their spendable
// session count.
func (r *Repo) CreditBalance(ctx context.Context, orgID, userID string) (int, error) {
	var balance int
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(delta), 0) FROM session_credit_ledger WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	).Scan(&balance)
	if err != nil {
		return 0, fmt.Errorf("sessions: credit balance: %w", err)
	}
	return balance, nil
}

func (r *Repo) creditBalanceTx(ctx context.Context, tx pgx.Tx, orgID, userID string) (int, error) {
	var balance int
	err := tx.QueryRow(ctx,
		`SELECT COALESCE(SUM(delta), 0) FROM session_credit_ledger WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	).Scan(&balance)
	if err != nil {
		return 0, fmt.Errorf("sessions: credit balance: %w", err)
	}
	return balance, nil
}

// insertLedgerTx appends one ledger movement. A unique violation here is the
// idempotency guard firing (see session_credit_ledger_booking_uq) — reported
// as such so callers can treat a retry as a no-op rather than an error.
func (r *Repo) insertLedgerTx(ctx context.Context, tx pgx.Tx, orgID, userID string, delta int, reason string, sessionID, purchaseID, note, createdBy *string) (bool, error) {
	_, err := tx.Exec(ctx,
		`INSERT INTO session_credit_ledger
		   (org_id, user_id, delta, reason, session_id, purchase_id, note, created_by)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		orgID, userID, delta, reason, sessionID, purchaseID, note, createdBy,
	)
	if uniqueViolation(err) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("sessions: insert ledger: %w", err)
	}
	return true, nil
}

// GrantCredits appends an admin grant (or revoke, when delta is negative).
func (r *Repo) GrantCredits(ctx context.Context, orgID, userID string, delta int, note, actorID string) (int, error) {
	reason := ReasonAdminGrant
	if delta < 0 {
		reason = ReasonAdminRevoke
	}
	var balance int
	err := r.tx(ctx, func(tx pgx.Tx) error {
		if err := r.lockUserCredits(ctx, tx, orgID, userID); err != nil {
			return err
		}
		current, err := r.creditBalanceTx(ctx, tx, orgID, userID)
		if err != nil {
			return err
		}
		// A revoke may not push a student negative — a negative balance would
		// silently swallow their next legitimate purchase.
		if current+delta < 0 {
			return fmt.Errorf("%w: cannot revoke more credits than the balance of %d", ErrInvalid, current)
		}
		var notePtr *string
		if note != "" {
			notePtr = &note
		}
		if _, err := r.insertLedgerTx(ctx, tx, orgID, userID, delta, reason, nil, nil, notePtr, &actorID); err != nil {
			return err
		}
		balance = current + delta
		return nil
	})
	return balance, err
}

// ListLedger returns a user's most recent credit movements.
func (r *Repo) ListLedger(ctx context.Context, orgID, userID string, limit int) ([]LedgerEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, delta, reason, session_id, note, created_at
		   FROM session_credit_ledger
		  WHERE org_id = $1 AND user_id = $2
		  ORDER BY created_at DESC
		  LIMIT $3`,
		orgID, userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list ledger: %w", err)
	}
	defer rows.Close()

	out := []LedgerEntry{}
	for rows.Next() {
		var e LedgerEntry
		if err := rows.Scan(&e.ID, &e.Delta, &e.Reason, &e.SessionID, &e.Note, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("sessions: scan ledger entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ─── credit packs & purchases ──────────────────────────────────────────────

// ListPacks returns an org's credit packs. activeOnly is what the student-
// facing store uses; the admin view wants archived packs too.
func (r *Repo) ListPacks(ctx context.Context, orgID string, activeOnly bool) ([]CreditPack, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, name, description, sessions, price_cents, currency, active, created_at
		   FROM session_credit_packs
		  WHERE org_id = $1 AND (NOT $2 OR active)
		  ORDER BY price_cents`,
		orgID, activeOnly,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list packs: %w", err)
	}
	defer rows.Close()

	out := []CreditPack{}
	for rows.Next() {
		var p CreditPack
		if err := rows.Scan(&p.ID, &p.OrgID, &p.Name, &p.Description, &p.Sessions,
			&p.PriceCents, &p.Currency, &p.Active, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("sessions: scan pack: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetPack returns one active-or-not pack, org-scoped.
func (r *Repo) GetPack(ctx context.Context, orgID, packID string) (CreditPack, error) {
	var p CreditPack
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, name, description, sessions, price_cents, currency, active, created_at
		   FROM session_credit_packs WHERE id = $1 AND org_id = $2`,
		packID, orgID,
	).Scan(&p.ID, &p.OrgID, &p.Name, &p.Description, &p.Sessions, &p.PriceCents, &p.Currency, &p.Active, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return CreditPack{}, ErrNotFound
	}
	if err != nil {
		return CreditPack{}, fmt.Errorf("sessions: get pack: %w", err)
	}
	return p, nil
}

// UpsertPack creates a pack, or updates it when p.ID is set.
func (r *Repo) UpsertPack(ctx context.Context, p CreditPack, actorID string) (CreditPack, error) {
	if p.ID == "" {
		err := r.pool.QueryRow(ctx,
			`INSERT INTO session_credit_packs
			   (org_id, name, description, sessions, price_cents, currency, active, created_by)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			 RETURNING id, created_at`,
			p.OrgID, p.Name, p.Description, p.Sessions, p.PriceCents, p.Currency, p.Active, actorID,
		).Scan(&p.ID, &p.CreatedAt)
		if err != nil {
			return CreditPack{}, fmt.Errorf("sessions: create pack: %w", err)
		}
		return p, nil
	}

	tag, err := r.pool.Exec(ctx,
		`UPDATE session_credit_packs
		    SET name = $3, description = $4, sessions = $5, price_cents = $6,
		        currency = $7, active = $8, updated_at = now()
		  WHERE id = $1 AND org_id = $2`,
		p.ID, p.OrgID, p.Name, p.Description, p.Sessions, p.PriceCents, p.Currency, p.Active,
	)
	if err != nil {
		return CreditPack{}, fmt.Errorf("sessions: update pack: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return CreditPack{}, ErrNotFound
	}
	return p, nil
}

// CreatePackPurchase opens a pending purchase row in the purchases table
// with product_type='session_pack'.
func (r *Repo) CreatePackPurchase(ctx context.Context, p PackPurchase) (PackPurchase, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO purchases
		   (org_id, user_id, product_type, pack_id, amount_cents, currency, provider, provider_ref, status)
		 VALUES ($1, $2, 'session_pack', $3, $4, $5, $6, $7, 'pending')
		 RETURNING id, status`,
		p.OrgID, p.UserID, p.PackID, p.AmountCents, p.Currency, p.Provider, p.ProviderRef,
	).Scan(&p.ID, &p.Status)
	if err != nil {
		return PackPurchase{}, fmt.Errorf("sessions: create pack purchase: %w", err)
	}
	return p, nil
}

// SetPurchaseProviderRef swaps the placeholder provider_ref for the gateway's
// real session/order id once CreateCheckout returns it.
func (r *Repo) SetPurchaseProviderRef(ctx context.Context, purchaseID, providerRef string) error {
	if _, err := r.pool.Exec(ctx,
		`UPDATE purchases SET provider_ref = $2 WHERE id = $1 AND product_type = 'session_pack'`,
		purchaseID, providerRef,
	); err != nil {
		return fmt.Errorf("sessions: set provider ref: %w", err)
	}
	return nil
}

// GetPurchaseByProviderRef resolves a webhook delivery back to its purchase.
func (r *Repo) GetPurchaseByProviderRef(ctx context.Context, provider, providerRef string) (PackPurchase, error) {
	var p PackPurchase
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, user_id, pack_id, amount_cents, currency, provider, provider_ref, status
		   FROM purchases WHERE provider = $1 AND provider_ref = $2 AND product_type = 'session_pack'`,
		provider, providerRef,
	).Scan(&p.ID, &p.OrgID, &p.UserID, &p.PackID, &p.AmountCents,
		&p.Currency, &p.Provider, &p.ProviderRef, &p.Status)
	if errors.Is(err, pgx.ErrNoRows) {
		return PackPurchase{}, ErrNotFound
	}
	if err != nil {
		return PackPurchase{}, fmt.Errorf("sessions: get purchase by provider ref: %w", err)
	}
	return p, nil
}

// MarkPurchaseFailed records a gateway failure.
func (r *Repo) MarkPurchaseFailed(ctx context.Context, purchaseID string) error {
	if _, err := r.pool.Exec(ctx,
		`UPDATE purchases SET status = 'failed' WHERE id = $1 AND status = 'pending' AND product_type = 'session_pack'`,
		purchaseID,
	); err != nil {
		return fmt.Errorf("sessions: mark purchase failed: %w", err)
	}
	return nil
}

// CompletePurchase marks a purchase completed and credits the ledger, in one
// transaction. The guarded UPDATE (status = 'pending' in the WHERE) is the
// idempotency backstop: a redelivered webhook finds no pending row, reports
// transitioned=false, and never credits a second time.
func (r *Repo) CompletePurchase(ctx context.Context, purchaseID, paymentRef string) (bool, error) {
	var transitioned bool
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var p PackPurchase
		err := tx.QueryRow(ctx,
			`UPDATE purchases
			    SET status = 'completed', completed_at = now(), payment_ref = NULLIF($2, '')
			  WHERE id = $1 AND status = 'pending' AND product_type = 'session_pack'
			  RETURNING id, org_id, user_id, (granted->>'sessions')::int as sessions`,
			purchaseID, paymentRef,
		).Scan(&p.ID, &p.OrgID, &p.UserID, &p.Sessions)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("sessions: complete purchase: %w", err)
		}

		if err := r.lockUserCredits(ctx, tx, p.OrgID, p.UserID); err != nil {
			return err
		}
		if _, err := r.insertLedgerTx(ctx, tx, p.OrgID, p.UserID, p.Sessions,
			ReasonPurchase, nil, &p.ID, nil, nil); err != nil {
			return err
		}
		transitioned = true
		return nil
	})
	return transitioned, err
}

package mentoring

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("mentoring: not found")

	// ErrForbidden is returned when a caller acts on a ticket/request that
	// isn't theirs (e.g. requesting a mentor change on someone else's ticket).
	ErrForbidden = errors.New("mentoring: forbidden")

	// ErrTicketAlreadyClaimed is returned by ClaimTicket/AssignTicket when the
	// target ticket no longer exists or is no longer 'open' — the handler
	// maps this to HTTP 409.
	ErrTicketAlreadyClaimed = errors.New("mentoring: ticket already claimed")

	// ErrChangeRequestPending is returned by CreateChangeRequest on a
	// UNIQUE (ticket_id) WHERE status='pending' violation — the handler maps
	// this to HTTP 409.
	ErrChangeRequestPending = &conflictErr{msg: "mentoring: a change request is already pending for this ticket"}

	// ErrAlreadyPurchased is returned by CreatePurchase on a UNIQUE
	// (user_id, course_id) violation. It implements IsConflict() so callers
	// in other packages (e.g. courses) can detect it via a locally-defined
	// interface without importing this package's concrete error value —
	// see courses.Handler.Purchase.
	ErrAlreadyPurchased = &conflictErr{msg: "mentoring: course already purchased"}

	// ErrAlreadyHasMentor is returned by RequestMentor when the student
	// already has an open or assigned ticket in this org — the handler maps
	// this to HTTP 409.
	ErrAlreadyHasMentor = &conflictErr{msg: "mentoring: you already have an active mentor request"}

	// ErrCouponHeld is returned by CreatePurchase on a
	// ux_course_purchases_coupon_user_open violation: this student already has
	// an open (pending or completed) purchase using this coupon, so a second
	// discounted checkout must not be opened. StartCheckout translates it to
	// coupons.ErrAlreadyUsed, which is what the API surfaces.
	ErrCouponHeld = errors.New("mentoring: coupon already held by an open purchase")
)

// conflictErr is a sentinel error type that signals "this is a conflict, not
// a server fault" to callers that only know about a narrow local interface
// (IsConflict() bool), not this package's concrete types.
type conflictErr struct{ msg string }

func (e *conflictErr) Error() string    { return e.msg }
func (e *conflictErr) IsConflict() bool { return true }

// clientErr mirrors conflictErr for "the client can fix this by sending
// something different" errors (bad state, missing precondition) — see
// Service.Refund. Kept distinct from ErrInvalid (a plain sentinel checked
// via errors.Is within this package) because courses.Handler needs to
// detect it through a local interface without importing mentoring's
// concrete error value.
type clientErr struct{ msg string }

func (e *clientErr) Error() string      { return e.msg }
func (e *clientErr) IsClientError() bool { return true }

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, committing on success and rolling back on
// any error fn returns. Mirrors courses.Repo's tx helper.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("mentoring: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("mentoring: commit tx: %w", err)
	}
	return nil
}

// rowScanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query),
// letting scan helpers work with either.
type rowScanner interface {
	Scan(dest ...any) error
}

const purchaseColumns = `id, org_id, user_id, course_id, amount_cents, discount_cents, currency,
	provider, provider_ref, payment_ref, coupon_id, status, receipt_number, purchased_at, updated_at`

func scanPurchase(row rowScanner) (Purchase, error) {
	var p Purchase
	err := row.Scan(&p.ID, &p.OrgID, &p.UserID, &p.CourseID, &p.AmountCents, &p.DiscountCents, &p.Currency,
		&p.Provider, &p.ProviderRef, &p.PaymentRef, &p.CouponID, &p.Status, &p.ReceiptNumber, &p.PurchasedAt, &p.UpdatedAt)
	return p, err
}

// CreatePurchase inserts a new 'pending' course_purchases row — the record
// checkout-start creates before ever contacting the gateway, so a charge can
// never exist without a row to confirm/fail it against. ProviderRef must
// already be a unique placeholder (see mentoring.newPendingProviderRef); the
// real gateway reference overwrites it once CreateCheckout returns (see
// SetProviderRef).
func (r *Repo) CreatePurchase(ctx context.Context, p Purchase) (Purchase, error) {
	p.Status = PurchaseStatusPending
	created, err := scanPurchase(r.pool.QueryRow(ctx,
		`INSERT INTO course_purchases (org_id, user_id, course_id, amount_cents, discount_cents, currency, provider, provider_ref, coupon_id, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		 RETURNING `+purchaseColumns,
		p.OrgID, p.UserID, p.CourseID, p.AmountCents, p.DiscountCents, p.Currency, p.Provider, p.ProviderRef, p.CouponID, p.Status,
	))
	if err != nil {
		// ux_course_purchases_coupon_user_open (009_coupon_hold_guard.sql) is
		// what actually makes "one open checkout per user per coupon" atomic —
		// a check-then-insert here would still let two concurrent requests
		// both open a discounted checkout with a one-per-customer coupon.
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.ConstraintName == "ux_course_purchases_coupon_user_open" {
			return Purchase{}, ErrCouponHeld
		}
		return Purchase{}, fmt.Errorf("mentoring: create purchase: %w", err)
	}
	return created, nil
}

// purchaseHoldWindow is how long a 'pending' course_purchases row is treated
// as a live checkout — both for reusing it on a retry (GetLivePendingPurchase)
// and for how long it holds a coupon against its per-user/redemption caps
// (ExpireStaleCouponHolds, CountLiveCouponHolds). After this it is an
// abandoned checkout that must never keep blocking a new one.
const purchaseHoldWindow = "30 minutes"

// ExpireStaleCouponHolds fails userID's abandoned coupon-backed checkouts so
// ux_course_purchases_coupon_user_open stops treating them as a live hold —
// without this, walking away from a coupon checkout would lock that student
// out of the coupon until the gateway got around to expiring the session
// (24h on Stripe, never on Razorpay).
func (r *Repo) ExpireStaleCouponHolds(ctx context.Context, userID, couponID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE course_purchases SET status = $3, updated_at = now()
		 WHERE user_id = $1 AND coupon_id = $2 AND status = $4
		   AND purchased_at < now() - interval '`+purchaseHoldWindow+`'`,
		userID, couponID, PurchaseStatusFailed, PurchaseStatusPending)
	if err != nil {
		return fmt.Errorf("mentoring: expire stale coupon holds: %w", err)
	}
	return nil
}

// CountLiveCouponHolds counts the still-live checkouts holding couponID but
// not yet confirmed — added to coupons.redeemed_count, this is what a
// max_redemptions check at checkout-start must compare against, so a capped
// coupon can't be handed to far more paying students than it allows just
// because none of their webhooks have landed yet.
func (r *Repo) CountLiveCouponHolds(ctx context.Context, couponID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM course_purchases
		  WHERE coupon_id = $1 AND status = $2
		    AND purchased_at > now() - interval '`+purchaseHoldWindow+`'`,
		couponID, PurchaseStatusPending,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("mentoring: count live coupon holds: %w", err)
	}
	return n, nil
}

// GetLivePendingPurchase returns a still-fresh (younger than 30 minutes)
// pending purchase for userID+courseID+provider+coupon, if one exists — used
// to make double-click/retry on StartCheckout reuse the same gateway
// session instead of creating a second one. Returns ErrNotFound if none.
func (r *Repo) GetLivePendingPurchase(ctx context.Context, userID, courseID, provider string, couponID *string) (Purchase, error) {
	p, err := scanPurchase(r.pool.QueryRow(ctx,
		`SELECT `+purchaseColumns+` FROM course_purchases
		 WHERE user_id = $1 AND course_id = $2 AND provider = $3 AND status = $4
		   AND (coupon_id = $5 OR (coupon_id IS NULL AND $5 IS NULL))
		   AND purchased_at > now() - interval '`+purchaseHoldWindow+`'
		 ORDER BY purchased_at DESC LIMIT 1`,
		userID, courseID, provider, PurchaseStatusPending, couponID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, ErrNotFound
		}
		return Purchase{}, fmt.Errorf("mentoring: get live pending purchase: %w", err)
	}
	return p, nil
}

// SetProviderRef overwrites a pending purchase's placeholder provider_ref
// with the gateway's real session/order id, once CreateCheckout returns it.
func (r *Repo) SetProviderRef(ctx context.Context, id, providerRef string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE course_purchases SET provider_ref = $2, updated_at = now() WHERE id = $1`, id, providerRef)
	if err != nil {
		return fmt.Errorf("mentoring: set provider ref: %w", err)
	}
	return nil
}

// GetPurchaseByProviderRef looks up the purchase a webhook event's
// ProviderRef confirms or fails — the gateway has no notion of our purchase
// id until CreateCheckout hands it the session/order id, so this is the only
// lookup key a webhook can use.
func (r *Repo) GetPurchaseByProviderRef(ctx context.Context, provider, providerRef string) (Purchase, error) {
	p, err := scanPurchase(r.pool.QueryRow(ctx,
		`SELECT `+purchaseColumns+` FROM course_purchases WHERE provider = $1 AND provider_ref = $2`,
		provider, providerRef,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, ErrNotFound
		}
		return Purchase{}, fmt.Errorf("mentoring: get purchase by provider ref: %w", err)
	}
	return p, nil
}

// MarkPurchaseCompletedTx transitions a purchase from 'pending' to
// 'completed' within tx. Zero rows updated means the purchase was already
// completed by an earlier webhook delivery (or isn't pending for some other
// reason) — the caller treats that as a safe no-op, since this guarded
// transition (not payment_events dedup alone) is the real idempotency
// backstop against a duplicated webhook. A unique violation on
// ux_course_purchases_completed means the user somehow completed two
// separate purchases for the same course concurrently — surfaced to the
// caller to log loudly rather than silently picking one.
func (r *Repo) MarkPurchaseCompletedTx(ctx context.Context, tx pgx.Tx, id, paymentRef string) (Purchase, bool, error) {
	p, err := scanPurchase(tx.QueryRow(ctx,
		`UPDATE course_purchases
		 SET status = $2, payment_ref = $3, purchased_at = now(), updated_at = now(),
		     receipt_number = 'MF-' || extract(year from now())::text || '-' || lpad(nextval('receipt_number_seq')::text, 6, '0')
		 WHERE id = $1 AND status = $4
		 RETURNING `+purchaseColumns,
		id, PurchaseStatusCompleted, paymentRef, PurchaseStatusPending,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, false, nil
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return Purchase{}, false, ErrAlreadyPurchased
		}
		return Purchase{}, false, fmt.Errorf("mentoring: mark purchase completed: %w", err)
	}
	return p, true, nil
}

// MarkPurchaseFailed transitions a purchase from 'pending' to 'failed' — a
// no-op if it's already left 'pending' (e.g. a failure event delivered after
// a success event already completed it, which must never downgrade a
// completed purchase).
func (r *Repo) MarkPurchaseFailed(ctx context.Context, id string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE course_purchases SET status = $2, updated_at = now() WHERE id = $1 AND status = $3`,
		id, PurchaseStatusFailed, PurchaseStatusPending)
	if err != nil {
		return fmt.Errorf("mentoring: mark purchase failed: %w", err)
	}
	return nil
}

// GetPurchase returns a single purchase by id, scoped to orgID — used by the
// student-facing receipt page and the staff-facing refund action, both of
// which need one specific purchase rather than "the latest for this course".
func (r *Repo) GetPurchase(ctx context.Context, orgID, id string) (Purchase, error) {
	p, err := scanPurchase(r.pool.QueryRow(ctx,
		`SELECT `+purchaseColumns+` FROM course_purchases WHERE id = $1 AND org_id = $2`,
		id, orgID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, ErrNotFound
		}
		return Purchase{}, fmt.Errorf("mentoring: get purchase: %w", err)
	}
	return p, nil
}

// MarkPurchaseRefundedTx transitions a purchase from 'completed' to
// 'refunded' within tx. Zero rows updated means it wasn't 'completed'
// (already refunded, or never completed) — the caller must not have already
// called the gateway's refund API in that case, so this is checked before
// the gateway call, not just guarded here (see Service.Refund).
func (r *Repo) MarkPurchaseRefundedTx(ctx context.Context, tx pgx.Tx, id string) (Purchase, bool, error) {
	p, err := scanPurchase(tx.QueryRow(ctx,
		`UPDATE course_purchases SET status = $2, updated_at = now()
		 WHERE id = $1 AND status = $3
		 RETURNING `+purchaseColumns,
		id, PurchaseStatusRefunded, PurchaseStatusCompleted,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, false, nil
		}
		return Purchase{}, false, fmt.Errorf("mentoring: mark purchase refunded: %w", err)
	}
	return p, true, nil
}

// InsertPaymentEvent records a webhook delivery for dedup + audit.
// UNIQUE(provider, event_id) makes this the actual replay guard: inserted
// reports false when a gateway redelivers an event we've already seen
// (Stripe retries for up to 72h; both gateways may redeliver), which the
// caller treats as a no-op, not an error.
func (r *Repo) InsertPaymentEvent(ctx context.Context, provider, eventID, eventType, providerRef string, purchaseID *string, payload []byte) (id string, inserted bool, err error) {
	err = r.pool.QueryRow(ctx,
		`INSERT INTO payment_events (provider, event_id, event_type, provider_ref, purchase_id, payload)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (provider, event_id) DO NOTHING
		 RETURNING id`,
		provider, eventID, eventType, providerRef, purchaseID, payload,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", false, nil
		}
		return "", false, fmt.Errorf("mentoring: insert payment event: %w", err)
	}
	return id, true, nil
}

// MarkPaymentEventProcessedTx marks a payment_events row processed within
// tx, atomically with the purchase-state transition it caused.
func (r *Repo) MarkPaymentEventProcessedTx(ctx context.Context, tx pgx.Tx, eventRowID, purchaseID string) error {
	_, err := tx.Exec(ctx,
		`UPDATE payment_events SET processed_at = now(), purchase_id = $2 WHERE id = $1`, eventRowID, purchaseID)
	if err != nil {
		return fmt.Errorf("mentoring: mark payment event processed: %w", err)
	}
	return nil
}

// MarkPaymentEventError records why a payment_events row couldn't be applied
// (no matching purchase, amount mismatch) without failing the webhook
// request — the delivery is still acked 200 so the gateway doesn't retry a
// condition retrying will never fix; the error is left for an operator to
// investigate.
func (r *Repo) MarkPaymentEventError(ctx context.Context, eventRowID, msg string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE payment_events SET processed_at = now(), error = $2 WHERE id = $1`, eventRowID, msg)
	if err != nil {
		return fmt.Errorf("mentoring: mark payment event error: %w", err)
	}
	return nil
}

// MarkPaymentEventProcessed marks a payment_events row processed with no
// purchase to associate it with — used for events that authenticated fine
// but had nothing to act on (StatusIgnored, or a failure event whose
// purchase was already handled).
func (r *Repo) MarkPaymentEventProcessed(ctx context.Context, eventRowID string) error {
	_, err := r.pool.Exec(ctx, `UPDATE payment_events SET processed_at = now() WHERE id = $1`, eventRowID)
	if err != nil {
		return fmt.Errorf("mentoring: mark payment event processed: %w", err)
	}
	return nil
}

// GetLatestPurchase returns the most recent purchase attempt (any status)
// for userID+courseID, scoped to orgID — the row the frontend's checkout
// return page polls via PurchaseStatus. Returns ErrNotFound if the student
// has never attempted to purchase this course.
func (r *Repo) GetLatestPurchase(ctx context.Context, orgID, userID, courseID string) (Purchase, error) {
	p, err := scanPurchase(r.pool.QueryRow(ctx,
		`SELECT `+purchaseColumns+` FROM course_purchases
		 WHERE org_id = $1 AND user_id = $2 AND course_id = $3
		 ORDER BY purchased_at DESC LIMIT 1`,
		orgID, userID, courseID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Purchase{}, ErrNotFound
		}
		return Purchase{}, fmt.Errorf("mentoring: get latest purchase: %w", err)
	}
	return p, nil
}

// HasActiveMentor reports whether studentID already has an open or assigned
// mentor ticket in orgID — used to dedupe ticket creation on repeat purchases.
func (r *Repo) HasActiveMentor(ctx context.Context, tx pgx.Tx, orgID, studentID string) (bool, error) {
	var exists bool
	err := tx.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM mentor_tickets
		   WHERE org_id = $1 AND student_id = $2 AND status IN ('open','assigned')
		 )`, orgID, studentID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has active mentor: %w", err)
	}
	return exists, nil
}

// HasBeenMentoredBy reports whether mentorID has ever actually been assigned
// to studentID — checked against the durable mentor_ticket_assignments
// history (not mentor_tickets.assigned_mentor_id, which only reflects the
// CURRENT mentor and is cleared on reassignment). Used to gate mentor
// ratings — a student can rate any mentor who has mentored them, past or
// present.
func (r *Repo) HasBeenMentoredBy(ctx context.Context, orgID, studentID, mentorID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM mentor_ticket_assignments
		   WHERE org_id = $1 AND student_id = $2 AND mentor_id = $3
		 )`, orgID, studentID, mentorID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has been mentored by: %w", err)
	}
	return exists, nil
}

// HasCompletedPurchase reports whether userID has a completed purchase on
// record for courseID — the "has this learner paid" check certificates'
// threshold-based auto-issue uses for non-free courses.
func (r *Repo) HasCompletedPurchase(ctx context.Context, userID, courseID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM course_purchases
		   WHERE user_id = $1 AND course_id = $2 AND status = $3
		 )`, userID, courseID, PurchaseStatusCompleted,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has completed purchase: %w", err)
	}
	return exists, nil
}

// CreateTicket opens a new 'open' mentor ticket within tx.
func (r *Repo) CreateTicket(ctx context.Context, tx pgx.Tx, t Ticket) (Ticket, error) {
	t.Status = TicketStatusOpen
	err := tx.QueryRow(ctx,
		`INSERT INTO mentor_tickets (org_id, student_id, course_id, purchase_id, status)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING id, created_at, updated_at`,
		t.OrgID, t.StudentID, t.CourseID, t.PurchaseID, t.Status,
	).Scan(&t.ID, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return Ticket{}, fmt.Errorf("mentoring: create ticket: %w", err)
	}
	return t, nil
}

const ticketColumns = `id, org_id, student_id, course_id, purchase_id, status,
	assigned_mentor_id, assigned_by, assigned_at, closed_at, escalation_level, created_at, updated_at`

func scanTicket(row rowScanner) (Ticket, error) {
	var t Ticket
	err := row.Scan(&t.ID, &t.OrgID, &t.StudentID, &t.CourseID, &t.PurchaseID, &t.Status,
		&t.AssignedMentorID, &t.AssignedBy, &t.AssignedAt, &t.ClosedAt, &t.EscalationLevel, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

// recordAssignment inserts a durable mentor_ticket_assignments row so
// HasBeenMentoredBy can still recognize a previous mentor after the ticket
// is later reassigned (assigned_mentor_id on mentor_tickets only ever
// reflects the CURRENT mentor).
func recordAssignment(ctx context.Context, tx pgx.Tx, orgID, ticketID, mentorID, studentID string) error {
	_, err := tx.Exec(ctx,
		`INSERT INTO mentor_ticket_assignments (org_id, ticket_id, mentor_id, student_id)
		 VALUES ($1,$2,$3,$4)`,
		orgID, ticketID, mentorID, studentID)
	if err != nil {
		return fmt.Errorf("mentoring: record assignment: %w", err)
	}
	return nil
}

// ListTicketAssignments returns every mentor ever assigned to ticketID, in
// chronological order — the durable history behind mentor_tickets'
// current-only assigned_mentor_id.
func (r *Repo) ListTicketAssignments(ctx context.Context, ticketID string) ([]TicketAssignment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, ticket_id, mentor_id, assigned_at
		 FROM mentor_ticket_assignments
		 WHERE ticket_id = $1
		 ORDER BY assigned_at ASC`, ticketID,
	)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list ticket assignments: %w", err)
	}
	defer rows.Close()

	assignments := []TicketAssignment{}
	for rows.Next() {
		var a TicketAssignment
		if err := rows.Scan(&a.ID, &a.TicketID, &a.MentorID, &a.AssignedAt); err != nil {
			return nil, fmt.Errorf("mentoring: list ticket assignments: scan: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("mentoring: list ticket assignments: rows: %w", err)
	}
	return assignments, nil
}

// ClaimTicket lets mentorID self-assign an open ticket within orgID. Returns
// ErrTicketAlreadyClaimed if the ticket doesn't exist in this org or is no
// longer open — the same error for "not found" and "not open" avoids leaking
// whether a ticket exists in another org (mirrors the RBAC "identical 404"
// no-leak convention).
func (r *Repo) ClaimTicket(ctx context.Context, orgID, ticketID, mentorID string) (Ticket, error) {
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'assigned', assigned_mentor_id = $1, assigned_by = $1, assigned_at = now(), updated_at = now()
			 WHERE id = $2 AND org_id = $3 AND status = 'open'
			 RETURNING `+ticketColumns,
			mentorID, ticketID, orgID)
		var txErr error
		t, txErr = scanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return recordAssignment(ctx, tx, orgID, ticketID, mentorID, t.StudentID)
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return Ticket{}, ErrTicketAlreadyClaimed
		}
		return Ticket{}, fmt.Errorf("mentoring: claim ticket: %w", err)
	}
	return t, nil
}

// AssignTicket lets a staff member (assignedBy) hand-assign mentorID to an
// open ticket within orgID. Returns ErrTicketAlreadyClaimed if the ticket
// doesn't exist in this org or is no longer open.
func (r *Repo) AssignTicket(ctx context.Context, orgID, ticketID, mentorID, assignedBy string) (Ticket, error) {
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'assigned', assigned_mentor_id = $1, assigned_by = $2, assigned_at = now(), updated_at = now()
			 WHERE id = $3 AND org_id = $4 AND status = 'open'
			 RETURNING `+ticketColumns,
			mentorID, assignedBy, ticketID, orgID)
		var txErr error
		t, txErr = scanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return recordAssignment(ctx, tx, orgID, ticketID, mentorID, t.StudentID)
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return Ticket{}, ErrTicketAlreadyClaimed
		}
		return Ticket{}, fmt.Errorf("mentoring: assign ticket: %w", err)
	}
	return t, nil
}

// IsMentor reports whether userID holds the 'mentor' org role in orgID —
// used to validate the target of AssignTicket before hand-assigning a
// ticket to them.
func (r *Repo) IsMentor(ctx context.Context, orgID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members WHERE org_id = $1 AND user_id = $2 AND role = 'mentor')`,
		orgID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: is mentor: %w", err)
	}
	return exists, nil
}

// CloseTicket closes a ticket within orgID that isn't already closed.
func (r *Repo) CloseTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_tickets
		 SET status = 'closed', closed_at = now(), updated_at = now()
		 WHERE id = $1 AND org_id = $2 AND status != 'closed'
		 RETURNING `+ticketColumns,
		ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("mentoring: close ticket: %w", err)
	}
	return t, nil
}

// GetTicket returns a single ticket by ID, scoped to orgID.
func (r *Repo) GetTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+ticketColumns+` FROM mentor_tickets WHERE id = $1 AND org_id = $2`, ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("mentoring: get ticket: %w", err)
	}
	return t, nil
}

// ListTickets returns tickets for orgID, optionally filtered by status,
// assigned_mentor_id (a mentor's own queue), and/or student_id (a student's
// own tickets).
func (r *Repo) ListTickets(ctx context.Context, orgID string, status *string, mentorID *string, studentID *string) ([]Ticket, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	n := 2
	if status != nil && *status != "" {
		where += fmt.Sprintf(" AND status = $%d", n)
		args = append(args, *status)
		n++
	}
	if mentorID != nil && *mentorID != "" {
		where += fmt.Sprintf(" AND assigned_mentor_id = $%d", n)
		args = append(args, *mentorID)
		n++
	}
	if studentID != nil && *studentID != "" {
		where += fmt.Sprintf(" AND student_id = $%d", n)
		args = append(args, *studentID)
		n++
	}
	rows, err := r.pool.Query(ctx,
		`SELECT `+ticketColumns+` FROM mentor_tickets `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list tickets: %w", err)
	}
	defer rows.Close()
	out := []Ticket{}
	for rows.Next() {
		t, err := scanTicket(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan ticket: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListMentorDirectory returns every mentor-role org member with their live
// assigned-mentee count (mentor_tickets, status='assigned') and aggregated
// rating (feedback, subject_type='mentor'). Mirrors the aggregation idiom
// used by assessment.Repo.GetBatchProgress: subquery joins, one round-trip.
func (r *Repo) ListMentorDirectory(ctx context.Context, orgID string) ([]MentorDirectoryEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email, u.avatar_url, u.created_at,
		        COALESCE(mt.mentee_count, 0) AS mentee_count,
		        fb.avg_rating, COALESCE(fb.rating_count, 0) AS rating_count,
		        p.bio, p.current_role, p.years_of_experience,
		        COALESCE(sk.skills, '{}') AS skills
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 LEFT JOIN (
		   SELECT assigned_mentor_id, COUNT(*) AS mentee_count
		   FROM mentor_tickets
		   WHERE status = 'assigned'
		   GROUP BY assigned_mentor_id
		 ) mt ON mt.assigned_mentor_id = u.id
		 LEFT JOIN (
		   SELECT subject_id, AVG(rating) AS avg_rating, COUNT(rating) AS rating_count
		   FROM feedback
		   WHERE subject_type = 'mentor' AND rating IS NOT NULL
		   GROUP BY subject_id
		 ) fb ON fb.subject_id = u.id
		 LEFT JOIN (
		   SELECT user_id, array_agg(skill_name ORDER BY created_at) AS skills
		   FROM user_skills
		   GROUP BY user_id
		 ) sk ON sk.user_id = u.id
		 WHERE om.org_id = $1 AND om.role = 'mentor'
		 ORDER BY u.name`, orgID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list mentor directory: %w", err)
	}
	defer rows.Close()

	out := []MentorDirectoryEntry{}
	for rows.Next() {
		var m MentorDirectoryEntry
		if err := rows.Scan(
			&m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.JoinedAt, &m.MenteeCount, &m.AvgRating, &m.RatingCount,
			&m.Bio, &m.CurrentRole, &m.YearsOfExperience, &m.Skills,
		); err != nil {
			return nil, fmt.Errorf("mentoring: scan mentor directory entry: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// GetMentorProfile returns the single-mentor superset of ListMentorDirectory
// shown on a mentor's profile page. Deliberately four small queries instead
// of one large CTE — each is independently easy to read/verify, and this
// only runs once per profile-page view (not once per row in a list).
func (r *Repo) GetMentorProfile(ctx context.Context, orgID, mentorID string) (MentorProfile, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT u.id, u.name, u.email, u.avatar_url, u.created_at,
		        COALESCE(mt.mentee_count, 0) AS mentee_count,
		        fb.avg_rating, COALESCE(fb.rating_count, 0) AS rating_count,
		        p.bio, p.current_role, p.years_of_experience,
		        COALESCE(sk.skills, '{}') AS skills,
		        COALESCE(p.mentor_verified, false) AS mentor_verified, p.mentor_verified_at,
		        u.last_active_at, sl.linkedin, sl.github, sl.portfolio
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 LEFT JOIN user_social_links sl ON sl.user_id = u.id
		 LEFT JOIN (
		   SELECT assigned_mentor_id, COUNT(*) AS mentee_count
		   FROM mentor_tickets
		   WHERE status = 'assigned'
		   GROUP BY assigned_mentor_id
		 ) mt ON mt.assigned_mentor_id = u.id
		 LEFT JOIN (
		   SELECT subject_id, AVG(rating) AS avg_rating, COUNT(rating) AS rating_count
		   FROM feedback
		   WHERE subject_type = 'mentor' AND rating IS NOT NULL
		   GROUP BY subject_id
		 ) fb ON fb.subject_id = u.id
		 LEFT JOIN (
		   SELECT user_id, array_agg(skill_name ORDER BY created_at) AS skills
		   FROM user_skills
		   GROUP BY user_id
		 ) sk ON sk.user_id = u.id
		 WHERE om.org_id = $1 AND om.role = 'mentor' AND u.id = $2`,
		orgID, mentorID)

	var m MentorProfile
	if err := row.Scan(
		&m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.JoinedAt, &m.MenteeCount, &m.AvgRating, &m.RatingCount,
		&m.Bio, &m.CurrentRole, &m.YearsOfExperience, &m.Skills, &m.Verified, &m.VerifiedAt,
		&m.LastActiveAt, &m.LinkedIn, &m.GitHub, &m.Portfolio,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return MentorProfile{}, ErrNotFound
		}
		return MentorProfile{}, fmt.Errorf("mentoring: get mentor profile: %w", err)
	}

	respErr := r.pool.QueryRow(ctx,
		`WITH thread AS (
		   SELECT m.ticket_id,
		          MIN(m.created_at) FILTER (WHERE m.sender_id = t.student_id) AS student_first,
		          MIN(m.created_at) FILTER (WHERE m.sender_id = t.assigned_mentor_id) AS mentor_first
		   FROM mentor_chat_messages m
		   JOIN mentor_tickets t ON t.id = m.ticket_id
		   WHERE t.org_id = $1 AND t.assigned_mentor_id = $2
		   GROUP BY m.ticket_id
		 )
		 SELECT AVG(EXTRACT(EPOCH FROM (mentor_first - student_first)) / 60)
		 FROM thread
		 WHERE student_first IS NOT NULL AND mentor_first IS NOT NULL AND mentor_first > student_first`,
		orgID, mentorID).Scan(&m.AvgResponseMinutes)
	if respErr != nil {
		return MentorProfile{}, fmt.Errorf("mentoring: get mentor avg response time: %w", respErr)
	}

	hoursErr := r.pool.QueryRow(ctx,
		`SELECT SUM(EXTRACT(EPOCH FROM (ce.ends_at - ce.starts_at)) / 3600)
		 FROM calendar_events ce
		 JOIN calendar_event_attendees cea ON cea.event_id = ce.id
		 WHERE ce.org_id = $1 AND cea.user_id = $2 AND ce.event_type = 'mentor_session'
		   AND ce.status != 'cancelled' AND ce.ends_at IS NOT NULL AND ce.starts_at < now()`,
		orgID, mentorID).Scan(&m.TotalMentorshipHours)
	if hoursErr != nil {
		return MentorProfile{}, fmt.Errorf("mentoring: get mentor total hours: %w", hoursErr)
	}

	rankErr := r.pool.QueryRow(ctx,
		`WITH monthly AS (
		   SELECT om.user_id,
		     (SELECT COUNT(DISTINCT ce.id) FROM calendar_events ce
		        JOIN calendar_event_attendees cea ON cea.event_id = ce.id
		        WHERE cea.user_id = om.user_id AND ce.org_id = om.org_id AND ce.event_type = 'mentor_session'
		          AND ce.status != 'cancelled'
		          AND ce.starts_at >= date_trunc('month', now())
		          AND ce.starts_at < date_trunc('month', now()) + interval '1 month'
		     ) AS session_count,
		     (SELECT COUNT(*) FROM feedback fb
		        WHERE fb.subject_id = om.user_id AND fb.subject_type = 'mentor' AND fb.rating IS NOT NULL
		          AND fb.created_at >= date_trunc('month', now())
		          AND fb.created_at < date_trunc('month', now()) + interval '1 month'
		     ) AS rating_count
		   FROM org_members om
		   WHERE om.org_id = $1 AND om.role = 'mentor'
		 ),
		 active AS (
		   SELECT user_id, PERCENT_RANK() OVER (ORDER BY session_count DESC, rating_count DESC) AS pct_rank
		   FROM monthly
		   WHERE session_count > 0 OR rating_count > 0
		 )
		 SELECT pct_rank FROM active WHERE user_id = $2`,
		orgID, mentorID).Scan(&m.PercentileRank)
	if rankErr != nil && !errors.Is(rankErr, pgx.ErrNoRows) {
		return MentorProfile{}, fmt.Errorf("mentoring: get mentor percentile rank: %w", rankErr)
	}

	return m, nil
}

// SetMentorVerified toggles the verified-expert badge on mentorID's profile,
// upserting user_profiles since a mentor may not have completed onboarding
// (and so may not have a row there yet).
func (r *Repo) SetMentorVerified(ctx context.Context, mentorID string, verified bool, verifiedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_profiles (user_id, mentor_verified, mentor_verified_at, mentor_verified_by)
		 VALUES ($1, $2, CASE WHEN $2 THEN now() ELSE NULL END, $3)
		 ON CONFLICT (user_id) DO UPDATE SET
		   mentor_verified = EXCLUDED.mentor_verified,
		   mentor_verified_at = EXCLUDED.mentor_verified_at,
		   mentor_verified_by = EXCLUDED.mentor_verified_by`,
		mentorID, verified, verifiedBy)
	if err != nil {
		return fmt.Errorf("mentoring: set mentor verified: %w", err)
	}
	return nil
}

const reportColumns = `id, org_id, mentor_id, reporter_id, ticket_id, reason, description, status,
	resolved_by, resolution_note, resolved_at, created_at`

func scanReport(row rowScanner) (Report, error) {
	var rep Report
	err := row.Scan(&rep.ID, &rep.OrgID, &rep.MentorID, &rep.ReporterID, &rep.TicketID, &rep.Reason,
		&rep.Description, &rep.Status, &rep.ResolvedBy, &rep.ResolutionNote, &rep.ResolvedAt, &rep.CreatedAt)
	return rep, err
}

// CreateReport files a new mentor complaint report with status 'open'.
func (r *Repo) CreateReport(ctx context.Context, rep Report) (Report, error) {
	rep.Status = ReportStatusOpen
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_reports (org_id, mentor_id, reporter_id, ticket_id, reason, description, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 RETURNING `+reportColumns,
		rep.OrgID, rep.MentorID, rep.ReporterID, rep.TicketID, rep.Reason, rep.Description, rep.Status)
	created, err := scanReport(row)
	if err != nil {
		return Report{}, fmt.Errorf("mentoring: create report: %w", err)
	}
	return created, nil
}

// ListReports returns reports for orgID, optionally filtered by status.
func (r *Repo) ListReports(ctx context.Context, orgID string, status *string) ([]Report, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx, `SELECT `+reportColumns+` FROM mentor_reports `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list reports: %w", err)
	}
	defer rows.Close()
	out := []Report{}
	for rows.Next() {
		rep, err := scanReport(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan report: %w", err)
		}
		out = append(out, rep)
	}
	return out, rows.Err()
}

// ResolveReport marks a report within orgID resolved or dismissed. status
// must be ReportStatusResolved or ReportStatusDismissed (validated by the
// service).
func (r *Repo) ResolveReport(ctx context.Context, orgID, reportID, resolvedBy, status, note string) (Report, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_reports
		 SET status = $1, resolved_by = $2, resolution_note = $3, resolved_at = now()
		 WHERE id = $4 AND org_id = $5
		 RETURNING `+reportColumns,
		status, resolvedBy, note, reportID, orgID)
	rep, err := scanReport(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, ErrNotFound
		}
		return Report{}, fmt.Errorf("mentoring: resolve report: %w", err)
	}
	return rep, nil
}

// ListReportsByTicket returns every complaint report filed against
// ticketID, most recent first — used by GetTicketDetail. Callers must check
// mentoring.manage_reports before calling this; it is not checked here.
func (r *Repo) ListReportsByTicket(ctx context.Context, ticketID string) ([]Report, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+reportColumns+` FROM mentor_reports WHERE ticket_id = $1 ORDER BY created_at DESC`, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list reports by ticket: %w", err)
	}
	defer rows.Close()
	out := []Report{}
	for rows.Next() {
		rep, err := scanReport(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan report: %w", err)
		}
		out = append(out, rep)
	}
	return out, rows.Err()
}

const chatMessageColumns = `id, org_id, ticket_id, sender_id, body, created_at`

func scanChatMessage(row rowScanner) (ChatMessage, error) {
	var m ChatMessage
	err := row.Scan(&m.ID, &m.OrgID, &m.TicketID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateChatMessage posts a new message on ticketID's chat thread.
func (r *Repo) CreateChatMessage(ctx context.Context, orgID, ticketID, senderID, body string) (ChatMessage, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_chat_messages (org_id, ticket_id, sender_id, body)
		 VALUES ($1,$2,$3,$4)
		 RETURNING `+chatMessageColumns,
		orgID, ticketID, senderID, body)
	m, err := scanChatMessage(row)
	if err != nil {
		return ChatMessage{}, fmt.Errorf("mentoring: create chat message: %w", err)
	}
	return m, nil
}

// ListChatMessages returns every message on ticketID's chat thread, oldest first.
func (r *Repo) ListChatMessages(ctx context.Context, orgID, ticketID string) ([]ChatMessage, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+chatMessageColumns+` FROM mentor_chat_messages
		 WHERE org_id = $1 AND ticket_id = $2
		 ORDER BY created_at ASC`,
		orgID, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list chat messages: %w", err)
	}
	defer rows.Close()
	out := []ChatMessage{}
	for rows.Next() {
		m, err := scanChatMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan chat message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

const mentorConversationColumns = `id, org_id, student_id, mentor_id, created_at, updated_at`

func scanMentorConversation(row rowScanner) (MentorConversation, error) {
	var c MentorConversation
	err := row.Scan(&c.ID, &c.OrgID, &c.StudentID, &c.MentorID, &c.CreatedAt, &c.UpdatedAt)
	return c, err
}

// GetOrCreateConversation returns the existing DM thread between studentID
// and mentorID within orgID, creating it (and bumping updated_at) if it
// doesn't exist yet — the get-or-create idiom for a UNIQUE(org_id,
// student_id, mentor_id) row.
func (r *Repo) GetOrCreateConversation(ctx context.Context, orgID, studentID, mentorID string) (MentorConversation, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_conversations (org_id, student_id, mentor_id)
		 VALUES ($1,$2,$3)
		 ON CONFLICT (org_id, student_id, mentor_id) DO UPDATE SET updated_at = now()
		 RETURNING `+mentorConversationColumns,
		orgID, studentID, mentorID)
	c, err := scanMentorConversation(row)
	if err != nil {
		return MentorConversation{}, fmt.Errorf("mentoring: get or create conversation: %w", err)
	}
	return c, nil
}

// GetConversation returns a single conversation by ID, scoped to orgID.
func (r *Repo) GetConversation(ctx context.Context, orgID, conversationID string) (MentorConversation, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+mentorConversationColumns+` FROM mentor_conversations WHERE id = $1 AND org_id = $2`,
		conversationID, orgID)
	c, err := scanMentorConversation(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return MentorConversation{}, ErrNotFound
		}
		return MentorConversation{}, fmt.Errorf("mentoring: get conversation: %w", err)
	}
	return c, nil
}

// ListMyConversations returns every conversation userID is a party to
// (as either student or mentor) within orgID, most recently active first.
func (r *Repo) ListMyConversations(ctx context.Context, orgID, userID string) ([]MentorConversation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+mentorConversationColumns+` FROM mentor_conversations
		 WHERE org_id = $1 AND (student_id = $2 OR mentor_id = $2)
		 ORDER BY updated_at DESC`,
		orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list my conversations: %w", err)
	}
	defer rows.Close()
	out := []MentorConversation{}
	for rows.Next() {
		c, err := scanMentorConversation(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan conversation: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const directMessageColumns = `id, org_id, conversation_id, sender_id, body, created_at`

func scanDirectMessage(row rowScanner) (DirectMessage, error) {
	var m DirectMessage
	err := row.Scan(&m.ID, &m.OrgID, &m.ConversationID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateDirectMessage posts a new message on conversationID's DM thread, and
// bumps the conversation's updated_at so ListMyConversations sorts it to the top.
func (r *Repo) CreateDirectMessage(ctx context.Context, orgID, conversationID, senderID, body string) (DirectMessage, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_direct_messages (org_id, conversation_id, sender_id, body)
		 VALUES ($1,$2,$3,$4)
		 RETURNING `+directMessageColumns,
		orgID, conversationID, senderID, body)
	m, err := scanDirectMessage(row)
	if err != nil {
		return DirectMessage{}, fmt.Errorf("mentoring: create direct message: %w", err)
	}
	if _, err := r.pool.Exec(ctx,
		`UPDATE mentor_conversations SET updated_at = now() WHERE id = $1`, conversationID,
	); err != nil {
		return DirectMessage{}, fmt.Errorf("mentoring: touch conversation: %w", err)
	}
	return m, nil
}

// ListDirectMessages returns every message on conversationID's thread, oldest first.
func (r *Repo) ListDirectMessages(ctx context.Context, orgID, conversationID string) ([]DirectMessage, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+directMessageColumns+` FROM mentor_direct_messages
		 WHERE org_id = $1 AND conversation_id = $2
		 ORDER BY created_at ASC`,
		orgID, conversationID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list direct messages: %w", err)
	}
	defer rows.Close()
	out := []DirectMessage{}
	for rows.Next() {
		m, err := scanDirectMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan direct message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

const changeRequestColumns = `id, org_id, ticket_id, student_id, reason, status,
	reviewed_by, review_note, reviewed_at, created_at`

func scanChangeRequest(row rowScanner) (ChangeRequest, error) {
	var cr ChangeRequest
	err := row.Scan(&cr.ID, &cr.OrgID, &cr.TicketID, &cr.StudentID, &cr.Reason, &cr.Status,
		&cr.ReviewedBy, &cr.ReviewNote, &cr.ReviewedAt, &cr.CreatedAt)
	return cr, err
}

// CreateChangeRequest files a new pending mentor-change request for a ticket.
// Returns ErrChangeRequestPending if one is already pending for this ticket
// (UNIQUE (ticket_id) WHERE status='pending').
func (r *Repo) CreateChangeRequest(ctx context.Context, cr ChangeRequest) (ChangeRequest, error) {
	cr.Status = ChangeRequestStatusPending
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_change_requests (org_id, ticket_id, student_id, reason, status)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING `+changeRequestColumns,
		cr.OrgID, cr.TicketID, cr.StudentID, cr.Reason, cr.Status)
	created, err := scanChangeRequest(row)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ChangeRequest{}, ErrChangeRequestPending
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: create change request: %w", err)
	}
	return created, nil
}

// ListChangeRequests returns change requests for orgID, optionally filtered
// by status.
func (r *Repo) ListChangeRequests(ctx context.Context, orgID string, status *string) ([]ChangeRequest, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx, `SELECT `+changeRequestColumns+` FROM mentor_change_requests `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list change requests: %w", err)
	}
	defer rows.Close()
	out := []ChangeRequest{}
	for rows.Next() {
		cr, err := scanChangeRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan change request: %w", err)
		}
		out = append(out, cr)
	}
	return out, rows.Err()
}

// ListChangeRequestsByTicket returns every change request ever filed for
// ticketID, most recent first — used by GetTicketDetail to assemble a
// ticket's full lifecycle alongside its assignments and reports.
func (r *Repo) ListChangeRequestsByTicket(ctx context.Context, ticketID string) ([]ChangeRequest, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+changeRequestColumns+` FROM mentor_change_requests WHERE ticket_id = $1 ORDER BY created_at DESC`, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list change requests by ticket: %w", err)
	}
	defer rows.Close()
	out := []ChangeRequest{}
	for rows.Next() {
		cr, err := scanChangeRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan change request: %w", err)
		}
		out = append(out, cr)
	}
	return out, rows.Err()
}

// GetChangeRequest returns a single change request scoped to orgID.
func (r *Repo) GetChangeRequest(ctx context.Context, orgID, requestID string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+changeRequestColumns+` FROM mentor_change_requests WHERE id = $1 AND org_id = $2`, requestID, orgID)
	cr, err := scanChangeRequest(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ChangeRequest{}, ErrNotFound
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: get change request: %w", err)
	}
	return cr, nil
}

// DenyChangeRequest marks a pending request denied within orgID. Returns
// ErrNotFound if the request doesn't exist in this org or is no longer pending.
func (r *Repo) DenyChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_change_requests
		 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
		 WHERE id = $4 AND org_id = $5 AND status = $6
		 RETURNING `+changeRequestColumns,
		ChangeRequestStatusDenied, reviewedBy, note, requestID, orgID, ChangeRequestStatusPending)
	cr, err := scanChangeRequest(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ChangeRequest{}, ErrNotFound
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: deny change request: %w", err)
	}
	return cr, nil
}

// ApproveChangeRequest marks a pending request approved and reopens its
// ticket (status back to 'open', mentor cleared, escalation_level reset to 0
// so the fresh assignment cycle re-escalates from scratch) atomically within
// orgID. Returns ErrNotFound if the request doesn't exist in this org or is
// no longer pending.
func (r *Repo) ApproveChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, Ticket, error) {
	var cr ChangeRequest
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_change_requests
			 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
			 WHERE id = $4 AND org_id = $5 AND status = $6
			 RETURNING `+changeRequestColumns,
			ChangeRequestStatusApproved, reviewedBy, note, requestID, orgID, ChangeRequestStatusPending)
		var txErr error
		cr, txErr = scanChangeRequest(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("update change request: %w", txErr)
		}

		ticketRow := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'open', assigned_mentor_id = NULL, assigned_by = NULL,
			     assigned_at = NULL, escalation_level = 0, updated_at = now()
			 WHERE id = $1 AND org_id = $2
			 RETURNING `+ticketColumns,
			cr.TicketID, orgID)
		t, txErr = scanTicket(ticketRow)
		if txErr != nil {
			return fmt.Errorf("reopen ticket %s: %w", cr.TicketID, txErr)
		}
		return nil
	})
	if err != nil {
		return ChangeRequest{}, Ticket{}, err
	}
	return cr, t, nil
}

package mentoring

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/tickets"
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

// CreatePurchase inserts a new 'pending' purchases row — the record
// checkout-start creates before ever contacting the gateway, so a charge can
// never exist without a row to confirm/fail it against. ProviderRef must
// already be a unique placeholder (see mentoring.newPendingProviderRef); the
// real gateway reference overwrites it once CreateCheckout returns (see
// SetProviderRef).
func (r *Repo) CreatePurchase(ctx context.Context, p Purchase) (Purchase, error) {
	return createPurchase(ctx, r.pool, p)
}

// CreatePurchaseTx is CreatePurchase run inside an in-flight transaction —
// used when the insert must happen while StartCheckout still holds the
// coupon row lock from LockCouponRedeemedCount, so the redemption-cap check
// and the hold it protects can't race with a concurrent checkout for the
// same coupon.
func (r *Repo) CreatePurchaseTx(ctx context.Context, tx pgx.Tx, p Purchase) (Purchase, error) {
	return createPurchase(ctx, tx, p)
}

// dbtx is satisfied by both *pgxpool.Pool and pgx.Tx, letting a query run
// either standalone or inside an in-flight transaction without a second copy.
type dbtx interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func createPurchase(ctx context.Context, db dbtx, p Purchase) (Purchase, error) {
	p.Status = PurchaseStatusPending
	created, err := scanPurchase(db.QueryRow(ctx,
		`INSERT INTO purchases (org_id, user_id, course_id, amount_cents, discount_cents, currency, provider, provider_ref, coupon_id, status, product_type)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		 RETURNING `+purchaseColumns,
		p.OrgID, p.UserID, p.CourseID, p.AmountCents, p.DiscountCents, p.Currency, p.Provider, p.ProviderRef, p.CouponID, p.Status, "course",
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

// LockCouponRedeemedCount locks the coupon row FOR UPDATE and returns its
// current redeemed_count. Must run inside the same transaction as the
// CreatePurchaseTx call it protects — the lock only closes the concurrent-
// redemption race while held through both the check and the insert; reading
// it standalone would just narrow the window, not close it.
func (r *Repo) LockCouponRedeemedCount(ctx context.Context, tx pgx.Tx, couponID string) (int, error) {
	var n int
	if err := tx.QueryRow(ctx, `SELECT redeemed_count FROM coupons WHERE id = $1 FOR UPDATE`, couponID).Scan(&n); err != nil {
		return 0, fmt.Errorf("mentoring: lock coupon: %w", err)
	}
	return n, nil
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
		`UPDATE purchases SET status = $3, updated_at = now()
		 WHERE user_id = $1 AND coupon_id = $2 AND status = $4 AND product_type = 'course'
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
	return countLiveCouponHolds(ctx, r.pool, couponID)
}

// CountLiveCouponHoldsTx is CountLiveCouponHolds run inside the same
// transaction as LockCouponRedeemedCount/CreatePurchaseTx — see
// LockCouponRedeemedCount's doc comment.
func (r *Repo) CountLiveCouponHoldsTx(ctx context.Context, tx pgx.Tx, couponID string) (int, error) {
	return countLiveCouponHolds(ctx, tx, couponID)
}

func countLiveCouponHolds(ctx context.Context, db dbtx, couponID string) (int, error) {
	var n int
	err := db.QueryRow(ctx,
		`SELECT COUNT(*) FROM purchases
		  WHERE coupon_id = $1 AND status = $2 AND product_type = 'course'
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
		`SELECT `+purchaseColumns+` FROM purchases
		 WHERE user_id = $1 AND course_id = $2 AND provider = $3 AND status = $4 AND product_type = 'course'
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
		`UPDATE purchases SET provider_ref = $2, updated_at = now() WHERE id = $1`, id, providerRef)
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
		`SELECT `+purchaseColumns+` FROM purchases WHERE provider = $1 AND provider_ref = $2 AND product_type = 'course'`,
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
		`UPDATE purchases
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
		`UPDATE purchases SET status = $2, updated_at = now() WHERE id = $1 AND status = $3`,
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
		`SELECT `+purchaseColumns+` FROM purchases WHERE id = $1 AND org_id = $2`,
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
		`UPDATE purchases SET status = $2, updated_at = now()
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
		`SELECT `+purchaseColumns+` FROM purchases
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
// HasActiveMentor reports whether studentID has an open or assigned
// mentorship ticket in orgID — the dedup check RequestMentor and
// confirmPurchase use before opening a new one. Deliberately kind='mentorship'
// only: a ticket-independent DM (kind='direct') is not a mentor assignment
// and must not suppress ticket creation.
func (r *Repo) HasActiveMentor(ctx context.Context, tx pgx.Tx, orgID, studentID string) (bool, error) {
	var exists bool
	err := tx.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM conversations
		   WHERE org_id = $1 AND requester_id = $2 AND kind = 'mentorship' AND status IN ('open','assigned')
		 )`, orgID, studentID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has active mentor: %w", err)
	}
	return exists, nil
}

// HasBeenMentoredBy reports whether mentorID is or was the assigned mentor
// on one of studentID's mentorship tickets. Deliberately kind='mentorship'
// only: a ticket-independent DM (kind='direct') is not a mentorship and must
// not count for rating/report/certificate eligibility. Note:
// mentor_ticket_assignments history was dropped in an earlier schema
// refactor; this can only detect the current assignment, not past ones.
func (r *Repo) HasBeenMentoredBy(ctx context.Context, orgID, studentID, mentorID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM conversations
		   WHERE org_id = $1 AND requester_id = $2 AND kind = 'mentorship' AND assigned_to = $3
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
		   SELECT 1 FROM purchases
		   WHERE user_id = $1 AND course_id = $2 AND status = $3
		 )`, userID, courseID, PurchaseStatusCompleted,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has completed purchase: %w", err)
	}
	return exists, nil
}

// CreateTicket opens a new 'open' mentorship conversation within tx.
// ClaimTicket lets mentorID self-assign an open mentorship ticket within
// orgID. Returns ErrTicketAlreadyClaimed if the ticket doesn't exist in this
// org or is no longer open — the same error for "not found" and "not open"
// avoids leaking whether a ticket exists in another org (mirrors the RBAC
// "identical 404" no-leak convention). Deliberately kind='mentorship' only:
// a ticket-independent DM (kind='direct') must never be claimable.
func (r *Repo) ClaimTicket(ctx context.Context, orgID, ticketID, mentorID string) (tickets.Ticket, error) {
	var t tickets.Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE conversations
			 SET status = 'assigned', assigned_to = $1
			 WHERE id = $2 AND org_id = $3 AND kind = 'mentorship' AND status = 'open'
			 RETURNING `+tickets.TicketColumns,
			mentorID, ticketID, orgID)
		var txErr error
		t, txErr = tickets.ScanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return tickets.Ticket{}, ErrTicketAlreadyClaimed
		}
		return tickets.Ticket{}, fmt.Errorf("mentoring: claim ticket: %w", err)
	}
	return t, nil
}

// AssignTicket lets a staff member (assignedBy) hand-assign mentorID to an
// open mentorship ticket within orgID. Returns ErrTicketAlreadyClaimed if the
// ticket doesn't exist in this org or is no longer open.
// Note: assignedBy info is not persisted (the schema has no assigned_by
// column on conversations).
func (r *Repo) AssignTicket(ctx context.Context, orgID, ticketID, mentorID, assignedBy string) (tickets.Ticket, error) {
	var t tickets.Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE conversations
			 SET status = 'assigned', assigned_to = $1
			 WHERE id = $2 AND org_id = $3 AND kind = 'mentorship' AND status = 'open'
			 RETURNING `+tickets.TicketColumns,
			mentorID, ticketID, orgID)
		var txErr error
		t, txErr = tickets.ScanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return tickets.Ticket{}, ErrTicketAlreadyClaimed
		}
		return tickets.Ticket{}, fmt.Errorf("mentoring: assign ticket: %w", err)
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

// CloseTicket closes a mentorship ticket within orgID that isn't already
// closed. Deliberately kind='mentorship' only: a ticket-independent DM must
// never be closeable through this path.
func (r *Repo) CloseTicket(ctx context.Context, orgID, ticketID string) (tickets.Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE conversations
		 SET status = 'closed', closed_at = now()
		 WHERE id = $1 AND org_id = $2 AND kind = 'mentorship' AND status != 'closed'
		 RETURNING `+tickets.TicketColumns,
		ticketID, orgID)
	t, err := tickets.ScanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return tickets.Ticket{}, ErrNotFound
		}
		return tickets.Ticket{}, fmt.Errorf("mentoring: close ticket: %w", err)
	}
	return t, nil
}

// ListMentorDirectory returns every mentor-role org member with their live
// assigned-mentee count (conversations with kind='mentorship', status='assigned')
// and aggregated rating (feedback, subject_type='mentor').
// Note: Skills are now stored in user_profiles.skills (jsonb); empty list returned here,
// callers should fetch skills separately if needed.
func (r *Repo) ListMentorDirectory(ctx context.Context, orgID string) ([]MentorDirectoryEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email, u.avatar_url, u.created_at,
		        COALESCE(mt.mentee_count, 0) AS mentee_count,
		        fb.avg_rating, COALESCE(fb.rating_count, 0) AS rating_count,
		        p.bio, p.current_role, p.years_of_experience
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 LEFT JOIN (
		   SELECT assigned_to, COUNT(*) AS mentee_count
		   FROM conversations
		   WHERE kind = 'mentorship' AND status = 'assigned'
		   GROUP BY assigned_to
		 ) mt ON mt.assigned_to = u.id
		 LEFT JOIN (
		   SELECT subject_id, AVG(rating) AS avg_rating, COUNT(rating) AS rating_count
		   FROM feedback
		   WHERE subject_type = 'mentor' AND rating IS NOT NULL
		   GROUP BY subject_id
		 ) fb ON fb.subject_id = u.id
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
			&m.Bio, &m.CurrentRole, &m.YearsOfExperience,
		); err != nil {
			return nil, fmt.Errorf("mentoring: scan mentor directory entry: %w", err)
		}
		m.Skills = []string{}
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
		        COALESCE(p.mentor_verified, false) AS mentor_verified, p.mentor_verified_at,
		        u.last_active_at, p.linkedin_url, p.github_url, p.portfolio_url
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 LEFT JOIN (
		   SELECT assigned_to, COUNT(*) AS mentee_count
		   FROM conversations
		   WHERE kind = 'mentorship' AND status = 'assigned'
		   GROUP BY assigned_to
		 ) mt ON mt.assigned_to = u.id
		 LEFT JOIN (
		   SELECT subject_id, AVG(rating) AS avg_rating, COUNT(rating) AS rating_count
		   FROM feedback
		   WHERE subject_type = 'mentor' AND rating IS NOT NULL
		   GROUP BY subject_id
		 ) fb ON fb.subject_id = u.id
		 WHERE om.org_id = $1 AND om.role = 'mentor' AND u.id = $2`,
		orgID, mentorID)

	var m MentorProfile
	if err := row.Scan(
		&m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.JoinedAt, &m.MenteeCount, &m.AvgRating, &m.RatingCount,
		&m.Bio, &m.CurrentRole, &m.YearsOfExperience, &m.Verified, &m.VerifiedAt,
		&m.LastActiveAt, &m.LinkedIn, &m.GitHub, &m.Portfolio,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return MentorProfile{}, ErrNotFound
		}
		return MentorProfile{}, fmt.Errorf("mentoring: get mentor profile: %w", err)
	}
	m.Skills = []string{} // Skills are in jsonb now; empty list for backward compat

	respErr := r.pool.QueryRow(ctx,
		`WITH thread AS (
		   SELECT c.id,
		          MIN(m.created_at) FILTER (WHERE m.sender_id = c.requester_id) AS student_first,
		          MIN(m.created_at) FILTER (WHERE m.sender_id = c.assigned_to) AS mentor_first
		   FROM messages m
		   JOIN conversations c ON c.id = m.thread_id
		   WHERE c.org_id = $1 AND c.assigned_to = $2 AND c.kind = 'mentorship' AND m.thread_type = 'mentor_ticket'
		   GROUP BY c.id
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

const reportColumns = `id, org_id, content_id, reporter_id, reason, description, status,
	resolved_by, resolution_note, resolved_at, created_at`

func scanReport(row rowScanner) (Report, error) {
	var rep Report
	err := row.Scan(&rep.ID, &rep.OrgID, &rep.MentorID, &rep.ReporterID, &rep.Reason,
		&rep.Description, &rep.Status, &rep.ResolvedBy, &rep.ResolutionNote, &rep.ResolvedAt, &rep.CreatedAt)
	// Note: TicketID is not available in new schema (content_reports doesn't track it)
	return rep, err
}

// CreateReport files a new mentor complaint report with status 'pending'.
// Maps to content_reports with content_type='mentor', content_id=mentor_id.
func (r *Repo) CreateReport(ctx context.Context, rep Report) (Report, error) {
	rep.Status = ReportStatusOpen
	row := r.pool.QueryRow(ctx,
		`INSERT INTO content_reports (org_id, reporter_id, content_type, content_id, reason, description, status)
		 VALUES ($1,$2,'mentor',$3,$4,$5,$6)
		 RETURNING `+reportColumns,
		rep.OrgID, rep.ReporterID, rep.MentorID, rep.Reason, rep.Description, rep.Status)
	created, err := scanReport(row)
	if err != nil {
		return Report{}, fmt.Errorf("mentoring: create report: %w", err)
	}
	return created, nil
}

// ListReports returns mentor reports for orgID, optionally filtered by status.
func (r *Repo) ListReports(ctx context.Context, orgID string, status *string) ([]Report, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1 AND content_type = 'mentor'"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx, `SELECT `+reportColumns+` FROM content_reports `+where+` ORDER BY created_at DESC`, args...)
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

// ResolveReport marks a mentor report within orgID resolved or dismissed. status
// must be ReportStatusResolved or ReportStatusDismissed (validated by the service).
func (r *Repo) ResolveReport(ctx context.Context, orgID, reportID, resolvedBy, status, note string) (Report, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE content_reports
		 SET status = $1, resolved_by = $2, resolution_note = $3, resolved_at = now()
		 WHERE id = $4 AND org_id = $5 AND content_type = 'mentor'
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

// ListReportsByTicket returns every complaint report filed about the mentor
// of the given ticketID, most recent first. Note: mentor_reports.ticket_id
// was dropped in the schema refactor; this now looks up the mentor from the
// conversation and returns all reports about that mentor.
func (r *Repo) ListReportsByTicket(ctx context.Context, ticketID string) ([]Report, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT cr.id, cr.org_id, cr.content_id, cr.reporter_id, cr.reason, cr.description, cr.status,
		        cr.resolved_by, cr.resolution_note, cr.resolved_at, cr.created_at
		 FROM content_reports cr
		 JOIN conversations c ON c.id = $1
		 WHERE cr.content_type = 'mentor' AND cr.content_id = c.assigned_to
		 ORDER BY cr.created_at DESC`, ticketID)
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

const mentorConversationColumns = `id, org_id, requester_id, counterpart_id, created_at, created_at`

func scanMentorConversation(row rowScanner) (MentorConversation, error) {
	var c MentorConversation
	var createdAt1, createdAt2 time.Time
	err := row.Scan(&c.ID, &c.OrgID, &c.StudentID, &c.MentorID, &createdAt1, &createdAt2)
	if err == nil {
		c.CreatedAt = createdAt1
		c.UpdatedAt = createdAt2 // Use second created_at as UpdatedAt (conversations doesn't track it separately)
	}
	return c, err
}

// GetOrCreateConversation returns the existing DM thread between studentID
// and mentorID within orgID, creating it if it doesn't exist yet.
// Maps to conversations with kind='direct', using requester_id and counterpart_id.
func (r *Repo) GetOrCreateConversation(ctx context.Context, orgID, studentID, mentorID string) (MentorConversation, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO conversations (org_id, kind, requester_id, counterpart_id, status)
		 VALUES ($1,'direct',$2,$3,'open')
		 ON CONFLICT (org_id, requester_id, counterpart_id) WHERE kind = 'direct' DO UPDATE SET created_at = created_at
		 RETURNING `+mentorConversationColumns,
		orgID, studentID, mentorID)
	c, err := scanMentorConversation(row)
	if err != nil {
		return MentorConversation{}, fmt.Errorf("mentoring: get or create conversation: %w", err)
	}
	return c, nil
}

// GetConversation returns a single direct conversation by ID, scoped to orgID.
func (r *Repo) GetConversation(ctx context.Context, orgID, conversationID string) (MentorConversation, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+mentorConversationColumns+` FROM conversations WHERE id = $1 AND org_id = $2 AND kind = 'direct'`,
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

// ListMyConversations returns every direct conversation userID is a party to
// (as either requester or counterpart) within orgID.
func (r *Repo) ListMyConversations(ctx context.Context, orgID, userID string) ([]MentorConversation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+mentorConversationColumns+` FROM conversations
		 WHERE org_id = $1 AND kind = 'direct' AND (requester_id = $2 OR counterpart_id = $2)
		 ORDER BY created_at DESC`,
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

const directMessageColumns = `id, org_id, thread_id, sender_id, body, created_at`

func scanDirectMessage(row rowScanner) (DirectMessage, error) {
	var m DirectMessage
	err := row.Scan(&m.ID, &m.OrgID, &m.ConversationID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateDirectMessage posts a new message on conversationID's DM thread (messages.thread_type='mentor_conversation').
// Note: conversations doesn't have an updated_at column, so we don't bump it.
func (r *Repo) CreateDirectMessage(ctx context.Context, orgID, conversationID, senderID, body string) (DirectMessage, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO messages (org_id, thread_type, thread_id, sender_id, body)
		 VALUES ($1,'mentor_conversation',$2,$3,$4)
		 RETURNING `+directMessageColumns,
		orgID, conversationID, senderID, body)
	m, err := scanDirectMessage(row)
	if err != nil {
		return DirectMessage{}, fmt.Errorf("mentoring: create direct message: %w", err)
	}
	return m, nil
}

// ListDirectMessages returns every message on conversationID's thread, oldest first.
func (r *Repo) ListDirectMessages(ctx context.Context, orgID, conversationID string) ([]DirectMessage, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+directMessageColumns+` FROM messages
		 WHERE org_id = $1 AND thread_type = 'mentor_conversation' AND thread_id = $2
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

const changeRequestColumns = `id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
	reviewed_by, review_note, reviewed_at, created_at`

func scanChangeRequest(row rowScanner) (ChangeRequest, error) {
	var cr ChangeRequest
	err := row.Scan(&cr.ID, &cr.OrgID, &cr.TicketID, &cr.StudentID, &cr.Reason, &cr.Status,
		&cr.ReviewedBy, &cr.ReviewNote, &cr.ReviewedAt, &cr.CreatedAt)
	return cr, err
}

// CreateChangeRequest files a new pending mentor-change request for a ticket.
// Maps to change_requests with kind='mentor_reassignment', storing reason in requested_change jsonb.
// Returns ErrChangeRequestPending if one is already pending for this subject
// (database constraint on kind/subject_type/subject_id/status).
func (r *Repo) CreateChangeRequest(ctx context.Context, cr ChangeRequest) (ChangeRequest, error) {
	cr.Status = ChangeRequestStatusPending
	requestedChange, _ := json.Marshal(map[string]string{"reason": cr.Reason})
	row := r.pool.QueryRow(ctx,
		`INSERT INTO change_requests (org_id, kind, requester_id, subject_type, subject_id, requested_change, status)
		 VALUES ($1,'mentor_reassignment',$2,'mentor_ticket',$3,$4,$5)
		 RETURNING id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
		          reviewed_by, review_note, reviewed_at, created_at`,
		cr.OrgID, cr.StudentID, cr.TicketID, requestedChange, cr.Status)
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

// ListChangeRequests returns mentor reassignment change requests for orgID,
// optionally filtered by status.
func (r *Repo) ListChangeRequests(ctx context.Context, orgID string, status *string) ([]ChangeRequest, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1 AND kind = 'mentor_reassignment'"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
		        reviewed_by, review_note, reviewed_at, created_at
		 FROM change_requests `+where+` ORDER BY created_at DESC`, args...)
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
// ticket's full lifecycle.
func (r *Repo) ListChangeRequestsByTicket(ctx context.Context, ticketID string) ([]ChangeRequest, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
		        reviewed_by, review_note, reviewed_at, created_at
		 FROM change_requests
		 WHERE kind = 'mentor_reassignment' AND subject_type = 'mentor_ticket' AND subject_id = $1
		 ORDER BY created_at DESC`, ticketID)
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

// GetChangeRequest returns a single mentor reassignment request scoped to orgID.
func (r *Repo) GetChangeRequest(ctx context.Context, orgID, requestID string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
		        reviewed_by, review_note, reviewed_at, created_at
		 FROM change_requests
		 WHERE id = $1 AND org_id = $2 AND kind = 'mentor_reassignment'`, requestID, orgID)
	cr, err := scanChangeRequest(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ChangeRequest{}, ErrNotFound
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: get change request: %w", err)
	}
	return cr, nil
}

// DenyChangeRequest marks a pending mentor reassignment request denied within orgID.
// Returns ErrNotFound if the request doesn't exist in this org or is no longer pending.
func (r *Repo) DenyChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE change_requests
		 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
		 WHERE id = $4 AND org_id = $5 AND kind = 'mentor_reassignment' AND status = $6
		 RETURNING id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
		          reviewed_by, review_note, reviewed_at, created_at`,
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

// ApproveChangeRequest marks a pending mentor reassignment request approved and reopens its
// ticket (status back to 'open', mentor cleared, escalation_level reset to 0)
// atomically within orgID.
func (r *Repo) ApproveChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, tickets.Ticket, error) {
	var cr ChangeRequest
	var t tickets.Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE change_requests
			 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
			 WHERE id = $4 AND org_id = $5 AND kind = 'mentor_reassignment' AND status = $6
			 RETURNING id, org_id, subject_id, requester_id, requested_change->>'reason' as reason, status,
			          reviewed_by, review_note, reviewed_at, created_at`,
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
			`UPDATE conversations
			 SET status = 'open', assigned_to = NULL, escalation_level = 0
			 WHERE id = $1 AND org_id = $2 AND kind = 'mentorship'
			 RETURNING `+tickets.TicketColumns,
			cr.TicketID, orgID)
		t, txErr = tickets.ScanTicket(ticketRow)
		if txErr != nil {
			return fmt.Errorf("reopen ticket %s: %w", cr.TicketID, txErr)
		}
		return nil
	})
	if err != nil {
		return ChangeRequest{}, tickets.Ticket{}, err
	}
	return cr, t, nil
}

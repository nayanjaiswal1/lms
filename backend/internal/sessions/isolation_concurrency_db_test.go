package sessions

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// failingProjector makes every calendar projection fail; Book tolerates that
// (the booking stays), which keeps these tests about the booking transaction.
type failingProjector struct{}

func (failingProjector) CreateEvent(context.Context, calendar.Event, []string) (calendar.Event, error) {
	return calendar.Event{}, errors.New("calendar disabled in test")
}
func (failingProjector) DeleteEvent(context.Context, string, string, string, string, *time.Time) error {
	return nil
}
func (failingProjector) UpdateEvent(context.Context, string, string, string, string, *time.Time, calendar.Event) (calendar.Event, error) {
	return calendar.Event{}, nil
}

type bookingFixture struct {
	svc      *Service
	repo     *Repo
	orgID    string
	mentorID string
}

func (f bookingFixture) addMember(t *testing.T, orgID, name, role string) string {
	t.Helper()
	var id string
	if err := f.repo.pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("%s-%d@%s", name, time.Now().UnixNano(), testdomain.Domain), name).Scan(&id); err != nil {
		t.Fatalf("seed user %s: %v", name, err)
	}
	if _, err := f.repo.pool.Exec(context.Background(),
		`INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, $3)`, orgID, id, role); err != nil {
		t.Fatalf("seed member %s: %v", name, err)
	}
	return id
}

func newOrg(t *testing.T, repo *Repo, slug string) string {
	t.Helper()
	var id string
	if err := repo.pool.QueryRow(context.Background(),
		`INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(&id); err != nil {
		t.Fatalf("seed org %s: %v", slug, err)
	}
	return id
}

func newBookingFixture(t *testing.T, requireCredits bool) bookingFixture {
	t.Helper()
	repo := NewRepo(testdb.New(t))
	svc := NewService(repo, failingProjector{}, nil, &config.Config{PaymentsCurrency: "USD"})
	f := bookingFixture{svc: svc, repo: repo}
	f.orgID = newOrg(t, repo, "book-org")
	f.mentorID = f.addMember(t, f.orgID, "mentor", "mentor")
	cfg := DefaultConfig(f.orgID)
	cfg.RequireCredits = requireCredits
	cfg.MinNoticeHours = 0
	cfg.MaxUpcomingPerStudent = 100
	cfg.BookingHorizonDays = 365
	if _, err := repo.UpsertConfig(context.Background(), cfg); err != nil {
		t.Fatalf("upsert config: %v", err)
	}
	return f
}

func (f bookingFixture) book(studentID string, start time.Time) (Session, error) {
	return f.svc.Book(context.Background(), BookRequest{
		OrgID: f.orgID, CallerID: studentID, MentorID: f.mentorID, StudentID: studentID,
		StartsAt: start, EndsAt: start.Add(30 * time.Minute),
	})
}

func runConcurrently(n int, fn func(i int)) {
	var wg sync.WaitGroup
	start := make(chan struct{})
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			fn(i)
		}(i)
	}
	close(start)
	wg.Wait()
}

// Tenant B must not read or modify tenant A's session by id.
func TestSessions_TenantIsolation(t *testing.T) {
	f := newBookingFixture(t, false)
	ctx := context.Background()
	student := f.addMember(t, f.orgID, "student", "learner")
	sess, err := f.book(student, time.Now().Add(48*time.Hour).Truncate(time.Second))
	if err != nil {
		t.Fatalf("book in org A: %v", err)
	}
	orgB := newOrg(t, f.repo, "other-org")

	// Even the real participants, asking through org B, learn nothing.
	for _, caller := range []string{f.mentorID, student} {
		if _, err := f.repo.GetSession(ctx, orgB, sess.ID, caller); !errors.Is(err, ErrNotFound) {
			t.Fatalf("GetSession via org B as %s: err=%v, want ErrNotFound", caller, err)
		}
	}
	if got, err := f.repo.ListSessions(ctx, orgB, f.mentorID, ScopeAll, 50); err != nil || len(got) != 0 {
		t.Fatalf("ListSessions org B = %d rows err=%v, want 0", len(got), err)
	}
	if _, err := f.repo.SetOutcome(ctx, orgB, sess.ID, "completed"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("SetOutcome via org B: err=%v, want ErrNotFound", err)
	}
	later := sess.StartsAt.Add(24 * time.Hour)
	if _, err := f.repo.Reschedule(ctx, orgB, sess.ID, later, later.Add(30*time.Minute)); !errors.Is(err, ErrNotFound) {
		t.Fatalf("Reschedule via org B: err=%v, want ErrNotFound", err)
	}

	// Org A's row is untouched.
	got, err := f.repo.GetSession(ctx, f.orgID, sess.ID, f.mentorID)
	if err != nil {
		t.Fatalf("GetSession org A: %v", err)
	}
	if got.Status != "scheduled" || !got.StartsAt.Equal(sess.StartsAt) {
		t.Fatalf("org A session mutated: status=%s starts=%s want scheduled %s", got.Status, got.StartsAt, sess.StartsAt)
	}
}

// Credit spend: 10 concurrent bookings against a balance of 3 -> exactly 3
// succeed, the rest are ErrInsufficientCredits, and the ledger lands on 0.
func TestBook_ConcurrentCreditSpendNeverOverdraws(t *testing.T) {
	f := newBookingFixture(t, true)
	ctx := context.Background()
	student := f.addMember(t, f.orgID, "student", "learner")
	const credits, attempts = 3, 10
	if _, err := f.repo.GrantCredits(ctx, f.orgID, student, credits, "seed", student); err != nil {
		t.Fatalf("grant: %v", err)
	}
	base := time.Now().Add(48 * time.Hour).Truncate(time.Hour)

	var mu sync.Mutex
	ok, insufficient, other := 0, 0, 0
	runConcurrently(attempts, func(i int) {
		_, err := f.book(student, base.Add(time.Duration(i)*time.Hour))
		mu.Lock()
		defer mu.Unlock()
		switch {
		case err == nil:
			ok++
		case errors.Is(err, ErrInsufficientCredits):
			insufficient++
		default:
			other++
			t.Errorf("unexpected booking error: %v", err)
		}
	})
	if ok != credits || insufficient != attempts-credits || other != 0 {
		t.Fatalf("ok=%d insufficient=%d other=%d, want %d/%d/0", ok, insufficient, other, credits, attempts-credits)
	}
	if bal, err := f.repo.CreditBalance(ctx, f.orgID, student); err != nil || bal != 0 {
		t.Fatalf("balance = %d err=%v, want 0 (never negative)", bal, err)
	}
	var rows int
	if err := f.repo.pool.QueryRow(ctx, `SELECT COUNT(*) FROM mentor_sessions WHERE org_id = $1`, f.orgID).Scan(&rows); err != nil || rows != credits {
		t.Fatalf("sessions = %d err=%v, want %d", rows, err, credits)
	}
}

// Double-book: 8 students race for the same mentor slot -> exactly one wins.
func TestBook_ConcurrentSameSlotExactlyOneWins(t *testing.T) {
	f := newBookingFixture(t, false)
	const racers = 8
	students := make([]string, racers)
	for i := range students {
		students[i] = f.addMember(t, f.orgID, fmt.Sprintf("student%d", i), "learner")
	}
	slot := time.Now().Add(72 * time.Hour).Truncate(time.Hour)

	var mu sync.Mutex
	ok, taken := 0, 0
	runConcurrently(racers, func(i int) {
		_, err := f.book(students[i], slot)
		mu.Lock()
		defer mu.Unlock()
		switch {
		case err == nil:
			ok++
		case errors.Is(err, ErrSlotTaken):
			taken++
		default:
			t.Errorf("unexpected booking error: %v", err)
		}
	})
	if ok != 1 || taken != racers-1 {
		t.Fatalf("ok=%d taken=%d, want 1/%d", ok, taken, racers-1)
	}
	var rows int
	if err := f.repo.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM mentor_sessions WHERE mentor_id = $1 AND status = 'scheduled'`, f.mentorID).Scan(&rows); err != nil || rows != 1 {
		t.Fatalf("scheduled rows = %d err=%v, want 1", rows, err)
	}
}

// Transaction rollback: Book inserts the session, then the credit-ledger row.
// A trigger makes the ledger insert fail; the session row must not survive.
func TestBook_LedgerFailureRollsBackSession(t *testing.T) {
	f := newBookingFixture(t, true)
	ctx := context.Background()
	student := f.addMember(t, f.orgID, "student", "learner")
	if _, err := f.repo.GrantCredits(ctx, f.orgID, student, 2, "seed", student); err != nil {
		t.Fatalf("grant: %v", err)
	}
	for _, stmt := range []string{
		`CREATE FUNCTION fail_booking_ledger() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
		   IF NEW.reason = 'booking' THEN RAISE EXCEPTION 'forced ledger failure'; END IF;
		   RETURN NEW; END $$`,
		`CREATE TRIGGER fail_booking_ledger BEFORE INSERT ON session_credit_ledger
		   FOR EACH ROW EXECUTE FUNCTION fail_booking_ledger()`,
	} {
		if _, err := f.repo.pool.Exec(ctx, stmt); err != nil {
			t.Fatalf("install failure trigger: %v", err)
		}
	}

	if _, err := f.book(student, time.Now().Add(48*time.Hour)); err == nil {
		t.Fatal("Book succeeded despite failing ledger insert")
	}
	var sessions int
	if err := f.repo.pool.QueryRow(ctx, `SELECT COUNT(*) FROM mentor_sessions WHERE org_id = $1`, f.orgID).Scan(&sessions); err != nil || sessions != 0 {
		t.Fatalf("mentor_sessions rows = %d err=%v, want 0 (rolled back)", sessions, err)
	}
	if bal, _ := f.repo.CreditBalance(ctx, f.orgID, student); bal != 2 {
		t.Fatalf("balance = %d, want 2 (no charge)", bal)
	}
}

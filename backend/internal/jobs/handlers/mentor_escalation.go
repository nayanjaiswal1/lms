package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// mentorEscalationStep maps an escalation level to the minimum age (in days)
// an 'open' (still unclaimed) mentor ticket must reach before that level's
// notifications fire.
type mentorEscalationStep struct {
	Level int
	Days  int
}

var mentorEscalationSteps = []mentorEscalationStep{
	{Level: 1, Days: 1}, // 1 day open  -> org mentors notified
	{Level: 2, Days: 3}, // 3 days open -> staff holding mentoring.assign_tickets notified
	{Level: 3, Days: 7}, // 7 days open -> staff notified again + the student notified
}

// staleMentorTicket is one 'open' ticket that has crossed an escalation threshold.
type staleMentorTicket struct {
	ID           string
	OrgID        string
	StudentID    string
	StudentEmail string
	StudentName  string
	CourseTitle  string
}

// contact is an email recipient resolved for an org.
type contact struct {
	ID    string
	Email string
	Name  string
}

// MentorEscalationHandler implements jobs.Handler for HandlerMentorEscalate
// jobs. On each tick it finds 'open' mentor_tickets that have just crossed a
// 1/3/7-day age threshold and enqueues escalation notification emails via
// the existing email.send job, then bumps the ticket's escalation_level so
// the same threshold is never processed twice.
type MentorEscalationHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

// NewMentorEscalationHandler constructs a MentorEscalationHandler.
func NewMentorEscalationHandler(pool *pgxpool.Pool, cfg *config.Config) *MentorEscalationHandler {
	return &MentorEscalationHandler{pool: pool, cfg: cfg}
}

// Handle processes every escalation step in ascending order so a ticket that
// has been open long enough for multiple thresholds still receives each
// level's notification on successive ticks (escalation_level only ever
// advances by one step per tick, since a fresh row starts at 0 and this loop
// only ever bumps it to the lowest still-unmet level it finds).
func (h *MentorEscalationHandler) Handle(ctx context.Context, _ jobs.Job) error {
	total := 0
	for _, step := range mentorEscalationSteps {
		n, err := h.escalateStep(ctx, step)
		if err != nil {
			return fmt.Errorf("handlers.mentor_escalation: level %d: %w", step.Level, err)
		}
		total += n
	}
	if total > 0 {
		slog.InfoContext(ctx, "handlers.mentor_escalation: tickets escalated", "count", total)
	}
	return nil
}

// escalateStep finds tickets crossing this step's threshold, enqueues the
// notification emails, and marks each ticket as having reached this level.
// Recipient lists are cached per org so a run with many stale tickets in the
// same org only resolves mentors/staff once.
func (h *MentorEscalationHandler) escalateStep(ctx context.Context, step mentorEscalationStep) (int, error) {
	rows, err := h.pool.Query(ctx,
		`SELECT conv.id, conv.org_id, conv.requester_id, u.email, u.name, co.title
		 FROM conversations conv
		 JOIN users u ON u.id = conv.requester_id
		 JOIN courses co ON co.id = conv.course_id
		 WHERE conv.kind = 'mentorship'
		   AND conv.status = 'open'
		   AND conv.escalation_level < $1
		   AND conv.created_at <= now() - make_interval(days => $2::int)
		 LIMIT 500`,
		step.Level, step.Days,
	)
	if err != nil {
		return 0, fmt.Errorf("query stale tickets: %w", err)
	}
	var tickets []staleMentorTicket
	for rows.Next() {
		var t staleMentorTicket
		if err := rows.Scan(&t.ID, &t.OrgID, &t.StudentID, &t.StudentEmail, &t.StudentName, &t.CourseTitle); err != nil {
			rows.Close()
			return 0, fmt.Errorf("scan stale ticket: %w", err)
		}
		tickets = append(tickets, t)
	}
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("stale ticket rows: %w", err)
	}
	rows.Close()
	if len(tickets) == 0 {
		return 0, nil
	}

	mentorCache := map[string][]contact{}
	staffCache := map[string][]contact{}

	escalated := 0
	for _, t := range tickets {
		var recipients []contact
		if step.Level == 1 {
			recipients, err = h.orgMentors(ctx, t.OrgID, mentorCache)
		} else {
			recipients, err = h.orgAssignStaff(ctx, t.OrgID, staffCache)
		}
		if err != nil {
			return escalated, fmt.Errorf("resolve recipients for org %s: %w", t.OrgID, err)
		}

		for _, r := range recipients {
			if err := h.enqueueEmail(ctx,
				fmt.Sprintf("mentor_escalation:%s:%d:%s", t.ID, step.Level, r.ID),
				r.Email, r.Name, staffSubject(step.Level, t.CourseTitle), staffBody(step.Level, t.CourseTitle, h.cfg.FrontendURL),
			); err != nil {
				return escalated, err
			}
		}

		if step.Level == 3 {
			if err := h.enqueueEmail(ctx,
				fmt.Sprintf("mentor_escalation:%s:%d:student", t.ID, step.Level),
				t.StudentEmail, t.StudentName, studentSubject(t.CourseTitle), studentBody(t.CourseTitle),
			); err != nil {
				return escalated, err
			}
		}

		tag, err := h.pool.Exec(ctx,
			`UPDATE conversations SET escalation_level = $1 WHERE id = $2 AND escalation_level < $1`,
			step.Level, t.ID,
		)
		if err != nil {
			return escalated, fmt.Errorf("mark ticket %s escalated: %w", t.ID, err)
		}
		if tag.RowsAffected() > 0 {
			escalated++
		}
	}
	return escalated, nil
}

// orgMentors returns every org-role 'mentor' in orgID, caching the result in
// cache for the remainder of this run.
func (h *MentorEscalationHandler) orgMentors(ctx context.Context, orgID string, cache map[string][]contact) ([]contact, error) {
	if c, ok := cache[orgID]; ok {
		return c, nil
	}
	rows, err := h.pool.Query(ctx,
		`SELECT u.id, u.email, u.name
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 WHERE om.org_id = $1 AND om.role = 'mentor' AND u.email <> ''`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("query org mentors: %w", err)
	}
	defer rows.Close()
	contacts, err := scanContacts(rows)
	if err != nil {
		return nil, err
	}
	cache[orgID] = contacts
	return contacts, nil
}

// mentoringAssignTicketsPermission mirrors mentoring.PermissionAssignTickets
// (backend/internal/mentoring/handler.go) — duplicated as a literal here
// rather than importing the mentoring package, matching how models.go
// elsewhere hardcodes strings mirroring migration CHECK constraints instead
// of taking a cross-domain dependency for a single constant.
const mentoringAssignTicketsPermission = "mentoring.assign_tickets"

// orgAssignStaff returns every user in orgID holding the mentoring.assign_tickets
// permission (via the fine-grained RBAC tables), caching the result in cache.
func (h *MentorEscalationHandler) orgAssignStaff(ctx context.Context, orgID string, cache map[string][]contact) ([]contact, error) {
	if c, ok := cache[orgID]; ok {
		return c, nil
	}
	rows, err := h.pool.Query(ctx,
		`SELECT DISTINCT u.id, u.email, u.name
		 FROM user_roles ur
		 JOIN role_permissions rp ON rp.role_id = ur.role_id
		 JOIN permissions p ON p.id = rp.permission_id
		 JOIN users u ON u.id = ur.user_id
		 WHERE ur.org_id = $1 AND p.code = $2 AND u.email <> ''`,
		orgID, mentoringAssignTicketsPermission,
	)
	if err != nil {
		return nil, fmt.Errorf("query org assign-staff: %w", err)
	}
	defer rows.Close()
	contacts, err := scanContacts(rows)
	if err != nil {
		return nil, err
	}
	cache[orgID] = contacts
	return contacts, nil
}

func scanContacts(rows pgx.Rows) ([]contact, error) {
	var contacts []contact
	for rows.Next() {
		var c contact
		if err := rows.Scan(&c.ID, &c.Email, &c.Name); err != nil {
			return nil, fmt.Errorf("scan contact: %w", err)
		}
		contacts = append(contacts, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("contact rows: %w", err)
	}
	return contacts, nil
}

// enqueueEmail inserts an email.send notification job, deduplicated by
// idempKey so re-running an escalation step is always safe.
func (h *MentorEscalationHandler) enqueueEmail(ctx context.Context, idempKey, to, toName, subject, body string) error {
	payload, err := json.Marshal(map[string]any{
		"type":    "notification",
		"to":      to,
		"to_name": toName,
		"template_data": map[string]any{
			"subject": subject,
			"body":    body,
		},
	})
	if err != nil {
		return fmt.Errorf("marshal escalation email payload: %w", err)
	}
	if _, err := h.pool.Exec(ctx,
		`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
		 VALUES ($1, 'queued', $2, $3, $4)
		 ON CONFLICT (idempotency_key) DO NOTHING`,
		HandlerEmailSend, jobs.PriorityNormal, payload, idempKey,
	); err != nil {
		return fmt.Errorf("insert escalation email job (to=%s): %w", to, err)
	}
	return nil
}

func staffSubject(level int, courseTitle string) string {
	switch level {
	case 1:
		return fmt.Sprintf("A student needs a mentor — %s", courseTitle)
	case 2:
		return fmt.Sprintf("Escalation: mentor ticket unassigned for 3 days — %s", courseTitle)
	default:
		return fmt.Sprintf("URGENT: mentor ticket unassigned for 7 days — %s", courseTitle)
	}
}

func staffBody(level int, courseTitle, frontendURL string) string {
	link := frontendURL + "/mentoring/tickets"
	switch level {
	case 1:
		return fmt.Sprintf("A student purchasing \"%s\" has been waiting a day for a mentor.\n\nClaim it here:\n%s", courseTitle, link)
	case 2:
		return fmt.Sprintf("A mentor ticket for \"%s\" has been open for 3 days with no mentor assigned. Please assign one.\n\n%s", courseTitle, link)
	default:
		return fmt.Sprintf("A mentor ticket for \"%s\" has been open for a full week with no mentor assigned. This needs immediate attention.\n\n%s", courseTitle, link)
	}
}

func studentSubject(courseTitle string) string {
	return fmt.Sprintf("An update on your mentor request for %s", courseTitle)
}

func studentBody(courseTitle string) string {
	return fmt.Sprintf(
		"Hi,\n\nWe're still working on finding you a mentor for \"%s\". "+
			"We're sorry for the delay — our team has been notified and is prioritizing your request.\n\nThe MindForge Team",
		courseTitle,
	)
}

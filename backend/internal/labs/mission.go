package labs

import (
	"context"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
)

// ─── Mission mode for composed (debug) labs ──────────────────────────────────
//
// An org picks which workspace its debug labs render through
// org_settings.labs.debug_ui. "old" (the default — an absent key, an empty
// value or anything unrecognised) is the side-panel workspace and changes
// nothing about a session. "new" is the mission workspace: a briefing the
// student starts (the clock runs from Start, not from provisioning) and
// integrity signals the browser reports for the result page. Everything
// mission-specific is gated through missionOn so the two modes never mix.

const (
	DebugUIOld = "old"
	DebugUINew = "new"
)

// DebugUIModes lists the values org_settings.labs.debug_ui accepts.
var DebugUIModes = []string{DebugUIOld, DebugUINew}

// resolveDebugUI maps the stored debug_ui value to a mode, defaulting to old.
func resolveDebugUI(raw *string) string {
	if raw != nil && *raw == DebugUINew {
		return DebugUINew
	}
	return DebugUIOld
}

// missionOn reports whether a session runs in mission mode: only composed
// (kind) labs of an org on the new UI.
func missionOn(hasKind bool, debugUI string) bool {
	return hasKind && debugUI == DebugUINew
}

// Activity event types the browser may report (lab_activity_events.event_type).
const (
	ActivityTabAway  = "tab_away"
	ActivityPaste    = "paste"
	ActivityFileOpen = "file_open"
)

const (
	// ActivityMaxBatch bounds events per POST; the client flushes in batches.
	ActivityMaxBatch = 50
	// ActivityMaxPerSession caps stored events per session so a noisy or
	// hostile client cannot grow the table without bound.
	ActivityMaxPerSession = 2000
	// ActivityMaxDetail bounds a file path, in characters.
	ActivityMaxDetail = 200
	// ActivityMaxValue bounds an event's value: 24h in ms for tab_away, and a
	// character count for paste.
	ActivityMaxValue = 24 * 60 * 60 * 1000
	// ActivityPostCooldown is the minimum gap between two activity POSTs of one session.
	ActivityPostCooldown = 2 * time.Second
	// ActivityRecentLimit is how many latest events a summary carries.
	ActivityRecentLimit = 100
	// ActivityFilesLimit is how many distinct opened files a summary lists.
	ActivityFilesLimit = 50
)

// ActivityEventInput is one event as reported by the browser.
type ActivityEventInput struct {
	Type   string `json:"type"`
	Detail string `json:"detail"`
	Value  int    `json:"value"`
}

// ActivityEvent is a stored event.
type ActivityEvent struct {
	Type       string    `json:"type"`
	Detail     string    `json:"detail"`
	Value      int       `json:"value"`
	OccurredAt time.Time `json:"occurred_at"`
}

// ActivityFile is a workspace file the student opened and how often.
type ActivityFile struct {
	Path  string `json:"path"`
	Opens int    `json:"opens"`
}

// ActivitySummary is what the result page shows about a mission session.
type ActivitySummary struct {
	TabAwayCount   int             `json:"tab_away_count"`
	TabAwayTotalMs int64           `json:"tab_away_total_ms"`
	PasteCount     int             `json:"paste_count"`
	PasteChars     int64           `json:"paste_chars"`
	FilesOpened    []ActivityFile  `json:"files_opened"`
	Recent         []ActivityEvent `json:"recent"`
}

// normalizeActivity validates one reported batch and returns the rows to store:
// unknown types are rejected, details are kept only where they mean something
// (a file path), and values are clamped.
func normalizeActivity(in []ActivityEventInput) ([]ActivityEventInput, error) {
	if len(in) == 0 || len(in) > ActivityMaxBatch {
		return nil, ErrInvalidActivity
	}
	out := make([]ActivityEventInput, 0, len(in))
	for _, e := range in {
		e.Value = max(0, min(e.Value, ActivityMaxValue))
		switch e.Type {
		case ActivityFileOpen:
			e.Detail = strings.TrimSpace(e.Detail)
			if e.Detail == "" || utf8.RuneCountInString(e.Detail) > ActivityMaxDetail {
				return nil, ErrInvalidActivity
			}
			e.Value = 0
		case ActivityTabAway, ActivityPaste:
			e.Detail = ""
		default:
			return nil, ErrInvalidActivity
		}
		out = append(out, e)
	}
	return out, nil
}

// missionContext loads a session the caller owns plus whether it runs in
// mission mode, for the endpoints that only make sense there.
func (s *Service) missionContext(ctx context.Context, sessionID, userID string) (*LabSession, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.missionContext: %w", err)
	}
	if err := s.requireMission(ctx, session); err != nil {
		return nil, err
	}
	return session, nil
}

// requireMission returns ErrMissionUIDisabled unless the session's lab is a
// composed kind and its org is on the new debug UI.
func (s *Service) requireMission(ctx context.Context, session *LabSession) error {
	lab, err := s.repo.GetLabForPlacement(ctx, session.LabID, session.OrgID)
	if err != nil {
		return fmt.Errorf("labs.requireMission: %w", err)
	}
	_, hasKind := kindFor(lab)
	cfg, err := s.repo.GetOrgConfig(ctx, session.OrgID)
	if err != nil {
		return fmt.Errorf("labs.requireMission: %w", err)
	}
	if !missionOn(hasKind, cfg.DebugUI) {
		return ErrMissionUIDisabled
	}
	return nil
}

// DebugUIFor is the workspace mode (DebugUIOld/DebugUINew) the org's debug labs render.
func (s *Service) DebugUIFor(ctx context.Context, orgID string) (string, error) {
	cfg, err := s.repo.GetOrgConfig(ctx, orgID)
	if err != nil {
		return "", fmt.Errorf("labs.Service.DebugUIFor: %w", err)
	}
	return cfg.DebugUI, nil
}

// StartMission starts the mission clock (POST /sessions/{id}/mission/start):
// the session keeps its full time budget but counts it from now, not from when
// provisioning began. Idempotent — an already started session is returned as is.
func (s *Service) StartMission(ctx context.Context, sessionID, userID string) (*LabSession, error) {
	session, err := s.missionContext(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.StartMission: %w", err)
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return nil, fmt.Errorf("labs.Service.StartMission: %w", err)
	}
	if session.MissionStartedAt != nil {
		return session, nil
	}
	if session.Status != SessionStatusRunning {
		return nil, ErrSessionNotRunning
	}
	if err := s.repo.StartMission(ctx, sessionID, userID); err != nil {
		return nil, fmt.Errorf("labs.Service.StartMission: %w", err)
	}
	started, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.StartMission: reload: %w", err)
	}
	return started, nil
}

// RecordActivity stores one batch of browser-reported integrity events
// (POST /sessions/{id}/activity). Only a started mission records anything.
func (s *Service) RecordActivity(ctx context.Context, sessionID, userID string, events []ActivityEventInput) error {
	session, err := s.missionContext(ctx, sessionID, userID)
	if err != nil {
		return fmt.Errorf("labs.Service.RecordActivity: %w", err)
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return fmt.Errorf("labs.Service.RecordActivity: %w", err)
	}
	if session.MissionStartedAt == nil {
		return ErrMissionNotStarted
	}
	rows, err := normalizeActivity(events)
	if err != nil {
		return err
	}
	if err := s.acquireCooldown(ctx, "lab:activity:rate:"+sessionID, ActivityPostCooldown, "labs.Service.RecordActivity"); err != nil {
		return fmt.Errorf("labs.Service.RecordActivity: %w", err)
	}
	if err := s.repo.InsertActivity(ctx, sessionID, rows); err != nil {
		return fmt.Errorf("labs.Service.RecordActivity: %w", err)
	}
	return nil
}

// GetActivity returns the activity summary of the caller's own session.
func (s *Service) GetActivity(ctx context.Context, sessionID, userID string) (*ActivitySummary, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.GetActivity: %w", err)
	}
	return s.activityOf(ctx, session.ID)
}

// GetOrgActivity returns the activity summary of any session of orgID, for org
// admins reviewing a candidate's attempt.
func (s *Service) GetOrgActivity(ctx context.Context, sessionID, orgID string) (*ActivitySummary, error) {
	session, err := s.repo.GetSessionByID(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.GetOrgActivity: %w", err)
	}
	if session.OrgID != orgID {
		return nil, ErrNotFound
	}
	return s.activityOf(ctx, session.ID)
}

func (s *Service) activityOf(ctx context.Context, sessionID string) (*ActivitySummary, error) {
	summary, err := s.repo.ActivitySummary(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.activityOf: %w", err)
	}
	return summary, nil
}

// SetDebugUI saves the org's debug workspace mode (admin settings).
func (s *Service) SetDebugUI(ctx context.Context, orgID, mode string) error {
	if mode != DebugUIOld && mode != DebugUINew {
		return ErrInvalidDebugUI
	}
	if err := s.repo.SetDebugUI(ctx, orgID, mode); err != nil {
		return fmt.Errorf("labs.Service.SetDebugUI: %w", err)
	}
	return nil
}

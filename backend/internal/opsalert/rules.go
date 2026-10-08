package opsalert

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// Rule is one ops_alert_rules row.
type Rule struct {
	Handler             string    `json:"handler"`
	Severity            string    `json:"severity"`
	DedupeWindowMinutes int       `json:"dedupe_window_minutes"`
	StormThreshold      int       `json:"storm_threshold"`
	StormWindowMinutes  int       `json:"storm_window_minutes"`
	Enabled             bool      `json:"enabled"`
	UpdatedAt           time.Time `json:"updated_at"`
}

const ruleColumns = `handler, severity, dedupe_window_minutes, storm_threshold, storm_window_minutes, enabled, updated_at`

// ErrInvalidRule marks a rule that failed boundary validation.
var ErrInvalidRule = errors.New("invalid alert rule")

func scanRule(row pgx.Row) (Rule, error) {
	var r Rule
	err := row.Scan(&r.Handler, &r.Severity, &r.DedupeWindowMinutes, &r.StormThreshold, &r.StormWindowMinutes, &r.Enabled, &r.UpdatedAt)
	return r, err
}

// Rule returns the handler's own rule, falling back to the '*' default row.
func (s *Service) Rule(ctx context.Context, handler string) (Rule, error) {
	r, err := scanRule(s.pool.QueryRow(ctx,
		`SELECT `+ruleColumns+` FROM ops_alert_rules WHERE handler IN ($1, $2)
		 ORDER BY (handler = $2) LIMIT 1`, handler, DefaultRuleHandler))
	if err != nil {
		return Rule{}, fmt.Errorf("load alert rule %q: %w", handler, err)
	}
	return r, nil
}

// ListRules returns all rules, default first.
func (s *Service) ListRules(ctx context.Context) ([]Rule, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+ruleColumns+` FROM ops_alert_rules ORDER BY (handler <> $1), handler`, DefaultRuleHandler)
	if err != nil {
		return nil, fmt.Errorf("opsalert.ListRules: %w", err)
	}
	defer rows.Close()
	out := []Rule{}
	for rows.Next() {
		r, err := scanRule(rows)
		if err != nil {
			return nil, fmt.Errorf("opsalert.ListRules: scan: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// Validate checks a rule's bounds (mirrors the table CHECK constraints).
func (r Rule) Validate() error {
	switch {
	case r.Handler == "" || len(r.Handler) > 128:
		return fmt.Errorf("%w: handler must be 1-128 chars", ErrInvalidRule)
	case r.Severity != SeverityLow && r.Severity != SeverityNormal && r.Severity != SeverityHigh:
		return fmt.Errorf("%w: severity must be low, normal or high", ErrInvalidRule)
	case r.DedupeWindowMinutes < 1 || r.DedupeWindowMinutes > 1440:
		return fmt.Errorf("%w: dedupe_window_minutes must be 1-1440", ErrInvalidRule)
	case r.StormWindowMinutes < 1 || r.StormWindowMinutes > 1440:
		return fmt.Errorf("%w: storm_window_minutes must be 1-1440", ErrInvalidRule)
	case r.StormThreshold < 1 || r.StormThreshold > 100000:
		return fmt.Errorf("%w: storm_threshold must be 1-100000", ErrInvalidRule)
	}
	return nil
}

// UpsertRule validates and saves a rule.
func (s *Service) UpsertRule(ctx context.Context, r Rule) (Rule, error) {
	if err := r.Validate(); err != nil {
		return Rule{}, err
	}
	out, err := scanRule(s.pool.QueryRow(ctx,
		`INSERT INTO ops_alert_rules (handler, severity, dedupe_window_minutes, storm_threshold, storm_window_minutes, enabled)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (handler) DO UPDATE SET
		   severity = EXCLUDED.severity, dedupe_window_minutes = EXCLUDED.dedupe_window_minutes,
		   storm_threshold = EXCLUDED.storm_threshold, storm_window_minutes = EXCLUDED.storm_window_minutes,
		   enabled = EXCLUDED.enabled, updated_at = NOW()
		 RETURNING `+ruleColumns,
		r.Handler, r.Severity, r.DedupeWindowMinutes, r.StormThreshold, r.StormWindowMinutes, r.Enabled))
	if err != nil {
		return Rule{}, fmt.Errorf("opsalert.UpsertRule: %w", err)
	}
	return out, nil
}

// Package whatsnew is the platform's release-notes feed shown in the
// sidebar's sparkle-icon panel (frontend/components/shared/whats-new-dialog.tsx).
// A platform admin publishes entries from /platform/whats-new, so no
// rebuild+redeploy is needed, same rationale as internal/pricing.
package whatsnew

import (
	"errors"
	"time"
)

var (
	ErrNotFound = errors.New("whatsnew: not found")
	ErrInvalid  = errors.New("whatsnew: invalid input")
)

// AllowedIcons mirrors whats_new_entries_icon_check (migration 032) — the
// fixed icon set frontend/lib/whats-new.ts's ICON_MAP can render. Kept as a
// curated set rather than an arbitrary lucide-icon string so a bad admin
// input can't ask the frontend to render an icon it doesn't ship.
var AllowedIcons = map[string]struct{}{
	"sparkles": {}, "book-open-check": {}, "list-checks": {}, "shield-check": {},
	"rocket": {}, "megaphone": {}, "zap": {}, "star": {},
}

type Entry struct {
	ID          string
	Title       string
	Description string
	Icon        string
	CTALabel    string
	CTAHref     string
	Published   bool
	PublishedAt time.Time
	CreatedBy   *string
	UpdatedAt   time.Time
}

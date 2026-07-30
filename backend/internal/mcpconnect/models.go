// Package mcpconnect lets a student connect their own Claude/ChatGPT client
// to their MindForge account as a remote MCP (Model Context Protocol) server.
// The external client authenticates via OAuth 2.1 + PKCE (no client secret —
// MCP clients are public/native apps), then calls a handful of tools that
// each delegate to the existing courses domain: read enrolled courses and
// lesson content, read/write the student's personal lesson notes, and log
// what the student understood or struggled with. MindForge never calls an
// LLM itself here — the "AI" in the loop is the student's own client, so
// there is no ai.LLMProvider dependency anywhere in this package.
package mcpconnect

import "time"

// Scopes a connection can hold. A client requests a subset at /oauth/authorize;
// every tool call checks the connection's granted scopes before acting.
const (
	ScopeCoursesRead    = "courses:read"
	ScopeCoursesWrite   = "courses:write"
	ScopeNotesWrite     = "notes:write"
	ScopeSignals        = "signals:write"
	ScopeCalendarManage = "calendar:manage"
	ScopeInterviewPrep  = "interview_prep:manage"
)

// AllScopes is the full set offered on the consent screen — this MVP grants
// all-or-nothing per connection rather than letting a client cherry-pick,
// since every scope maps to the student's own data only. ScopeCoursesWrite
// only ever touches courses the student owns (their own kind='self' courses)
// or queues a pending proposal on a shared course for a human to review —
// never a direct write to a course the student doesn't own. ScopeInterviewPrep
// covers both reading and creating prep plans/rounds — like ScopeCalendarManage,
// one combined scope rather than a read/write split, since every interview-prep
// tool call is scoped to the connection's own plans only.
var AllScopes = []string{ScopeCoursesRead, ScopeCoursesWrite, ScopeNotesWrite, ScopeSignals, ScopeCalendarManage, ScopeInterviewPrep}

// ScopeDescriptions is shown on the consent screen, keyed by scope.
var ScopeDescriptions = map[string]string{
	ScopeCoursesRead:    "Read your enrolled courses and lesson content",
	ScopeCoursesWrite:   "Create and edit your own private courses, and propose lessons to shared courses",
	ScopeNotesWrite:     "Read and write your personal lesson notes",
	ScopeSignals:        "Log what you understood or struggled with",
	ScopeCalendarManage: "View, create, update, and delete events on your calendar",
	ScopeInterviewPrep:  "Create and run interview-prep practice plans, submit coding answers, and view your readiness report",
}

func validScope(s string) bool {
	switch s {
	case ScopeCoursesRead, ScopeCoursesWrite, ScopeNotesWrite, ScopeSignals, ScopeCalendarManage, ScopeInterviewPrep:
		return true
	default:
		return false
	}
}

// Client is an external application registered via Dynamic Client Registration
// (RFC 7591) — e.g. "Claude". Public client: no secret, PKCE substitutes for
// client authentication at the token endpoint.
type Client struct {
	ClientID     string    `json:"client_id"`
	ClientName   string    `json:"client_name"`
	RedirectURIs []string  `json:"redirect_uris"`
	CreatedAt    time.Time `json:"created_at"`
}

// Connection is one user's approval of one client — holds the long-lived
// refresh token (hashed, compare-only, mirroring how the login refresh_tokens
// table stores its hash) that mints new short-lived access tokens.
type Connection struct {
	ID         string     `json:"id"`
	OrgID      string     `json:"-"`
	UserID     string     `json:"-"`
	ClientID   string     `json:"client_id"`
	ClientName string     `json:"client_name"`
	Scopes     []string   `json:"scopes"`
	Status     string     `json:"status"`
	LastUsedAt *time.Time `json:"last_used_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

// AuthCode is a single-use authorization code minted after user consent,
// exchanged once at /oauth/token then deleted. Mirrors the existing
// oauth_exchanges table's shape/TTL pattern used by social login.
type AuthCode struct {
	Code          string
	ClientID      string
	OrgID         string
	UserID        string
	Scopes        []string
	CodeChallenge string
	RedirectURI   string
	ExpiresAt     time.Time
}

// authCodeTTL is deliberately short — the code only has to survive one
// redirect hop from our consent page back to the external client's backend.
const authCodeTTL = 2 * time.Minute

// accessTokenTTL bounds how long a stolen bearer token stays useful; the
// client is expected to silently refresh well before this using its refresh
// token, the same way the browser session refreshes access_token cookies.
const accessTokenTTL = time.Hour

// refreshTokenTTL matches the login refresh token's default lifetime —
// no reason for an MCP connection to outlive a browser session by policy.
const refreshTokenTTL = 720 * time.Hour

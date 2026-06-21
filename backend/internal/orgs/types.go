package orgs

import "time"

// Role constants
const (
	RoleOwner      = "owner"
	RoleAdmin      = "admin"
	RoleMentor     = "mentor"
	RoleInstructor = "instructor"
	RoleLearner    = "learner"
)

// Org status constants
const (
	StatusPendingVerification = "pending_verification"
	StatusOnboarding          = "onboarding"
	StatusActive              = "active"
	StatusSuspended           = "suspended"
	StatusArchived            = "archived"
)

// Member status constants
const (
	MemberActive    = "active"
	MemberSuspended = "suspended"
	MemberRemoved   = "removed"
)

var roleRank = map[string]int{
	RoleOwner:      5,
	RoleAdmin:      4,
	RoleMentor:     3,
	RoleInstructor: 2,
	RoleLearner:    1,
}

// CanGrantRole returns true if actorRole can assign granteeRole.
// Owner can assign any role. Others can only assign roles strictly below their own.
func CanGrantRole(actorRole, granteeRole string) bool {
	if actorRole == RoleOwner {
		return true
	}
	return roleRank[actorRole] > roleRank[granteeRole]
}

// reservedSlugs is enforced at application layer before DB insert.
var reservedSlugs = map[string]struct{}{
	"api": {}, "admin": {}, "app": {}, "www": {}, "auth": {},
	"static": {}, "assets": {}, "login": {}, "signup": {}, "billing": {},
	"support": {}, "status": {}, "docs": {}, "help": {},
}

func IsReservedSlug(slug string) bool {
	_, ok := reservedSlugs[slug]
	return ok
}

// publicEmailDomains is a blocklist for org domain verification.
var publicEmailDomains = map[string]struct{}{
	"gmail.com": {}, "outlook.com": {}, "yahoo.com": {}, "hotmail.com": {},
	"icloud.com": {}, "protonmail.com": {}, "live.com": {}, "msn.com": {},
}

func IsPublicEmailDomain(domain string) bool {
	_, ok := publicEmailDomains[domain]
	return ok
}

// Domain types

type Org struct {
	ID                    string     `json:"id"`
	Slug                  string     `json:"slug"`
	Name                  string     `json:"name"`
	LogoURL               *string    `json:"logo_url"`
	Description           *string    `json:"description"`
	Status                string     `json:"status"`
	SeatLimit             *int       `json:"seat_limit"`
	ActiveMemberCount     int        `json:"active_member_count"`
	OnboardingStep        int        `json:"onboarding_step"`
	OnboardingCompletedAt *time.Time `json:"onboarding_completed_at"`
	ActivatedAt           *time.Time `json:"activated_at"`
	CreatedAt             time.Time  `json:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at"`
}

type OrgSummary struct {
	ID   string `json:"id"`
	Slug string `json:"slug"`
	Name string `json:"name"`
	Role string `json:"role"`
}

type Member struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	AvatarURL *string   `json:"avatar_url"`
	Role      string    `json:"role"`
	Status    string    `json:"status"`
	JoinedAt  time.Time `json:"joined_at"`
}

type MemberPage struct {
	Members    []Member `json:"members"`
	NextCursor string   `json:"next_cursor,omitempty"`
}

type Invite struct {
	ID          string     `json:"id"`
	OrgID       string     `json:"org_id"`
	Email       string     `json:"email"`
	Role        string     `json:"role"`
	InvitedByID string     `json:"invited_by"`
	ExpiresAt   time.Time  `json:"expires_at"`
	AcceptedAt  *time.Time `json:"accepted_at"`
	RevokedAt   *time.Time `json:"revoked_at"`
	CreatedAt   time.Time  `json:"created_at"`
}

type InvitePage struct {
	Invites    []Invite `json:"invites"`
	NextCursor string   `json:"next_cursor,omitempty"`
}

type Domain struct {
	ID                 string     `json:"id"`
	OrgID              string     `json:"org_id"`
	Domain             string     `json:"domain"`
	Verified           bool       `json:"verified"`
	VerificationMethod *string    `json:"verification_method"`
	VerificationToken  string     `json:"verification_token"`
	VerifiedAt         *time.Time `json:"verified_at"`
	AutoJoinEnabled    bool       `json:"auto_join_enabled"`
	CreatedAt          time.Time  `json:"created_at"`
}

type AuditLog struct {
	ID          string     `json:"id"`
	OrgID       string     `json:"org_id"`
	ActorUserID *string    `json:"actor_user_id"`
	Action      string     `json:"action"`
	TargetType  string     `json:"target_type"`
	TargetID    *string    `json:"target_id"`
	BeforeState *any       `json:"before_state"`
	AfterState  *any       `json:"after_state"`
	IPAddress   *string    `json:"ip_address"`
	CreatedAt   time.Time  `json:"created_at"`
}

type AuditLogPage struct {
	Logs       []AuditLog `json:"logs"`
	NextCursor string     `json:"next_cursor,omitempty"`
}

type OrgAuthConfig struct {
	OrgID          string   `json:"org_id"`
	SSOEnabled     bool     `json:"sso_enabled"`
	SSOProvider    *string  `json:"sso_provider"`
	PasswordPolicy any      `json:"password_policy"`
	AllowedDomains []string `json:"allowed_domains"`
}

type OnboardingState struct {
	Step                  int            `json:"step"`
	OnboardingCompletedAt *time.Time     `json:"onboarding_completed_at"`
	Org                   *Org           `json:"org"`
	AuthConfig            *OrgAuthConfig `json:"auth_config"`
}

// Request types

type CreateOrgRequest struct {
	Name        string  `json:"name"`
	Slug        string  `json:"slug"`
	Description *string `json:"description"`
	LogoURL     *string `json:"logo_url"`
}

type UpdateOrgRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	LogoURL     *string `json:"logo_url"`
	SeatLimit   *int    `json:"seat_limit"`
}

type CreateInviteRequest struct {
	Email string `json:"email"`
	Role  string `json:"role"`
}

type JoinOrgRequest struct {
	Token string `json:"token"`
}

type UpdateMemberRequest struct {
	Role   *string `json:"role"`
	Status *string `json:"status"`
}

type AddDomainRequest struct {
	Domain             string `json:"domain"`
	VerificationMethod string `json:"verification_method"`
}

type VerifyDomainRequest struct {
	DomainID string `json:"domain_id"`
	Token    string `json:"token"`
}

type SaveOnboardingRequest struct {
	// Step 1 — Identity
	Name        *string `json:"name"`
	Slug        *string `json:"slug"`
	Description *string `json:"description"`
	LogoURL     *string `json:"logo_url"`
	// Step 2 — Auth config
	AllowedDomains *[]string `json:"allowed_domains"`
	SSOEnabled     *bool     `json:"sso_enabled"`
	SSOProvider    *string   `json:"sso_provider"`
	// Step 3 — Plan
	SeatLimit *int `json:"seat_limit"`
	// Step 4 — Invites (handled via POST /invites, not stored here)
}

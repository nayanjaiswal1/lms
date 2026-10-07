package workspace

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// Handler exposes the workspace domain over HTTP. It owns the Service; every
// handler_*.go file adds methods to it. limiter/cfg are the same instances
// the Service holds — the public interest endpoint's per-IP/email/project
// rate limits are applied at the handler layer (contract-phase1.md), before
// the request ever reaches the service.
type Handler struct {
	service *Service
	limiter *ratelimit.Limiter
	cfg     *config.Config
	perms   PermissionChecker
}

// New builds the fully-wired workspace Handler from deps (built once in
// internal/api/router.go).
func New(d Deps) *Handler {
	return &Handler{service: NewService(d), limiter: d.Limiter, cfg: d.Cfg, perms: d.Perms}
}

// Service exposes the underlying Service — job handlers and router wiring
// (gitlabSvc.SetWorkItemLinker in a later phase) need it directly.
func (h *Handler) Service() *Service { return h.service }

// domainErrors maps sentinel errors to HTTP responses (contract-phase1.md's
// error mapping table). *FieldError and *RateLimitError carry per-call data
// (field messages, a wait duration) that a static map can't express, so
// writeDomainError checks those two first.
var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:         {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:        {Status: http.StatusForbidden, Message: "Your project role does not allow this action."},
	ErrConflict:         {Status: http.StatusConflict},
	ErrSeatsFull:        {Status: http.StatusConflict},
	ErrAlreadyReviewed:  {Status: http.StatusConflict},
	ErrKeyPrefixTaken:   {Status: http.StatusConflict},
	ErrKeyPrefixLocked:  {Status: http.StatusConflict},
	ErrInvalidState:     {Status: http.StatusConflict},
	ErrAlreadyMember:    {Status: http.StatusConflict},
	ErrOwnerCantLeave:   {Status: http.StatusConflict},
	ErrPreconditionFail: {Status: http.StatusConflict},
	ErrNotOrgMember:     {Status: http.StatusConflict, Message: "That user is not an active member of this organization."},
	ErrInvalidInput:     {Status: http.StatusBadRequest},

	// Phase 2 — work items (contract-phase2.md's error mapping table).
	ErrStaleVersion:         {Status: http.StatusConflict},
	ErrIllegalHierarchy:     {Status: http.StatusUnprocessableEntity},
	ErrIllegalTransition:    {Status: http.StatusConflict},
	ErrBlockedByOpen:        {Status: http.StatusConflict},
	ErrWipLimit:             {Status: http.StatusConflict},
	ErrLinkCycle:            {Status: http.StatusConflict},
	ErrSoD:                  {Status: http.StatusForbidden},
	ErrBriefNotAgreed:       {Status: http.StatusConflict},
	ErrDocNotApproved:       {Status: http.StatusConflict},
	ErrOnboardingIncomplete: {Status: http.StatusForbidden},
	ErrNotDeletable:         {Status: http.StatusConflict},
	ErrReasonRequired:       {Status: http.StatusUnprocessableEntity},
	ErrTrackLeaderless:      {Status: http.StatusConflict},

	// Phase 3 — clarification, brief, doc gate, triage, meetings
	// (contract-phase3.md's error mapping table).
	ErrStaleDocVersion:  {Status: http.StatusConflict},
	ErrNoReviewers:      {Status: http.StatusConflict},
	ErrBriefMissing:     {Status: http.StatusConflict},
	ErrQuestionAnswered: {Status: http.StatusConflict},
	ErrTooEarly:         {Status: http.StatusConflict},

	// Phase 4 — time logs (contract-phase4.md 4b).
	ErrTimeLogCap:    {Status: http.StatusConflict},
	ErrTimeLogLocked: {Status: http.StatusConflict},

	// Phase 5 — releases, sprints, completion, feedback (contract-phase5.md's
	// error mapping table).
	ErrReleaseFrozen:    {Status: http.StatusConflict},
	ErrReleaseNotReady:  {Status: http.StatusConflict},
	ErrSprintsDisabled:  {Status: http.StatusConflict},
	ErrSprintOverlap:    {Status: http.StatusConflict},
	ErrFeedbackClosed:   {Status: http.StatusConflict},
	ErrNoSharedWork:     {Status: http.StatusForbidden},
	ErrCompleteBlocked:  {Status: http.StatusConflict},
	ErrUnfinishedChoice: {Status: http.StatusUnprocessableEntity},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong. Please try again.",
	func(w http.ResponseWriter, err error) bool {
		var fe *FieldError
		if !errors.As(err, &fe) {
			return false
		}
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fe.Fields)
		return true
	},
	func(w http.ResponseWriter, err error) bool {
		var rl *RateLimitError
		if !errors.As(err, &rl) {
			return false
		}
		w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(rl.RetryAfter)))
		httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
		return true
	},
	// A stale-version PATCH/move/transition carries the current row so the
	// client can render "yours vs current" (D17) instead of just erroring.
	func(w http.ResponseWriter, err error) bool {
		var ce *ConflictError
		if !errors.As(err, &ce) {
			return false
		}
		httputil.WriteErrorWithData(w, http.StatusConflict, ErrStaleVersion.Error(), ce.Current)
		return true
	},
)

// maskShareToken clears p.ShareToken unless the caller is the owner or
// acting as one (overseer) — everyone else with viewer/member/manager access
// to GET the project must not see the credential-equivalent share link
// (models.go's own doc comment on Project.ShareToken).
func maskShareToken(p *Project, pc *ProjectCtx) {
	if pc.Role != RoleOwner && !pc.Overseer {
		p.ShareToken = ""
	}
}

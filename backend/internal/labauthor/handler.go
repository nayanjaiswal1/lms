package labauthor

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/labblock"
)

const (
	maxBodyBytes    = 1 << 20
	defaultPageSize = 100
	maxPageSize     = 200
	maxYankReason   = 500
)

// Handler serves the lab-authoring API (docs/debug-labs.md Part 2 §B5).
type Handler struct{ svc *Service }

// NewHandler returns a Handler over svc.
func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

func decodeBody(w http.ResponseWriter, r *http.Request, dst any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		httputil.WriteErrorCode(w, http.StatusBadRequest, CodeInvalidInput, "Invalid request body.")
		return false
	}
	return true
}

// pathID reads a UUID path parameter; a malformed one is a plain 404 (it can
// never match a row) rather than a database error.
func pathID(w http.ResponseWriter, r *http.Request, name string) (string, bool) {
	id := chi.URLParam(r, name)
	if _, err := uuid.Parse(id); err != nil {
		httputil.WriteErrorCode(w, http.StatusNotFound, CodeBlockNotFound, "Not found.")
		return "", false
	}
	return id, true
}

// writeErr maps domain errors to the envelope. A rejected recipe carries its
// issues in `data`; when every issue is a yanked block the code is block_yanked.
func writeErr(w http.ResponseWriter, err error) {
	var inv *InvalidRecipeError
	if errors.As(err, &inv) {
		code := CodeRecipeInvalid
		if allCode(inv.Analysis.Issues, labblock.CodeBlockYanked) {
			code = CodeBlockYanked
		}
		httputil.WriteErrorCodeWithData(w, http.StatusUnprocessableEntity, code, invalidMessage(inv.Analysis), inv.Analysis)
		return
	}
	if errors.Is(err, ErrRateLimited) {
		w.Header().Set("Retry-After", "60")
	}
	httputil.WriteDomainError(w, err, errSpecs, "Something went wrong.")
}

// WriteError maps a lab-authoring domain error (including a rejected recipe)
// to the API error envelope. Exported so the build pipeline's handlers report
// authoring errors identically.
func WriteError(w http.ResponseWriter, err error) { writeErr(w, err) }

// invalidMessage is the envelope message of a rejected recipe or block: the
// first error issue, so a form that shows only the message still says why.
func invalidMessage(a *Analysis) string {
	for _, i := range a.Issues {
		if i.Severity == labblock.SeverityError {
			return "The recipe is not valid: " + i.Message
		}
	}
	return "The recipe is not valid."
}

func allCode(issues []labblock.Issue, code string) bool {
	if len(issues) == 0 {
		return false
	}
	for _, i := range issues {
		if i.Code != code {
			return false
		}
	}
	return true
}

// ─── blocks ─────────────────────────────────────────────────────────────────

// HandleListBlocks: GET /api/instructor/lab-authoring/blocks?kind=&stack=&category=
func (h *Handler) HandleListBlocks(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	blocks, err := h.svc.repo.ListBlocks(r.Context(), claims.OrgID, BlockFilter{
		Kind: httputil.QueryStr(r, "kind"), Stack: httputil.QueryStr(r, "stack"), Category: httputil.QueryStr(r, "category"),
		Limit:  min(httputil.QueryIntPositive(r, "limit", defaultPageSize), maxPageSize),
		Offset: httputil.QueryIntNonNegative(r, "offset", 0),
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, blocks)
}

// HandleGetBlock: GET /api/instructor/lab-authoring/blocks/{id}
func (h *Handler) HandleGetBlock(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	d, err := h.svc.repo.GetBlock(r.Context(), claims.OrgID, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, d)
}

// HandleCreateBlock: POST /api/instructor/lab-authoring/blocks — an org-owned
// text block (ticket/hints/rubric/preset); body is the block manifest.
func (h *Handler) HandleCreateBlock(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var m labblock.Manifest
	if !decodeBody(w, r, &m) {
		return
	}
	blockID, versionID, err := h.svc.CreateTextBlock(r.Context(), claims.OrgID, claims.UserID, m)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"block_id": blockID, "version_id": versionID})
}

// HandleUpdateBlock: PUT /api/instructor/lab-authoring/blocks/{id} — appends a
// new immutable version (blocks are never edited in place).
func (h *Handler) HandleUpdateBlock(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	var m labblock.Manifest
	if !decodeBody(w, r, &m) {
		return
	}
	versionID, err := h.svc.UpdateTextBlock(r.Context(), claims.OrgID, claims.UserID, id, m)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"block_id": id, "version_id": versionID})
}

// HandleDeleteBlock: DELETE /api/instructor/lab-authoring/blocks/{id}
func (h *Handler) HandleDeleteBlock(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	if err := h.svc.DeleteTextBlock(r.Context(), claims.OrgID, id); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// HandleYankVersion: POST /api/admin/lab-authoring/blocks/{versionID}/yank
// (platform super_admin). Blocks new builds from the version; never touches
// live labs, and lists the ones built from it.
func (h *Handler) HandleYankVersion(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	id, ok := pathID(w, r, "versionID")
	if !ok {
		return
	}
	var body struct {
		Reason string `json:"reason"`
	}
	if !decodeBody(w, r, &body) {
		return
	}
	if body.Reason == "" || len(body.Reason) > maxYankReason {
		writeErr(w, ErrInvalidInput)
		return
	}
	labs, err := h.svc.repo.YankVersion(r.Context(), id, body.Reason)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"affected_labs": labs})
}

// HandleAffectedLabs: GET /api/admin/lab-authoring/blocks/{versionID}/affected-labs
// (platform super_admin) — the published labs built from a version, so the
// yank dialog can show its blast radius before it is confirmed.
func (h *Handler) HandleAffectedLabs(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	id, ok := pathID(w, r, "versionID")
	if !ok {
		return
	}
	labs, err := h.svc.repo.AffectedLabs(r.Context(), id)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"affected_labs": labs})
}

// ─── recipes ────────────────────────────────────────────────────────────────

// HandleListRecipes: GET /api/instructor/lab-authoring/recipes
func (h *Handler) HandleListRecipes(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	rs, err := h.svc.ListRecipes(r.Context(), claims.OrgID,
		min(httputil.QueryIntPositive(r, "limit", defaultPageSize), maxPageSize), httputil.QueryIntNonNegative(r, "offset", 0))
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rs)
}

// HandleCreateRecipe: POST /api/instructor/lab-authoring/recipes
func (h *Handler) HandleCreateRecipe(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var in RecipeInput
	if !decodeBody(w, r, &in) {
		return
	}
	rc, err := h.svc.CreateRecipe(r.Context(), claims.OrgID, claims.UserID, in)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, rc)
}

// HandleGetRecipe: GET /api/instructor/lab-authoring/recipes/{id} — the recipe,
// its pinned blocks, and "update available" info.
func (h *Handler) HandleGetRecipe(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	view, err := h.svc.GetRecipeView(r.Context(), claims.OrgID, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// HandleUpdateRecipe: PUT /api/instructor/lab-authoring/recipes/{id}
func (h *Handler) HandleUpdateRecipe(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	var in RecipeInput
	if !decodeBody(w, r, &in) {
		return
	}
	rc, err := h.svc.UpdateRecipe(r.Context(), claims.OrgID, id, in)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rc)
}

// HandleDeleteRecipe: DELETE /api/instructor/lab-authoring/recipes/{id}
func (h *Handler) HandleDeleteRecipe(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	if err := h.svc.repo.DeleteRecipe(r.Context(), claims.OrgID, id); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// HandleRecipeAnalysis: GET /api/instructor/lab-authoring/recipes/{id}/analysis
// — the validator's verdict on the saved recipe. Always 200; an invalid
// composition is a normal result with issues, not an HTTP error.
func (h *Handler) HandleRecipeAnalysis(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	a, err := h.svc.Validate(r.Context(), claims.OrgID, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, a)
}

// HandleRecipeCandidates: GET /api/instructor/lab-authoring/recipes/{id}/candidates?kind=fault
// — the blocks of one kind the builder wizard can add, with compatibility.
func (h *Handler) HandleRecipeCandidates(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	cs, err := h.svc.Candidates(r.Context(), claims.OrgID, id, httputil.QueryStr(r, "kind"))
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cs)
}

// HandleTicketDraft: POST /api/instructor/lab-authoring/recipes/{id}/ticket-draft
// {"persona": "..."} — AI-drafted ticket, cached per (recipe hash, persona).
func (h *Handler) HandleTicketDraft(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id, ok := pathID(w, r, "id")
	if !ok {
		return
	}
	var body struct {
		Persona string `json:"persona"`
	}
	if !decodeBody(w, r, &body) {
		return
	}
	d, err := h.svc.TicketDraft(r.Context(), claims.OrgID, claims.UserID, id, body.Persona)
	if err != nil {
		writeErr(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, d)
}

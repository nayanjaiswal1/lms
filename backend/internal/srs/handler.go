package srs

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the SRS domain over HTTP.
type Handler struct {
	repo *Repo
}

// NewHandler constructs the SRS handler from a connection pool.
func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{repo: NewRepo(pool)}
}

// ctxClaims pulls authenticated claims or writes 401 and returns false.
func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// writeDomainError maps domain errors to HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	if errors.Is(err, ErrNotFound) {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
}

// GetDueCards handles GET /api/srs/due.
// Returns up to 20 cards due for review today.
func (h *Handler) GetDueCards(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	cards, err := h.repo.GetDueCards(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, DueCardsResponse{Cards: cards, Total: len(cards)})
}

// ReviewCard handles POST /api/srs/review.
// Accepts a ReviewRequest, runs the SM-2 algorithm, persists the new schedule,
// and returns the updated ReviewResult.
func (h *Handler) ReviewCard(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req ReviewRequest
	if err := decodeJSON(w, r, &req); !err {
		return
	}
	if req.CardID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"card_id": "card_id is required.",
		})
		return
	}
	if req.Quality < 0 || req.Quality > 3 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"quality": "quality must be between 0 and 3.",
		})
		return
	}

	card, err := h.repo.GetCard(r.Context(), req.CardID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	newInterval, newReps, newEF := SM2(card.IntervalDays, card.Repetitions, card.EaseFactor, req.Quality)
	nextDue := time.Now().AddDate(0, 0, newInterval).Format("2006-01-02")

	if err := h.repo.UpdateCardAfterReview(r.Context(), card.ID, newInterval, newReps, newEF, nextDue); err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, ReviewResult{
		NextDue:      nextDue,
		IntervalDays: newInterval,
		EaseFactor:   newEF,
	})
}

// CreateCard handles POST /api/srs/cards.
// Allows a student to create a card manually.
func (h *Handler) CreateCard(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CreateCardRequest
	if err := decodeJSON(w, r, &req); !err {
		return
	}
	if req.Front == "" || req.Back == "" {
		fields := map[string]string{}
		if req.Front == "" {
			fields["front"] = "front is required."
		}
		if req.Back == "" {
			fields["back"] = "back is required."
		}
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	if req.SourceType == "" {
		req.SourceType = "manual"
	}

	card, err := h.repo.CreateCard(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, card)
}

// decodeJSON decodes r.Body into dst. Writes 400 and returns false on error.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

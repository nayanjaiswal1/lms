package coupons

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Coupon not found.")
	case errors.Is(err, ErrInvalid):
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

type couponResponse struct {
	ID             string     `json:"id"`
	Code           string     `json:"code"`
	Description    string     `json:"description"`
	DiscountType   string     `json:"discount_type"`
	DiscountValue  int        `json:"discount_value"`
	CourseID       *string    `json:"course_id,omitempty"`
	MaxRedemptions *int       `json:"max_redemptions,omitempty"`
	RedeemedCount  int        `json:"redeemed_count"`
	StartsAt       *time.Time `json:"starts_at,omitempty"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
	IsActive       bool       `json:"is_active"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

func toCouponResponse(c Coupon) couponResponse {
	return couponResponse{
		ID: c.ID, Code: c.Code, Description: c.Description,
		DiscountType: c.DiscountType, DiscountValue: c.DiscountValue,
		CourseID: c.CourseID, MaxRedemptions: c.MaxRedemptions, RedeemedCount: c.RedeemedCount,
		StartsAt: c.StartsAt, ExpiresAt: c.ExpiresAt, IsActive: c.IsActive,
		CreatedAt: c.CreatedAt, UpdatedAt: c.UpdatedAt,
	}
}

type createCouponRequest struct {
	Code           string     `json:"code"`
	Description    string     `json:"description"`
	DiscountType   string     `json:"discount_type"`
	DiscountValue  int        `json:"discount_value"`
	CourseID       *string    `json:"course_id"`
	MaxRedemptions *int       `json:"max_redemptions"`
	StartsAt       *time.Time `json:"starts_at"`
	ExpiresAt      *time.Time `json:"expires_at"`
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req createCouponRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	createdBy := claims.UserID
	c, err := h.service.Create(r.Context(), Coupon{
		OrgID: claims.OrgID, Code: req.Code, Description: req.Description,
		DiscountType: req.DiscountType, DiscountValue: req.DiscountValue,
		CourseID: req.CourseID, MaxRedemptions: req.MaxRedemptions,
		StartsAt: req.StartsAt, ExpiresAt: req.ExpiresAt, CreatedBy: &createdBy,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, toCouponResponse(c))
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	includeInactive := r.URL.Query().Get("include_inactive") == "true"
	list, err := h.service.List(r.Context(), claims.OrgID, includeInactive)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	out := make([]couponResponse, len(list))
	for i, c := range list {
		out[i] = toCouponResponse(c)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"coupons": out})
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	c, err := h.service.Get(r.Context(), claims.OrgID, chi.URLParam(r, "couponID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toCouponResponse(c))
}

type updateCouponRequest struct {
	Description    string     `json:"description"`
	IsActive       bool       `json:"is_active"`
	ExpiresAt      *time.Time `json:"expires_at"`
	MaxRedemptions *int       `json:"max_redemptions"`
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req updateCouponRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.Update(r.Context(), claims.OrgID, chi.URLParam(r, "couponID"),
		req.Description, req.IsActive, req.ExpiresAt, req.MaxRedemptions)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toCouponResponse(c))
}

func (h *Handler) Deactivate(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.Deactivate(r.Context(), claims.OrgID, chi.URLParam(r, "couponID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "deactivated"})
}

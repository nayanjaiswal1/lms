package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func seedSession(t *testing.T, pool *pgxpool.Pool, userID, device string) (familyID, rawToken string) {
	t.Helper()
	raw, hash, err := CreateRefreshToken()
	if err != nil {
		t.Fatalf("CreateRefreshToken: %v", err)
	}
	familyID = uuid.NewString()
	if _, err := pool.Exec(context.Background(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 VALUES ($1, $2, now() + interval '1 day', $3, $4, '10.0.0')`,
		userID, hash, familyID, device,
	); err != nil {
		t.Fatalf("seed refresh token: %v", err)
	}
	return familyID, raw
}

func sessionReq(t *testing.T, method, id, userID, cookie string) *http.Request {
	t.Helper()
	req := httptest.NewRequest(method, "/api/auth/sessions", nil)
	if cookie != "" {
		req.AddCookie(&http.Cookie{Name: "refresh_token", Value: cookie})
	}
	rc := chi.NewRouteContext()
	rc.URLParams.Add("id", id)
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, rc)
	return req.WithContext(SetClaims(ctx, &Claims{UserID: userID}))
}

func listSessions(t *testing.T, h *Handler, userID, cookie string) []sessionResponse {
	t.Helper()
	rec := httptest.NewRecorder()
	h.HandleSessionsList(rec, sessionReq(t, http.MethodGet, "", userID, cookie))
	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d: %s", rec.Code, rec.Body)
	}
	var body struct {
		Data struct {
			Sessions []sessionResponse `json:"sessions"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	return body.Data.Sessions
}

func TestSessionsListAndRevoke(t *testing.T) {
	pool := testdb.New(t)
	h := &Handler{pool: pool}
	ctx := context.Background()

	var me, other string
	for i, dst := range []*string{&me, &other} {
		if err := pool.QueryRow(ctx,
			`INSERT INTO users (email, name) VALUES ($1, 'U') RETURNING id`,
			[]string{"sess-me@", "sess-other@"}[i]+testdomain.Domain,
		).Scan(dst); err != nil {
			t.Fatalf("seed user: %v", err)
		}
	}
	phone, _ := seedSession(t, pool, me, "phone")
	laptop, laptopCookie := seedSession(t, pool, me, "laptop")
	theirs, _ := seedSession(t, pool, other, "theirs")

	got := listSessions(t, h, me, laptopCookie)
	if len(got) != 2 {
		t.Fatalf("want 2 sessions, got %d", len(got))
	}
	for _, s := range got {
		if s.Current != (s.ID == laptop) {
			t.Errorf("session %s current=%v, want %v", s.ID, s.Current, s.ID == laptop)
		}
	}

	revoke := func(id string) int {
		rec := httptest.NewRecorder()
		h.HandleSessionRevoke(rec, sessionReq(t, http.MethodDelete, id, me, laptopCookie))
		return rec.Code
	}
	if code := revoke(theirs); code != http.StatusNotFound {
		t.Errorf("revoking another user's session = %d, want 404", code)
	}
	if code := revoke("not-a-uuid"); code != http.StatusNotFound {
		t.Errorf("revoking malformed id = %d, want 404", code)
	}
	if code := revoke(phone); code != http.StatusOK {
		t.Fatalf("revoking own session = %d, want 200", code)
	}
	if code := revoke(phone); code != http.StatusNotFound {
		t.Errorf("revoking twice = %d, want 404", code)
	}

	got = listSessions(t, h, me, laptopCookie)
	if len(got) != 1 || got[0].ID != laptop {
		t.Fatalf("after revoke want only laptop, got %+v", got)
	}
}

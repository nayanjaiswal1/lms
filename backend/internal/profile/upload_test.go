package profile

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/auth"
)

// An avatar body larger than the cap must be refused before the service (nil
// here, so any write would panic) is reached.
//
// The MaxBytesReader failure must surface as 413 "Avatar must be under 5 MB.".
func TestHandleUploadAvatarRejectsOversizedBody(t *testing.T) {
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	part, err := mw.CreateFormFile("avatar", "big.png")
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := part.Write(make([]byte, maxAvatarBytes+2048)); err != nil {
		t.Fatalf("write part: %v", err)
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("close writer: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/profile/me/avatar", &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: "u1"}))
	rec := httptest.NewRecorder()

	(&Handler{}).HandleUploadAvatar(rec, req)

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413 for an over-limit body; body=%s", rec.Code, rec.Body.String())
	}
}

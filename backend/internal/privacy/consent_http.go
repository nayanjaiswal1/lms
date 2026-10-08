package privacy

import (
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// EnforceAIConsent writes a 403 carrying deniedMessage, or a 500 when consent
// cannot be read, and returns false unless userID has opted in to AI processing.
func EnforceAIConsent(w http.ResponseWriter, r *http.Request, q rowQuerier, userID, deniedMessage string) bool {
	err := RequireAIConsent(r.Context(), q, userID)
	if err == nil {
		return true
	}
	if errors.Is(err, ErrAIConsentRequired) {
		httputil.WriteError(w, http.StatusForbidden, deniedMessage)
	} else {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not verify your AI consent.")
	}
	return false
}

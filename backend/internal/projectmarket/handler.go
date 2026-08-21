package projectmarket

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the projectmarket domain over HTTP. It owns the service.
type Handler struct {
	service *Service
}

// NewHandler builds the projectmarket HTTP handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// writeDomainError maps domain/service errors to HTTP responses.
var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:               {Status: http.StatusNotFound, Message: "Not found."},
	ErrConflict:               {Status: http.StatusConflict, Message: "This action conflicts with the current state."},
	ErrRequirementClosed:      {Status: http.StatusConflict, Message: "This requirement is not accepting applications."},
	ErrAlreadyApplied:         {Status: http.StatusConflict, Message: "You have already applied to this requirement."},
	ErrAIUnavailable:          {Status: http.StatusServiceUnavailable, Message: "AI scoring is not available right now."},
	ErrNoSelectedApplications: {Status: http.StatusConflict, Message: "No applications are marked selected yet."},
	ErrTooManySelected:        {Status: http.StatusConflict, Message: "More applications are selected than this requirement's team size allows."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong. Please try again.")
}

// Length caps on user-submitted free text — cheap to enforce at the
// boundary, expensive to retrofit once a giant paste has already inflated
// storage and (for motivation/resume_text) every future AI scoring prompt's
// token cost. Chosen generously (a resume is realistically a few thousand
// characters; these caps are an abuse ceiling, not a normal-use limit).
const (
	maxTitleLen       = 200
	maxBriefLen       = 5000
	maxMotivationLen  = 3000
	maxResumeLen      = 20000
	maxDescriptionLen = 3000
	maxLinkLen        = 500
	maxRequiredSkills = 30
)

func validateRequirementRequest(req *requirementRequest) map[string]string {
	fields := map[string]string{}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "A title is required."
	} else if len(req.Title) > maxTitleLen {
		fields["title"] = fmt.Sprintf("Title must be %d characters or fewer.", maxTitleLen)
	}
	if strings.TrimSpace(req.Brief) == "" {
		fields["brief"] = "A brief is required."
	} else if len(req.Brief) > maxBriefLen {
		fields["brief"] = fmt.Sprintf("Brief must be %d characters or fewer.", maxBriefLen)
	}
	if req.TeamSizeMin < 1 {
		fields["team_size_min"] = "Team size must be at least 1."
	}
	if req.TeamSizeMax < req.TeamSizeMin {
		fields["team_size_max"] = "Max team size must be at least the min team size."
	}
	if len(req.RequiredSkills) > maxRequiredSkills {
		fields["required_skills"] = fmt.Sprintf("List at most %d skills.", maxRequiredSkills)
	}
	if req.ApplicationDeadline.IsZero() {
		fields["application_deadline"] = "An application deadline is required."
	}
	return fields
}

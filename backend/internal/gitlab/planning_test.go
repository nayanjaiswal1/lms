package gitlab

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPlanningFixturesServeValidEnvelope(t *testing.T) {
	h := &Handler{}
	for name, fn := range map[string]http.HandlerFunc{"board": h.PlanningBoard, "issues": h.PlanningIssues} {
		rec := httptest.NewRecorder()
		fn(rec, httptest.NewRequest(http.MethodGet, "/", nil))
		var body struct {
			Data map[string]json.RawMessage `json:"data"`
		}
		if rec.Code != http.StatusOK || json.Unmarshal(rec.Body.Bytes(), &body) != nil || len(body.Data) == 0 {
			t.Fatalf("%s: status %d body %s", name, rec.Code, rec.Body.String())
		}
	}
}

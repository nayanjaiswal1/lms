package rewards

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/auth"
)

// rankFailHook serves a one-row leaderboard page and fails ZREVRANK, so only
// the caller's own rank lookup errors. No network connection is ever made.
type rankFailHook struct{}

func (rankFailHook) DialHook(next redis.DialHook) redis.DialHook { return next }
func (rankFailHook) ProcessPipelineHook(next redis.ProcessPipelineHook) redis.ProcessPipelineHook {
	return next
}
func (rankFailHook) ProcessHook(redis.ProcessHook) redis.ProcessHook {
	return func(_ context.Context, cmd redis.Cmder) error {
		switch c := cmd.(type) {
		case *redis.ZSliceCmd:
			c.SetVal([]redis.Z{{Member: "other-user", Score: 50}})
		case *redis.MapStringStringCmd:
			c.SetVal(map[string]string{"name": "Other"})
		case *redis.IntCmd:
			if c.Name() == "zrevrank" {
				return errors.New("redis unavailable")
			}
		}
		return nil
	}
}

func TestGetLeaderboard_RankLookupErrorReturns500(t *testing.T) {
	rdb := redis.NewClient(&redis.Options{Dialer: func(context.Context, string, string) (net.Conn, error) {
		return nil, errors.New("no network in unit test")
	}})
	t.Cleanup(func() { rdb.Close() })
	rdb.AddHook(rankFailHook{})
	h := NewHandler(NewService(NewRepo(nil, rdb)))

	req := httptest.NewRequest(http.MethodGet, "/api/rewards/leaderboard?scope=global", nil)
	req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: "me", OrgID: "org-1"}))
	rec := httptest.NewRecorder()
	h.GetLeaderboard(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500; body=%s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), `"rank"`) {
		t.Fatalf("rank must not be reported on lookup failure: %s", rec.Body.String())
	}
}

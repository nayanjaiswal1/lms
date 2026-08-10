package gitlab

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/netguard"
)

// Client is a GitLab REST API client. Batch 1 built the minimal surface
// needed to verify a token and read instance metadata for tier detection;
// Batch 2 adds client_groups.go/client_projects.go/client_members.go
// alongside this file for group/fork/branch-protection/membership work
// rather than growing this file into one large surface, mirroring how
// internal/assessment splits its own repo/handler files by concern.
type Client struct {
	baseURL string
	token   string
	http    *http.Client
}

// NewClient builds a Client for baseURL authorized with the given bearer
// token (a PAT or an OAuth access token — GitLab accepts both identically).
//
// The transport's DialContext re-checks the IP actually being connected to
// against netguard's denylist on every dial, not just once at config-save
// time in validateBaseURL. That handler-time check can't fully close the
// SSRF gap on its own: the admin-configured hostname's DNS can change
// between validation and any later request this client makes (DNS
// rebinding), so the real guard has to sit at the point of connection.
func NewClient(baseURL, token string) *Client {
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		token:   token,
		http: &http.Client{
			Timeout:   15 * time.Second,
			Transport: guardedTransport(),
		},
	}
}

// guardedTransport returns an http.Transport whose DialContext rejects any
// address that resolves to a denylisted IP (see internal/netguard) before
// the connection is made — the dial-time half of this app's SSRF defense.
func guardedTransport() *http.Transport {
	dialer := &net.Dialer{Timeout: 15 * time.Second}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, fmt.Errorf("gitlab: parse dial address %q: %w", addr, err)
		}
		if ip := net.ParseIP(host); ip != nil {
			if netguard.IsDenylisted(ip) {
				return nil, fmt.Errorf("gitlab: refusing to dial denylisted address %s", host)
			}
			return dialer.DialContext(ctx, network, addr)
		}
		// addr's host is still a hostname (net/http resolves via DialContext
		// itself rather than pre-resolving) — resolve it here so every IP it
		// could connect to is checked, then dial that specific IP directly
		// rather than re-resolving (which could yield a different, unchecked
		// answer under DNS rebinding).
		ips, err := net.DefaultResolver.LookupIP(ctx, "ip", host)
		if err != nil {
			return nil, fmt.Errorf("gitlab: resolve %q: %w", host, err)
		}
		for _, ip := range ips {
			if netguard.IsDenylisted(ip) {
				continue
			}
			conn, dialErr := dialer.DialContext(ctx, network, net.JoinHostPort(ip.String(), port))
			if dialErr == nil {
				return conn, nil
			}
			err = dialErr
		}
		if err == nil {
			err = fmt.Errorf("gitlab: all resolved addresses for %q are denylisted", host)
		}
		return nil, fmt.Errorf("gitlab: dial %q: %w", host, err)
	}
	return transport
}

// APIError is returned for any non-2xx GitLab API response. RetryAfter is
// populated from the response's Retry-After header when present (GitLab sets
// it on 429s); zero when absent or not a 429.
type APIError struct {
	StatusCode int
	Message    string
	RetryAfter time.Duration
}

func (e *APIError) Error() string {
	return fmt.Sprintf("gitlab api: status %d: %s", e.StatusCode, e.Message)
}

// maxRetries bounds the 429 backoff-and-retry loop in do() — a small, fixed
// cap rather than unbounded retry, since a caller (an HTTP request handler or
// a job with its own timeout) needs do() to eventually give up and surface
// the error rather than hang.
const maxRetries = 3

// do issues a request, retrying 429s with backoff, and decodes a JSON
// response into out (which may be nil for endpoints with no useful body,
// e.g. member add/remove). reqBody is the raw request body (nil for GET/
// DELETE and any POST/PUT that only needs query-string parameters) — pass
// it via doJSON when the caller has a Go value to encode instead.
func (c *Client) do(ctx context.Context, method, path string, reqBody []byte, out any) error {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return fmt.Errorf("gitlab: request %s %s: %w", method, path, ctx.Err())
			case <-time.After(retryAfterDelay(lastErr, attempt)):
			}
		}

		resp, body, err := c.doOnce(ctx, method, path, reqBody)
		if err != nil {
			return err
		}

		if resp.StatusCode == http.StatusTooManyRequests && attempt < maxRetries {
			lastErr = &APIError{StatusCode: resp.StatusCode, Message: strings.TrimSpace(string(body)), RetryAfter: parseRetryAfter(resp.Header.Get("Retry-After"))}
			continue
		}
		if resp.StatusCode >= 300 {
			return &APIError{StatusCode: resp.StatusCode, Message: strings.TrimSpace(string(body)), RetryAfter: parseRetryAfter(resp.Header.Get("Retry-After"))}
		}
		if out == nil || len(body) == 0 {
			return nil
		}
		if err := json.Unmarshal(body, out); err != nil {
			return fmt.Errorf("gitlab: decode response %s %s: %w", method, path, err)
		}
		return nil
	}
	return lastErr
}

func (c *Client) doOnce(ctx context.Context, method, path string, reqBody []byte) (*http.Response, []byte, error) {
	var reader io.Reader
	if reqBody != nil {
		reader = bytes.NewReader(reqBody)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+"/api/v4"+path, reader)
	if err != nil {
		return nil, nil, fmt.Errorf("gitlab: build request %s %s: %w", method, path, err)
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Accept", "application/json")
	if reqBody != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("gitlab: request %s %s: %w", method, path, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, nil, fmt.Errorf("gitlab: read response body %s %s: %w", method, path, err)
	}
	return resp, body, nil
}

// retryAfterDelay honors the prior response's Retry-After seconds if GitLab
// sent one, else falls back to a short fixed backoff scaled by attempt
// number. GitLab's own rate-limit docs recommend obeying Retry-After when
// present rather than a fixed exponential curve.
func retryAfterDelay(lastErr error, attempt int) time.Duration {
	var apiErr *APIError
	if ae, ok := lastErr.(*APIError); ok {
		apiErr = ae
	}
	if apiErr != nil && apiErr.RetryAfter > 0 {
		return apiErr.RetryAfter
	}
	return time.Duration(attempt) * 500 * time.Millisecond
}

func parseRetryAfter(header string) time.Duration {
	if header == "" {
		return 0
	}
	if secs, err := strconv.Atoi(strings.TrimSpace(header)); err == nil && secs > 0 {
		return time.Duration(secs) * time.Second
	}
	return 0
}

// GitlabUser is the subset of GET /user this package needs to verify a token
// and record the identity it belongs to.
type GitlabUser struct {
	ID        int64  `json:"id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	AvatarURL string `json:"avatar_url"`
}

// VerifyUser calls GET /user — confirms the token is valid and returns the
// GitLab identity it belongs to. Used for both installation PAT/OAuth setup
// and per-user connect, and by the /verify and token-refresh flows to
// re-confirm a stored token still works.
func (c *Client) VerifyUser(ctx context.Context) (*GitlabUser, error) {
	var u GitlabUser
	if err := c.do(ctx, http.MethodGet, "/user", nil, &u); err != nil {
		return nil, fmt.Errorf("gitlab: verify user: %w", err)
	}
	return &u, nil
}

// InstanceMetadata is the subset of GET /metadata used for installation tier
// detection.
type InstanceMetadata struct {
	Version    string `json:"version"`
	Enterprise bool   `json:"enterprise"`
}

// GitlabLicense is the subset of GET /license (admin-only) this package uses
// to split Premium from Ultimate. Plan is GitLab's own tier name for the
// active license ("ultimate", "premium", or an older/unrecognized value).
type GitlabLicense struct {
	Plan string `json:"plan"`
}

// DetectTier calls GET /metadata and maps the response to this app's coarse
// tier field. When the instance reports "enterprise" — GitLab's /metadata
// can't tell Premium from Ultimate, it only proves "not Free" — DetectTier
// then attempts an admin-scoped GET /license call to read the actual plan.
// Most installation tokens are not admin-scoped, so a 403/404 (or any other
// error, or an unrecognized plan value) from /license is expected, not
// fatal: that's a capability gap (finer detection unavailable for this
// token), not a tier-detection failure, so it falls back to the coarser
// "premium" collapse instead of erroring out.
func (c *Client) DetectTier(ctx context.Context) (string, error) {
	var meta InstanceMetadata
	if err := c.do(ctx, http.MethodGet, "/metadata", nil, &meta); err != nil {
		return "", fmt.Errorf("gitlab: detect tier: %w", err)
	}
	if !meta.Enterprise {
		return TierFree, nil
	}
	if tier, ok := c.detectEnterpriseTier(ctx); ok {
		return tier, nil
	}
	return TierPremium, nil
}

// detectEnterpriseTier attempts the admin-scoped GET /license call that can
// distinguish Premium from Ultimate. ok is false whenever the call didn't
// yield a usable tier — missing admin scope (403), license endpoint absent
// (404), or any other transport/API error — in which case the caller falls
// back to the "premium" collapse.
func (c *Client) detectEnterpriseTier(ctx context.Context) (tier string, ok bool) {
	var lic GitlabLicense
	if err := c.do(ctx, http.MethodGet, "/license", nil, &lic); err != nil {
		return "", false
	}
	return planToTier(lic.Plan)
}

// planToTier maps GET /license's "plan" field to this app's tier constants.
// ok is false for a plan value this app doesn't recognize, in which case the
// caller falls back to the "premium" collapse rather than trusting an
// unrecognized string.
func planToTier(plan string) (tier string, ok bool) {
	switch strings.ToLower(strings.TrimSpace(plan)) {
	case "ultimate":
		return TierUltimate, true
	case "premium":
		return TierPremium, true
	default:
		return "", false
	}
}

// doJSON is do() with payload marshaled to JSON — the common case for
// POST/PUT calls whose parameters are more naturally expressed as a Go
// struct than a query string (e.g. CreateGroup, UpdateProject).
func (c *Client) doJSON(ctx context.Context, method, path string, payload any, out any) error {
	var body []byte
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return fmt.Errorf("gitlab: encode request body %s %s: %w", method, path, err)
		}
		body = b
	}
	return c.do(ctx, method, path, body, out)
}

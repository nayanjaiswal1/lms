package auth

import (
	"bufio"
	"context"
	"crypto/sha1" //nolint:gosec // not used as a security primitive; the range API's index is defined in terms of SHA-1
	"encoding/hex"
	"log/slog"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// Password policy.
//
// Deliberately NOT composition rules ("one uppercase, one digit, one symbol").
// NIST SP 800-63B advises against them: they push people toward predictable
// mutations like "Password1!" while blocking strong passphrases, and they make
// the guessable set smaller, not larger. What the guidance asks for instead is
// a length floor and a check against passwords already known to be breached —
// which is what this file implements.
//
// Two checks run, in cost order:
//
//  1. Context terms — a password that is the account's own email or name is
//     the first thing an attacker tries, and costs nothing to reject locally.
//  2. Breach corpus — a k-anonymity range lookup, so the password itself never
//     leaves this process (see checkBreachCorpus).

// PasswordRejection explains why a password was refused. A nil result means the
// password is acceptable.
type PasswordRejection struct{ Reason string }

// ValidatePassword applies the full policy. context holds account-identifying
// strings (email, name) that the password must not simply repeat; any may be
// empty.
//
// Length is validated by the caller alongside its other field errors, so it is
// not repeated here.
func ValidatePassword(ctx context.Context, cfg *config.Config, password string, contextTerms ...string) *PasswordRejection {
	if r := checkContextTerms(password, contextTerms...); r != nil {
		return r
	}
	return checkBreachCorpus(ctx, cfg, password)
}

// checkContextTerms rejects a password that is one of the account's own
// identifying strings, or the local part of its email address.
func checkContextTerms(password string, terms ...string) *PasswordRejection {
	lowered := strings.ToLower(strings.TrimSpace(password))
	if lowered == "" {
		return nil
	}

	for _, term := range terms {
		term = strings.ToLower(strings.TrimSpace(term))
		if term == "" {
			continue
		}
		if lowered == term {
			return &PasswordRejection{Reason: "Your password must not be your name or email address."}
		}
		// The local part on its own is just as guessable as the full address.
		if local, _, found := strings.Cut(term, "@"); found && local != "" && lowered == local {
			return &PasswordRejection{Reason: "Your password must not be your name or email address."}
		}
	}
	return nil
}

// checkBreachCorpus asks the Pwned Passwords range API whether this password
// appears in a known breach corpus.
//
// The password is never transmitted. Its SHA-1 is computed locally and only the
// first five hex characters of the digest are sent; the service replies with
// every suffix sharing that prefix (~800 of them) and the match is decided here.
// SHA-1 is not doing security work — it is the index the API is defined in terms
// of. Stored password hashing remains bcrypt.
//
// Fails OPEN. If the service is unreachable, slow, or returns an error, the
// password is accepted and the failure is logged. Refusing registrations and
// password resets because a third-party API is down trades a real outage for a
// speculative risk; the breach check is a strengthening measure layered on top
// of bcrypt, rate limiting, and the length floor, not a load-bearing control.
func checkBreachCorpus(ctx context.Context, cfg *config.Config, password string) *PasswordRejection {
	if !cfg.PasswordBreachCheckEnabled {
		return nil
	}

	sum := sha1.Sum([]byte(password)) //nolint:gosec // see doc comment
	digest := strings.ToUpper(hex.EncodeToString(sum[:]))
	prefix, suffix := digest[:5], digest[5:]

	reqCtx, cancel := context.WithTimeout(ctx, cfg.PasswordBreachTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, cfg.PasswordBreachAPIURL+prefix, nil)
	if err != nil {
		slog.Error("auth: password breach check request", "error", err)
		return nil
	}
	// The API requires a descriptive User-Agent and rejects requests without one.
	req.Header.Set("User-Agent", "MindForge-Auth")
	req.Header.Set("Add-Padding", "true") // uniform response size; hides the prefix from a network observer

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		slog.Warn("auth: password breach check unavailable — allowing password", "error", err)
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		slog.Warn("auth: password breach check non-200 — allowing password", "status", resp.StatusCode)
		return nil
	}

	// Each line is "SUFFIX:COUNT". Padding entries carry a count of 0 and must
	// not be treated as hits.
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		lineSuffix, count, found := strings.Cut(line, ":")
		if !found || !strings.EqualFold(strings.TrimSpace(lineSuffix), suffix) {
			continue
		}
		if strings.TrimSpace(count) == "0" {
			continue
		}
		return &PasswordRejection{
			Reason: "This password has appeared in a public data breach. Please choose a different one.",
		}
	}
	if err := scanner.Err(); err != nil {
		slog.Warn("auth: password breach check read failed — allowing password", "error", err)
	}
	return nil
}

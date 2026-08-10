package main

import (
	"net"
	"strconv"
	"strings"

	"github.com/google/uuid"
)

// splitPreviewHost parses a preview subdomain of the form
// "p<port>-<sessionID>.<suffix>" — e.g.
// "p3000-9f1c2a44-3e7b-4a91-b0d2-8c5e17ad9f10.labs.example.com" with
// suffix="labs.example.com" — into its port and session ID. suffix is
// LABPROXY_PREVIEW_DOMAIN; the caller lowercases nothing for it, so pass it
// as configured (this function lowercases both sides before comparing).
//
// ok is false for anything that isn't exactly one label ahead of suffix —
// including a host with an extra label (e.g. "8080.uuid.suffix", which is
// two labels: "8080" and "uuid") — because a single wildcard cert
// ("*.suffix") can only ever cover one dynamic label; see Caddyfile and
// k8s/base/gateway.yaml.
func splitPreviewHost(host, suffix string) (port int, sessionID string, ok bool) {
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	host = strings.ToLower(host)
	suffix = strings.ToLower(suffix)

	dotSuffix := "." + suffix
	if suffix == "" || !strings.HasSuffix(host, dotSuffix) {
		return 0, "", false
	}
	label := strings.TrimSuffix(host, dotSuffix)
	if label == "" || strings.Contains(label, ".") {
		return 0, "", false
	}
	if !strings.HasPrefix(label, "p") {
		return 0, "", false
	}

	portStr, idStr, found := strings.Cut(label[1:], "-")
	if !found {
		return 0, "", false
	}
	p, err := strconv.Atoi(portStr)
	if err != nil || !validPreviewPort(p) {
		return 0, "", false
	}
	id, err := uuid.Parse(idStr)
	if err != nil {
		return 0, "", false
	}
	return p, id.String(), true
}

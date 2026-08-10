package main

import "testing"

func TestSplitEntryPort(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		wantPort int
		wantPath string
	}{
		{"explicit port with path", "3000/index.html", 3000, "index.html"},
		{"explicit port bare", "8080/", 8080, ""},
		{"no port segment", "static/app.css", 0, "static/app.css"},
		{"empty path", "", 0, ""},
		{"non-numeric segment", "app2/main.js", 0, "app2/main.js"},
		{"digits-only single segment is a port", "5173", 5173, ""},
		{"zero rejected as port", "0/app.css", 0, "0/app.css"},
		{"negative not parsed as port", "-1/x", 0, "-1/x"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			port, path := splitEntryPort(tt.path)
			if port != tt.wantPort || path != tt.wantPath {
				t.Errorf("splitEntryPort(%q) = (%d, %q), want (%d, %q)",
					tt.path, port, path, tt.wantPort, tt.wantPath)
			}
		})
	}
}

func TestSplitPreviewHost(t *testing.T) {
	const suffix = "labs.example.com"
	const uuidStr = "9f1c2a44-3e7b-4a91-b0d2-8c5e17ad9f10"

	tests := []struct {
		name     string
		host     string
		wantPort int
		wantID   string
		wantOK   bool
	}{
		{
			name:     "valid",
			host:     "p3000-" + uuidStr + "." + suffix,
			wantPort: 3000,
			wantID:   uuidStr,
			wantOK:   true,
		},
		{
			name:   "wrong suffix",
			host:   "p3000-" + uuidStr + ".other.com",
			wantOK: false,
		},
		{
			name:   "two labels before suffix rejected",
			host:   "8080." + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:   "missing p prefix",
			host:   "3000-" + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:   "malformed uuid",
			host:   "p3000-not-a-uuid." + suffix,
			wantOK: false,
		},
		{
			name:   "no dash separator",
			host:   "p3000" + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:   "invalid port — zero",
			host:   "p0-" + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:   "invalid port — above range",
			host:   "p65536-" + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:   "invalid port — ttyd port rejected",
			host:   "p7681-" + uuidStr + "." + suffix,
			wantOK: false,
		},
		{
			name:     "boundary port 1",
			host:     "p1-" + uuidStr + "." + suffix,
			wantPort: 1,
			wantID:   uuidStr,
			wantOK:   true,
		},
		{
			name:     "boundary port 65535",
			host:     "p65535-" + uuidStr + "." + suffix,
			wantPort: 65535,
			wantID:   uuidStr,
			wantOK:   true,
		},
		{
			name:     "uppercase host header",
			host:     "P3000-" + uuidStr + "." + suffix,
			wantPort: 3000,
			wantID:   uuidStr,
			wantOK:   true,
		},
		{
			name:     "host with explicit port 443",
			host:     "p3000-" + uuidStr + "." + suffix + ":443",
			wantPort: 3000,
			wantID:   uuidStr,
			wantOK:   true,
		},
		{
			name:   "empty host",
			host:   "",
			wantOK: false,
		},
		{
			name:   "bare suffix, no label",
			host:   suffix,
			wantOK: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			port, sessionID, ok := splitPreviewHost(tt.host, suffix)
			if ok != tt.wantOK {
				t.Fatalf("splitPreviewHost(%q, %q) ok = %v, want %v", tt.host, suffix, ok, tt.wantOK)
			}
			if !tt.wantOK {
				return
			}
			if port != tt.wantPort {
				t.Errorf("splitPreviewHost(%q, %q) port = %d, want %d", tt.host, suffix, port, tt.wantPort)
			}
			if sessionID != tt.wantID {
				t.Errorf("splitPreviewHost(%q, %q) sessionID = %q, want %q", tt.host, suffix, sessionID, tt.wantID)
			}
		})
	}
}

func TestShouldWrapJSONDocument(t *testing.T) {
	tests := []struct {
		name        string
		isDocRoot   bool
		contentType string
		status      int
		want        bool
	}{
		{"json document root wrapped", true, "application/json", 200, true},
		{"json with charset wrapped", true, "application/json; charset=utf-8", 200, true},
		{"subresource untouched", false, "application/json", 200, false},
		{"html untouched", true, "text/html", 200, false},
		{"error response untouched", true, "application/json", 502, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := shouldWrapJSONDocument(tt.isDocRoot, tt.contentType, tt.status); got != tt.want {
				t.Errorf("shouldWrapJSONDocument(%v, %q, %d) = %v, want %v",
					tt.isDocRoot, tt.contentType, tt.status, got, tt.want)
			}
		})
	}
}

func TestValidPreviewPort(t *testing.T) {
	tests := []struct {
		port int
		want bool
	}{
		{3000, true},
		{1, true},
		{65535, true},
		{ttydPort, false}, // ttyd must never be proxied as an app preview
		{0, false},
		{65536, false},
		{-80, false},
	}
	for _, tt := range tests {
		if got := validPreviewPort(tt.port); got != tt.want {
			t.Errorf("validPreviewPort(%d) = %v, want %v", tt.port, got, tt.want)
		}
	}
}

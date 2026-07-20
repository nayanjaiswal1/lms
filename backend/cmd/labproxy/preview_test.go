package main

import "testing"

func TestSplitPreviewPort(t *testing.T) {
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
			port, path := splitPreviewPort(tt.path)
			if port != tt.wantPort || path != tt.wantPath {
				t.Errorf("splitPreviewPort(%q) = (%d, %q), want (%d, %q)",
					tt.path, port, path, tt.wantPort, tt.wantPath)
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

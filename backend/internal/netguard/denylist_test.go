package netguard

import (
	"net"
	"testing"
)

func TestIsDenylisted(t *testing.T) {
	tests := []struct {
		name string
		ip   string
		want bool
	}{
		// RFC1918 private IPv4.
		{"rfc1918 10/8", "10.1.2.3", true},
		{"rfc1918 172.16/12 low", "172.16.0.1", true},
		{"rfc1918 172.16/12 high", "172.31.255.254", true},
		{"rfc1918 192.168/16", "192.168.1.1", true},

		// RFC4193 IPv6 unique-local.
		{"ipv6 ULA fc00::/7 low", "fc00::1", true},
		{"ipv6 ULA fc00::/7 high", "fdff:ffff::1", true},

		// Loopback.
		{"ipv4 loopback", "127.0.0.1", true},
		{"ipv4 loopback other", "127.5.5.5", true},
		{"ipv6 loopback", "::1", true},

		// Link-local.
		{"ipv4 link-local", "169.254.1.1", true},
		{"ipv6 link-local", "fe80::1", true},

		// Cloud metadata.
		{"aws/gcp/azure/do metadata v4", "169.254.169.254", true},
		{"aws metadata v6", "fd00:ec2::254", true},

		// Unspecified.
		{"ipv4 unspecified", "0.0.0.0", true},
		{"ipv6 unspecified", "::", true},

		// IPv4-mapped IPv6 bypass attempts — classic SSRF trick, must still
		// be caught since To4() unwraps these before the range checks.
		{"ipv4-mapped private", "::ffff:10.0.0.1", true},
		{"ipv4-mapped loopback", "::ffff:127.0.0.1", true},
		{"ipv4-mapped link-local metadata", "::ffff:169.254.169.254", true},
		{"ipv4-mapped public", "::ffff:8.8.8.8", false},

		// Public IPs — must pass.
		{"public v4 dns", "8.8.8.8", false},
		{"public v4 other", "1.1.1.1", false},
		{"public v6", "2606:4700:4700::1111", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ip := net.ParseIP(tt.ip)
			if ip == nil {
				t.Fatalf("net.ParseIP(%q) returned nil", tt.ip)
			}
			if got := IsDenylisted(ip); got != tt.want {
				t.Errorf("IsDenylisted(%s) = %v, want %v", tt.ip, got, tt.want)
			}
		})
	}
}

func TestIsDenylistedNil(t *testing.T) {
	if !IsDenylisted(nil) {
		t.Error("IsDenylisted(nil) = false, want true (fail closed)")
	}
}

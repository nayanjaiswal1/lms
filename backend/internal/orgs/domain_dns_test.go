package orgs

import (
	"context"
	"errors"
	"net"
	"testing"
)

func TestDNSProvesOwnership(t *testing.T) {
	const token = "abc123"
	cases := []struct {
		name    string
		records []string
		err     error
		want    bool
		wantErr bool
	}{
		{"matching record", []string{"v=spf1", DNSVerificationValuePrefix + token}, nil, true, false},
		{"wrong token", []string{DNSVerificationValuePrefix + "other"}, nil, false, false},
		{"no record published", nil, &net.DNSError{IsNotFound: true}, false, false},
		{"resolver failure", nil, errors.New("timeout"), false, true},
	}
	for _, c := range cases {
		s := &DomainService{lookupTXT: func(_ context.Context, name string) ([]string, error) {
			if name != DNSVerificationLabel+".example.com" {
				t.Errorf("%s: queried %q", c.name, name)
			}
			return c.records, c.err
		}}
		got, err := s.dnsProvesOwnership(context.Background(), "example.com", token)
		if got != c.want || (err != nil) != c.wantErr {
			t.Errorf("%s: got (%v, %v), want (%v, err=%v)", c.name, got, err, c.want, c.wantErr)
		}
	}
}

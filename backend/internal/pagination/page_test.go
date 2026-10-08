package pagination

import (
	"errors"
	"net/url"
	"testing"
	"time"
)

type row struct {
	at time.Time
	id string
}

func TestPageRoundTrip(t *testing.T) {
	p, err := ParseParams(url.Values{"limit": {"2"}})
	if err != nil || p.Limit != 2 || p.After != nil || p.Fetch() != 3 {
		t.Fatalf("first page params = %+v, %v", p, err)
	}
	t0 := time.UnixMicro(1_700_000_000_000_000)
	rows := []row{{t0, "c"}, {t0.Add(-time.Second), "b"}, {t0.Add(-2 * time.Second), "a"}}
	key := func(r row) (time.Time, string) { return r.at, r.id }

	page := NewPage(rows, p, key)
	if len(page.Items) != 2 || page.NextCursor == "" {
		t.Fatalf("page = %+v, want 2 items and a cursor", page)
	}
	next, err := ParseParams(url.Values{"limit": {"2"}, "cursor": {page.NextCursor}})
	if err != nil || next.AfterID != "b" || !next.After.Equal(rows[1].at) {
		t.Fatalf("next params = %+v, %v", next, err)
	}
	if last := NewPage(rows[2:], next, key); last.NextCursor != "" || len(last.Items) != 1 {
		t.Fatalf("last page = %+v", last)
	}

	if _, err := ParseParams(url.Values{"cursor": {"not-a-cursor!"}}); !errors.Is(err, ErrBadCursor) {
		t.Fatalf("bad cursor: err = %v", err)
	}
	if p, _ := ParseParams(url.Values{"limit": {"100000"}}); p.Limit != MaxLimit {
		t.Fatalf("limit not clamped: %d", p.Limit)
	}
	if empty := NewPage[row](nil, p, key); empty.Items == nil {
		t.Fatal("nil rows must encode as []")
	}
}

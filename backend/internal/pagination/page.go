package pagination

import (
	"errors"
	"net/url"
	"strconv"
	"time"
)

// The API's list convention: GET ...?limit=&cursor= answers
// {"items": [...], "next_cursor": "..."}; next_cursor is omitted on the last
// page. Rows are ordered newest first by (created_at, id), which the cursor
// encodes.
const (
	DefaultLimit = 50
	MaxLimit     = 200
)

// ErrBadCursor is returned by ParseParams for a cursor this API never issued.
var ErrBadCursor = errors.New("pagination: malformed cursor")

// Params is a parsed page request. After/AfterID are nil/"" on the first page.
type Params struct {
	Limit   int
	After   *time.Time
	AfterID string
}

// ParseParams reads ?limit= (clamped to [1, MaxLimit], default DefaultLimit)
// and ?cursor=.
func ParseParams(q url.Values) (Params, error) {
	limit, err := strconv.Atoi(q.Get("limit"))
	if err != nil || limit <= 0 {
		limit = DefaultLimit
	}
	p := Params{Limit: min(limit, MaxLimit)}
	at, id, err := DecodeCursor(q.Get("cursor"), "pagination")
	if err != nil {
		return Params{}, ErrBadCursor
	}
	if id != "" {
		p.After, p.AfterID = &at, id
	}
	return p, nil
}

// Fetch is the row count a repo should request: one past the page, so
// NewPage can tell whether another page exists.
func (p Params) Fetch() int { return p.Limit + 1 }

// Page is the list envelope.
type Page[T any] struct {
	Items      []T    `json:"items"`
	NextCursor string `json:"next_cursor,omitempty"`
}

// NewPage trims rows (fetched with p.Fetch()) to the page and sets the cursor
// from the last kept row's (created_at, id).
func NewPage[T any](rows []T, p Params, key func(T) (time.Time, string)) Page[T] {
	if rows == nil {
		rows = []T{}
	}
	if len(rows) <= p.Limit {
		return Page[T]{Items: rows}
	}
	rows = rows[:p.Limit]
	at, id := key(rows[len(rows)-1])
	return Page[T]{Items: rows, NextCursor: EncodeCursor(at, id)}
}

package whatsnew

import (
	"context"
	"errors"
	"strings"
	"testing"
)

// service.Create/Update return before touching s.repo when validation fails,
// so a nil repo is safe here — this only exercises the validate() branches.
func TestCreateRejectsInvalidInput(t *testing.T) {
	valid := Entry{Title: "t", Description: "d", Icon: "sparkles", CTALabel: "Go", CTAHref: "/diary"}

	cases := []struct {
		name string
		e    Entry
	}{
		{"empty title", valid.with(func(e *Entry) { e.Title = "" })},
		{"title too long", valid.with(func(e *Entry) { e.Title = strings.Repeat("x", 121) })},
		{"empty description", valid.with(func(e *Entry) { e.Description = "" })},
		{"empty cta_label", valid.with(func(e *Entry) { e.CTALabel = "" })},
		{"empty cta_href", valid.with(func(e *Entry) { e.CTAHref = "" })},
		{"unknown icon", valid.with(func(e *Entry) { e.Icon = "not-a-real-icon" })},
	}

	s := NewService(nil)
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := s.Create(context.Background(), tc.e); !errors.Is(err, ErrInvalid) {
				t.Fatalf("Create(%+v) error = %v, want ErrInvalid", tc.e, err)
			}
		})
	}
}

func (e Entry) with(mutate func(*Entry)) Entry {
	mutate(&e)
	return e
}

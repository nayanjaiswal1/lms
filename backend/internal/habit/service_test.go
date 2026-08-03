package habit

import (
	"errors"
	"testing"
	"time"
)

func TestValidCadence(t *testing.T) {
	for _, c := range []Cadence{CadenceDaily, CadenceWeekly, CadenceMonthly} {
		if !validCadence(c) {
			t.Fatalf("cadence %q: want valid", c)
		}
	}
	if validCadence("yearly") {
		t.Fatal("cadence \"yearly\": want invalid")
	}
}

func TestValidColor(t *testing.T) {
	for _, c := range ColorPalette {
		if !validColor(c) {
			t.Fatalf("color %q: want valid", c)
		}
	}
	if validColor("chartreuse") {
		t.Fatal("color \"chartreuse\": want invalid")
	}
}

func TestValidateWeeklyOptions(t *testing.T) {
	cases := []struct {
		name        string
		cadence     Cadence
		targetCount int
		weekdays    []int32
		wantErr     error
	}{
		{"daily default", CadenceDaily, 1, nil, nil},
		{"daily with target rejected", CadenceDaily, 2, nil, ErrConflictingModes},
		{"daily with weekdays rejected", CadenceDaily, 1, []int32{1}, ErrConflictingModes},
		{"weekly default", CadenceWeekly, 1, nil, nil},
		{"weekly any-N-times", CadenceWeekly, 3, nil, nil},
		{"weekly target out of range", CadenceWeekly, 8, nil, ErrInvalidTarget},
		{"weekly specific weekdays", CadenceWeekly, 1, []int32{1, 4}, nil},
		{"weekly weekday out of range", CadenceWeekly, 1, []int32{7}, ErrInvalidWeekday},
		{"weekly duplicate weekday", CadenceWeekly, 1, []int32{1, 1}, ErrInvalidWeekday},
		{"weekly both modes rejected", CadenceWeekly, 3, []int32{1}, ErrConflictingModes},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := validateWeeklyOptions(c.cadence, c.targetCount, c.weekdays)
			if !errors.Is(err, c.wantErr) {
				t.Fatalf("validateWeeklyOptions(%s, %d, %v) = %v, want %v", c.cadence, c.targetCount, c.weekdays, err, c.wantErr)
			}
		})
	}
}

func TestMondayOfWeek(t *testing.T) {
	cases := []struct {
		date string
		want string
	}{
		{"2026-08-01", "2026-07-27"}, // Saturday -> preceding Monday
		{"2026-08-03", "2026-08-03"}, // already a Monday
		{"2026-08-09", "2026-08-03"}, // Sunday -> preceding Monday
	}
	for _, c := range cases {
		d, err := time.Parse("2006-01-02", c.date)
		if err != nil {
			t.Fatalf("parse %q: %v", c.date, err)
		}
		got := mondayOfWeek(d).Format("2006-01-02")
		if got != c.want {
			t.Fatalf("mondayOfWeek(%s) = %s, want %s", c.date, got, c.want)
		}
	}
}

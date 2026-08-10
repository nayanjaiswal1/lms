package habit

import (
	"errors"
	"strings"
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

func TestValidHabitType(t *testing.T) {
	for _, ht := range []HabitType{HabitTypeGeneric, HabitTypeGym, HabitTypeSleep, HabitTypeReading, HabitTypeCustom} {
		if !validHabitType(ht) {
			t.Fatalf("type %q: want valid", ht)
		}
	}
	if validHabitType("workout") {
		t.Fatal("type \"workout\": want invalid")
	}
}

func TestValidateCustomFields(t *testing.T) {
	cases := []struct {
		name    string
		fields  []CustomField
		wantErr error
	}{
		{"empty rejected", nil, ErrCustomFieldsEmpty},
		{"valid single field", []CustomField{{Key: "exercise", Label: "Exercise", Kind: CustomFieldText}}, nil},
		{"missing key rejected", []CustomField{{Key: "", Label: "Exercise", Kind: CustomFieldText}}, ErrCustomFieldInvalid},
		{"missing label rejected", []CustomField{{Key: "exercise", Label: "", Kind: CustomFieldText}}, ErrCustomFieldInvalid},
		{"invalid kind rejected", []CustomField{{Key: "exercise", Label: "Exercise", Kind: "date"}}, ErrCustomFieldInvalid},
		{
			"duplicate key rejected",
			[]CustomField{{Key: "x", Label: "A", Kind: CustomFieldText}, {Key: "x", Label: "B", Kind: CustomFieldNumber}},
			ErrCustomFieldInvalid,
		},
		{"too many fields rejected", make([]CustomField, maxCustomFields+1), ErrTooManyCustomFields},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := validateCustomFields(c.fields)
			if !errors.Is(err, c.wantErr) {
				t.Fatalf("validateCustomFields(%v) = %v, want %v", c.fields, err, c.wantErr)
			}
		})
	}
}

func TestAllowedMetadataKeys(t *testing.T) {
	gym, err := allowedMetadataKeys(Habit{Type: HabitTypeGym})
	if err != nil {
		t.Fatalf("gym habit: unexpected error %v", err)
	}
	if !gym["exercise"] || gym["takeaway"] {
		t.Fatalf("gym habit: unexpected allowed keys %v", gym)
	}

	custom, err := allowedMetadataKeys(Habit{Type: HabitTypeCustom, CustomFields: []CustomField{{Key: "mood", Label: "Mood", Kind: CustomFieldText}}})
	if err != nil {
		t.Fatalf("custom habit: unexpected error %v", err)
	}
	if !custom["mood"] || custom["exercise"] {
		t.Fatalf("custom habit: unexpected allowed keys %v", custom)
	}

	if _, err := allowedMetadataKeys(Habit{Type: HabitTypeGeneric}); !errors.Is(err, ErrHabitHasNoFields) {
		t.Fatalf("generic habit: got %v, want ErrHabitHasNoFields", err)
	}
}

func TestValidIcon(t *testing.T) {
	for _, icon := range IconOptions {
		if !validIcon(icon) {
			t.Fatalf("icon %q: want valid", icon)
		}
	}
	if !validIcon("") {
		t.Fatal("icon \"\": want valid (means no override)")
	}
	if !validIcon("🔥") {
		t.Fatal("icon \"🔥\": want valid (short custom emoji)")
	}
	if !validIcon("👨‍👩‍👧‍👦") {
		t.Fatal("icon \"👨‍👩‍👧‍👦\": want valid (7-rune ZWJ family emoji fits the 8-rune cap)")
	}
	if validIcon("nuclear-launch-button") {
		t.Fatal("icon \"nuclear-launch-button\": want invalid (not curated, exceeds custom-icon rune cap)")
	}
}

func TestNormalizeTags(t *testing.T) {
	cases := []struct {
		name    string
		tags    []string
		want    []string
		wantErr error
	}{
		{"trims and drops empties", []string{" Health ", "", "  "}, []string{"Health"}, nil},
		{"dedupes case-insensitively, keeps first casing", []string{"Health", "health", "HEALTH"}, []string{"Health"}, nil},
		{"nil in, empty out", nil, []string{}, nil},
		{"too many rejected", make([]string, maxTags+1), nil, ErrTooManyTags},
		{"too long rejected", []string{strings.Repeat("a", maxTagLength+1)}, nil, ErrTagTooLong},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := normalizeTags(c.tags)
			if !errors.Is(err, c.wantErr) {
				t.Fatalf("normalizeTags(%v) err = %v, want %v", c.tags, err, c.wantErr)
			}
			if err != nil {
				return
			}
			if len(got) != len(c.want) {
				t.Fatalf("normalizeTags(%v) = %v, want %v", c.tags, got, c.want)
			}
			for i := range got {
				if got[i] != c.want[i] {
					t.Fatalf("normalizeTags(%v) = %v, want %v", c.tags, got, c.want)
				}
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

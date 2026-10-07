package privacy

import (
	"errors"
	"strings"
	"testing"
)

func TestNormalizeNominee(t *testing.T) {
	if n, err := normalizeNominee(nil); n != nil || err != nil {
		t.Fatalf("nil: got %v, %v", n, err)
	}
	if n, err := normalizeNominee(&Nominee{Name: " ", Relationship: "", Contact: ""}); n != nil || err != nil {
		t.Fatalf("blank should clear: got %v, %v", n, err)
	}
	n, err := normalizeNominee(&Nominee{Name: " Asha ", Relationship: "Sister", Contact: "a@b.co"})
	if err != nil || n.Name != "Asha" {
		t.Fatalf("valid: got %v, %v", n, err)
	}
	if _, err := normalizeNominee(&Nominee{Name: "Asha"}); !errors.Is(err, ErrInvalidNominee) {
		t.Fatalf("partial: want ErrInvalidNominee, got %v", err)
	}
	long := strings.Repeat("x", maxNomineeFieldLen+1)
	if _, err := normalizeNominee(&Nominee{Name: long, Relationship: "a", Contact: "b"}); !errors.Is(err, ErrInvalidNominee) {
		t.Fatalf("too long: want ErrInvalidNominee, got %v", err)
	}
}

package focuswall

import "testing"

func TestValidateText(t *testing.T) {
	if err := validateText(""); err != ErrTextEmpty {
		t.Fatalf("empty text: want ErrTextEmpty, got %v", err)
	}
	long := make([]byte, maxTextLength+1)
	for i := range long {
		long[i] = 'a'
	}
	if err := validateText(string(long)); err != ErrTextTooLong {
		t.Fatalf("501-char text: want ErrTextTooLong, got %v", err)
	}
	if err := validateText("Buy coffee"); err != nil {
		t.Fatalf("valid text: want nil, got %v", err)
	}
}

func TestValidColorAndCategory(t *testing.T) {
	for _, c := range []Color{ColorYellow, ColorBlue, ColorPink, ColorGreen} {
		if !validColor(c) {
			t.Fatalf("color %q: want valid", c)
		}
	}
	if validColor("purple") {
		t.Fatal("color \"purple\": want invalid")
	}

	for _, c := range []Category{CategoryPersonal, CategoryStudy, CategoryUrgent} {
		if !validCategory(c) {
			t.Fatalf("category %q: want valid", c)
		}
	}
	if validCategory("random") {
		t.Fatal("category \"random\": want invalid")
	}
}

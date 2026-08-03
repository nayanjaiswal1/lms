package srs

import "testing"

// ponytail: no DB test infra exists for domain packages yet (see
// courses.service_test.go's precedent) — this covers the one pure-Go branch
// worth a check: SM2's quality→schedule mapping, since that's exactly what
// now gets persisted into srs_reviews on every review.
func TestSM2(t *testing.T) {
	t.Run("again resets interval and repetitions, ease factor unchanged", func(t *testing.T) {
		interval, reps, ef := SM2(10, 3, 2.5, 0)
		if interval != 1 || reps != 0 || ef != 2.5 {
			t.Fatalf("quality=0: got (interval=%d, reps=%d, ef=%v), want (1, 0, 2.5)", interval, reps, ef)
		}
	})

	t.Run("hard resets repetitions and penalises ease factor, floored at 1.3", func(t *testing.T) {
		_, reps, ef := SM2(10, 3, 1.35, 1)
		if reps != 0 {
			t.Fatalf("quality=1: expected repetitions reset to 0, got %d", reps)
		}
		if ef != 1.3 {
			t.Fatalf("quality=1: expected ease factor floored at 1.3, got %v", ef)
		}
	})

	t.Run("good advances interval on the 1/6/ease*interval schedule", func(t *testing.T) {
		if interval, reps, _ := SM2(1, 0, 2.5, 2); interval != 1 || reps != 1 {
			t.Fatalf("quality=2, reps=0: got (interval=%d, reps=%d), want (1, 1)", interval, reps)
		}
		if interval, reps, _ := SM2(1, 1, 2.5, 2); interval != 6 || reps != 2 {
			t.Fatalf("quality=2, reps=1: got (interval=%d, reps=%d), want (6, 2)", interval, reps)
		}
		if interval, _, ef := SM2(6, 2, 2.5, 2); interval != 15 || ef != 2.5 {
			t.Fatalf("quality=2, reps=2: got (interval=%d, ef=%v), want (15, 2.5)", interval, ef)
		}
	})

	t.Run("easy advances interval and boosts ease factor", func(t *testing.T) {
		interval, reps, ef := SM2(6, 2, 2.5, 3)
		if interval != 15 || reps != 3 || ef != 2.6 {
			t.Fatalf("quality=3: got (interval=%d, reps=%d, ef=%v), want (15, 3, 2.6)", interval, reps, ef)
		}
	})

	t.Run("out-of-range quality clamps into [0, 3]", func(t *testing.T) {
		lo, _, _ := SM2(10, 3, 2.5, -5)
		hi, _, hiEF := SM2(6, 2, 2.5, 99)
		if lo != 1 {
			t.Fatalf("quality=-5: expected clamp to 0 (interval=1), got interval=%d", lo)
		}
		if hi != 15 || hiEF != 2.6 {
			t.Fatalf("quality=99: expected clamp to 3, got (interval=%d, ef=%v)", hi, hiEF)
		}
	})
}

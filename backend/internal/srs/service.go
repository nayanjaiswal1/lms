package srs

import "math"

// SM2 applies the SM-2 spaced-repetition algorithm and returns the new
// scheduling values to persist on the card.
//
// quality must be in [0, 3]:
//
//	0 = Again — complete blackout; restart from scratch.
//	1 = Hard  — incorrect but the answer was close.
//	2 = Good  — correct with hesitation.
//	3 = Easy  — perfect recall.
//
// The function never panics; out-of-range quality values are clamped to [0, 3].
func SM2(intervalDays, repetitions int, easeFactor float64, quality int) (newInterval, newReps int, newEF float64) {
	if quality < 0 {
		quality = 0
	}
	if quality > 3 {
		quality = 3
	}

	switch quality {
	case 0:
		// Again: full reset, ease factor unchanged.
		return 1, 0, easeFactor

	case 1:
		// Hard: reset repetition counter, penalise ease factor.
		newEF = easeFactor - 0.15
		if newEF < 1.3 {
			newEF = 1.3
		}
		return 1, 0, newEF

	case 2:
		// Good: advance the interval, keep ease factor.
		newReps = repetitions + 1
		switch repetitions {
		case 0:
			newInterval = 1
		case 1:
			newInterval = 6
		default:
			newInterval = int(math.Round(float64(intervalDays) * easeFactor))
		}
		return newInterval, newReps, easeFactor

	default: // 3 = Easy
		// Easy: advance the interval, boost ease factor.
		newReps = repetitions + 1
		switch repetitions {
		case 0:
			newInterval = 1
		case 1:
			newInterval = 6
		default:
			newInterval = int(math.Round(float64(intervalDays) * easeFactor))
		}
		newEF = easeFactor + 0.1
		return newInterval, newReps, newEF
	}
}

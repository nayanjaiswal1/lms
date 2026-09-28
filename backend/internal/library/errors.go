package library

import "errors"

var (
	// ErrNotFound covers both "the section doesn't exist in this org" and
	// "the source item doesn't exist / isn't eligible" — writeDomainError
	// maps both to 404, same as every other domain here.
	ErrNotFound = errors.New("library: not found")

	// ErrInvalidKind is returned for a kind outside {lab, quiz, notes} —
	// "debug" ships with the Phase 1 builder (docs/debug-labs.md L6).
	ErrInvalidKind = errors.New("library: invalid kind")

	// ErrItemNotEligible is returned when the source item exists but fails
	// an Attach eligibility check: an unpublished lab/quiz, or a non-notes
	// module passed as kind=notes.
	ErrItemNotEligible = errors.New("library: item is not eligible for placement")
)

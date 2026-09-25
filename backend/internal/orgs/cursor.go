package orgs

import (
	"time"

	"github.com/mindforge/backend/internal/pagination"
)

// encodeCursor encodes a (created_at, id) pair as a base64url cursor string.
// Thin wrapper over pagination.EncodeCursor kept so existing call sites read
// unchanged.
func encodeCursor(createdAt time.Time, id string) string {
	return pagination.EncodeCursor(createdAt, id)
}

// decodeCursor decodes a cursor string back into (created_at, id).
// Returns an error if the cursor is malformed.
func decodeCursor(cursor string) (time.Time, string, error) {
	return pagination.DecodeCursor(cursor, "orgs")
}

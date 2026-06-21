package orgs

import (
	"encoding/base64"
	"fmt"
	"strings"
	"time"
)

// encodeCursor encodes a (created_at, id) pair as a base64url cursor string.
func encodeCursor(createdAt time.Time, id string) string {
	raw := fmt.Sprintf("%d:%s", createdAt.UnixMicro(), id)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// decodeCursor decodes a cursor string back into (created_at, id).
// Returns an error if the cursor is malformed.
func decodeCursor(cursor string) (time.Time, string, error) {
	if cursor == "" {
		return time.Time{}, "", nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", fmt.Errorf("orgs: decode cursor: base64: %w", err)
	}
	parts := strings.SplitN(string(b), ":", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("orgs: decode cursor: invalid format")
	}
	var micro int64
	if _, err := fmt.Sscanf(parts[0], "%d", &micro); err != nil {
		return time.Time{}, "", fmt.Errorf("orgs: decode cursor: parse timestamp: %w", err)
	}
	return time.UnixMicro(micro), parts[1], nil
}

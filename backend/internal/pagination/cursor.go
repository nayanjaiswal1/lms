// Package pagination holds the shared cursor-pagination helpers: a
// (created_at, id) pair encoded as a base64url cursor string. Three domains
// previously carried verbatim copies (orgs, jobs, mcpconnect's action log);
// they now delegate here, passing their own error prefix so log messages
// keep identifying the originating domain.
package pagination

import (
	"encoding/base64"
	"fmt"
	"strings"
	"time"
)

// EncodeCursor encodes a (created_at, id) pair as a base64url cursor string.
func EncodeCursor(createdAt time.Time, id string) string {
	raw := fmt.Sprintf("%d:%s", createdAt.UnixMicro(), id)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// DecodeCursor decodes a cursor string back into (created_at, id). An empty
// cursor decodes to the zero time and empty id with no error. prefix names
// the calling domain (e.g. "orgs") and is stamped onto malformed-cursor
// errors so they keep their original attribution.
func DecodeCursor(cursor, prefix string) (time.Time, string, error) {
	if cursor == "" {
		return time.Time{}, "", nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", fmt.Errorf("%s: decode cursor: base64: %w", prefix, err)
	}
	parts := strings.SplitN(string(b), ":", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("%s: decode cursor: invalid format", prefix)
	}
	var micro int64
	if _, err := fmt.Sscanf(parts[0], "%d", &micro); err != nil {
		return time.Time{}, "", fmt.Errorf("%s: decode cursor: parse timestamp: %w", prefix, err)
	}
	return time.UnixMicro(micro), parts[1], nil
}

package generator

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// sqlString returns s as a single-quoted SQL string literal with embedded
// single quotes doubled.
func sqlString(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

// sqlStringArray returns items as a Postgres TEXT[] literal, e.g. ARRAY['a','b'].
func sqlStringArray(items []string) string {
	quoted := make([]string, len(items))
	for i, it := range items {
		quoted[i] = sqlString(it)
	}
	return "ARRAY[" + strings.Join(quoted, ",") + "]"
}

// sqlBool returns the Postgres literal for a Go bool.
func sqlBool(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

// sqlInt returns the Postgres literal for a Go int.
func sqlInt(n int) string {
	return strconv.Itoa(n)
}

// sqlNullableString returns "NULL" for an empty string, or a quoted literal
// otherwise — for optional TEXT columns authored as an empty canonical field.
func sqlNullableString(s string) string {
	if s == "" {
		return "NULL"
	}
	return sqlString(s)
}

// dollarQuote wraps content in a Postgres dollar-quoted string literal using
// tag, avoiding single-quote escaping entirely for long bodies (markdown,
// scripts, JSON). tag must not itself appear as a literal "$tag$" substring
// inside content — the fixed short tags used by this package (md, json,
// script) are chosen to make that collision practically impossible for
// authored educational content.
func dollarQuote(tag, content string) string {
	return "$" + tag + "$" + content + "$" + tag + "$"
}

// sqlJSONB marshals v to compact JSON and returns it as a dollar-quoted JSONB
// literal (dollarQuote(...)::jsonb).
func sqlJSONB(v any) (string, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return "", fmt.Errorf("sqlJSONB: %w", err)
	}
	return dollarQuote("json", string(b)) + "::jsonb", nil
}

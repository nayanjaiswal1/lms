package labauthor

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/mindforge/backend/internal/labblock"
)

// Language-aware literal rendering: the ONLY way a recipe parameter may enter
// generated source (docs/debug-labs.md §B7). The renderer (phase 1c-ii) must
// call RenderLiteral with the literal type the target `value` slot declares
// (labblock.SlotDecl.Literal), and paste the returned text verbatim; it must
// never interpolate a param into source any other way. The output of every
// function here is a complete, self-delimited literal token: strings come back
// already quoted, so an attacker-controlled value can never terminate the
// literal or start new code.

// RenderLiteral formats v as a source literal of type lit.
//
//	python_str    'single-quoted' with Python repr escaping (\\ \' \n \r \t,
//	              \xNN for other control chars, \uNNNN/\UNNNNNNNN for
//	              non-printable code points; printable Unicode kept)
//	python_int    decimal integer
//	python_float  finite float, always with '.' or exponent
//	python_bool   True | False
//	json          compact JSON (HTML-safe: < > & U+2028 U+2029 escaped)
//	js_string     "double-quoted" JS string; < > & and every non-printable or
//	              non-ASCII-control code point escaped as \uNNNN, so the token
//	              is also safe inside an inline <script>
//	js_number     finite number
//	js_bool       true | false
func RenderLiteral(lit string, v any) (string, error) {
	switch lit {
	case labblock.LitPythonStr:
		s, ok := v.(string)
		if !ok {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs a string, got %T", lit, v)
		}
		return PythonRepr(s), nil
	case labblock.LitJSString:
		s, ok := v.(string)
		if !ok {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs a string, got %T", lit, v)
		}
		return JSString(s), nil
	case labblock.LitPythonInt:
		n, ok := integerOf(v)
		if !ok {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs an integer, got %v", lit, v)
		}
		return strconv.FormatInt(n, 10), nil
	case labblock.LitPythonFloat, labblock.LitJSNumber:
		f, ok := numOf(v)
		if !ok || math.IsNaN(f) || math.IsInf(f, 0) {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs a finite number, got %v", lit, v)
		}
		out := strconv.FormatFloat(f, 'g', -1, 64)
		if lit == labblock.LitPythonFloat && !strings.ContainsAny(out, ".e") {
			out += ".0"
		}
		return out, nil
	case labblock.LitPythonBool:
		b, ok := v.(bool)
		if !ok {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs a bool, got %T", lit, v)
		}
		if b {
			return "True", nil
		}
		return "False", nil
	case labblock.LitJSBool:
		b, ok := v.(bool)
		if !ok {
			return "", fmt.Errorf("labauthor.RenderLiteral: %s needs a bool, got %T", lit, v)
		}
		return strconv.FormatBool(b), nil
	case labblock.LitJSON:
		return JSONLiteral(v)
	}
	return "", fmt.Errorf("labauthor.RenderLiteral: unknown literal type %q", lit)
}

func integerOf(v any) (int64, bool) {
	switch n := v.(type) {
	case int:
		return int64(n), true
	case int64:
		return n, true
	case json.Number:
		i, err := n.Int64()
		return i, err == nil
	case float64:
		if n == math.Trunc(n) && math.Abs(n) < 1<<53 {
			return int64(n), true
		}
	}
	return 0, false
}

// PythonRepr renders s like Python's repr() but always single-quoted.
func PythonRepr(s string) string {
	var b strings.Builder
	b.WriteByte('\'')
	for _, r := range s {
		switch {
		case r == '\\':
			b.WriteString(`\\`)
		case r == '\'':
			b.WriteString(`\'`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r == utf8.RuneError:
			b.WriteString(`�`)
		case r < 0x20 || r == 0x7f:
			fmt.Fprintf(&b, `\x%02x`, r)
		case r < 0x7f || unicode.IsPrint(r):
			b.WriteRune(r)
		case r <= 0xff:
			fmt.Fprintf(&b, `\x%02x`, r)
		case r <= 0xffff:
			fmt.Fprintf(&b, `\u%04x`, r)
		default:
			fmt.Fprintf(&b, `\U%08x`, r)
		}
	}
	b.WriteByte('\'')
	return b.String()
}

// JSString renders s as a double-quoted JavaScript string literal that is safe
// in a .js file and inside an inline <script>.
func JSString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range s {
		switch {
		case r == '\\':
			b.WriteString(`\\`)
		case r == '"':
			b.WriteString(`\"`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r == '<' || r == '>' || r == '&' || r == '\'' || r == '`' || r == '$':
			// '`' and '$' keep the token inert if it is ever re-embedded in a template literal.
			fmt.Fprintf(&b, `\u%04x`, r)
		case r == utf8.RuneError || r < 0x20 || r == 0x7f || r == 0x2028 || r == 0x2029:
			fmt.Fprintf(&b, `\u%04x`, r)
		case r < 0x7f || unicode.IsPrint(r):
			b.WriteRune(r)
		case r <= 0xffff:
			fmt.Fprintf(&b, `\u%04x`, r)
		default:
			r -= 0x10000
			fmt.Fprintf(&b, `\u%04x\u%04x`, 0xd800+(r>>10), 0xdc00+(r&0x3ff))
		}
	}
	b.WriteByte('"')
	return b.String()
}

// JSONLiteral renders v as compact, HTML-safe JSON (encoding/json escapes
// < > & U+2028 U+2029 by default).
func JSONLiteral(v any) (string, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(true)
	if err := enc.Encode(v); err != nil {
		return "", fmt.Errorf("labauthor.JSONLiteral: %w", err)
	}
	return strings.TrimRight(buf.String(), "\n"), nil
}

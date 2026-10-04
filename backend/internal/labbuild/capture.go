package labbuild

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"

	"github.com/mindforge/backend/internal/labs"
)

// Captured placeholders ({{captured.trace}} etc. in a ticket) are filled from
// the REAL app output of the broken run (docs/debug-labs.md B3): tickets show
// real tracebacks, not authored imitations. The capture runs inside the
// clean-room sandbox after the symptom probes have hit the broken app, reading
// the supervised app's own log.
const (
	appLogPath      = "/var/log/mindforge-lab/app.log"
	pgLogPath       = "/var/log/mindforge-lab/postgres.log"
	maxCaptureBytes = 4000
	captureExecCap  = 256 * 1024
)

// captureScripts maps a placeholder name to the trusted script that extracts it.
var captureScripts = map[string]string{
	// The last Python traceback in the app log, up to and including its exception line.
	"trace": `python3 - <<'PY'
import re, sys
try:
    text = open("` + appLogPath + `", errors="replace").read()
except OSError:
    sys.exit(0)
starts = [m.start() for m in re.finditer(r"^Traceback \(most recent call last\):", text, re.M)]
if not starts:
    sys.exit(0)
out = []
for line in text[starts[-1]:].split("\n"):
    out.append(line)
    if out[1:] and line and not line.startswith((" ", "\t")):
        break
print("\n".join(out))
PY`,
	// The tail of the app log.
	"log": `tail -n 40 ` + appLogPath + ` 2>/dev/null`,
	// The slowest recent statements the database logged.
	"slow_queries": `grep -a "duration:" ` + pgLogPath + ` 2>/dev/null | tail -n 20`,
}

var (
	ansiRe        = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)
	capturePlaceR = regexp.MustCompile(`\{\{\s*captured\.([a-z_]+)\s*\}\}`)
)

// captureBox collects captured text from a run's after-grade hook.
type captureBox struct {
	mu   sync.Mutex
	want []string
	got  map[string]string
	errs []string
}

func newCaptureBox(names []string) *captureBox {
	return &captureBox{want: names, got: map[string]string{}}
}

// snapshot copies the captured text collected so far.
func (c *captureBox) snapshot() map[string]string {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make(map[string]string, len(c.got))
	for k, v := range c.got {
		out[k] = v
	}
	return out
}

// hook is a labs.GradeTarget.AfterGrade that runs the requested capture scripts.
func (c *captureBox) hook(rt labs.ContainerRuntime) func(ctx context.Context, containerID string) error {
	return func(ctx context.Context, containerID string) error {
		c.mu.Lock()
		defer c.mu.Unlock()
		for _, name := range c.want {
			script, ok := captureScripts[name]
			if !ok {
				c.errs = append(c.errs, fmt.Sprintf("unknown capture %q", name))
				continue
			}
			out, _, _, err := rt.ExecCapture(ctx, containerID, script, captureExecCap)
			if err != nil {
				c.errs = append(c.errs, fmt.Sprintf("capture %s: %v", name, err))
				continue
			}
			text := cleanCapture(out)
			if text == "" {
				c.errs = append(c.errs, fmt.Sprintf("capture %q found nothing (the broken app's log has no matching output)", name))
				continue
			}
			c.got[name] = text
		}
		return nil
	}
}

// cleanCapture strips terminal escapes and the workspace path prefix and
// bounds the size, so a captured trace reads like the student's own.
func cleanCapture(s string) string {
	s = ansiRe.ReplaceAllString(s, "")
	s = strings.ReplaceAll(s, "/home/labuser/work/", "")
	s = strings.TrimSpace(s)
	if len(s) > maxCaptureBytes {
		s = "…" + s[len(s)-maxCaptureBytes:]
	}
	return s
}

// substituteCaptures replaces {{captured.X}} placeholders in brief with fenced
// blocks of the captured text. Unknown/uncaptured names are left in place and
// reported.
func substituteCaptures(brief string, got map[string]string) (string, []string) {
	var missing []string
	out := capturePlaceR.ReplaceAllStringFunc(brief, func(tok string) string {
		name := capturePlaceR.FindStringSubmatch(tok)[1]
		text, ok := got[name]
		if !ok {
			missing = append(missing, name)
			return tok
		}
		return "```\n" + text + "\n```"
	})
	return out, missing
}

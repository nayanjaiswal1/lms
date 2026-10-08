package labs

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func gitIn(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	require.NoError(t, err, string(out))
	return strings.TrimSpace(string(out))
}

// The debrief diff must show new (untracked) files such as the regression
// test the student wrote, not only edits to tracked files.
func TestStudentDiffScriptIncludesUntrackedFiles(t *testing.T) {
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("bash not available")
	}
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}

	dir := t.TempDir()
	gitIn(t, dir, "init", "-q")
	gitIn(t, dir, "config", "user.email", "t@example.test")
	gitIn(t, dir, "config", "user.name", "t")
	require.NoError(t, os.WriteFile(filepath.Join(dir, "app.py"), []byte("x = 1\n"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, ".gitignore"), []byte("ignored.txt\n"), 0o600))
	gitIn(t, dir, "add", ".")
	gitIn(t, dir, "commit", "-q", "-m", "baseline")
	ref := gitIn(t, dir, "rev-parse", "HEAD")

	require.NoError(t, os.WriteFile(filepath.Join(dir, "app.py"), []byte("x = 2\n"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "test_new.py"), []byte("def test_it():\n    pass\n"), 0o600))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "ignored.txt"), []byte("secret\n"), 0o600))
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "logs"), 0o750))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "logs", "app.log"), []byte("noise\n"), 0o600))

	script := strings.Replace(studentDiffScript(ref), shellQuote(labWorkdir), shellQuote(filepath.ToSlash(dir)), 1)
	out, err := exec.Command(bash, "-c", script).CombinedOutput()
	require.NoError(t, err, string(out))

	diff := string(out)
	require.Contains(t, diff, "+x = 2")
	require.Contains(t, diff, "test_new.py")
	require.Contains(t, diff, "+def test_it():")
	require.NotContains(t, diff, "secret")
	require.NotContains(t, diff, "noise")
}

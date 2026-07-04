package labs

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestResolveWorkdirPath(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{"simple file", "deployment.yaml", "deployment.yaml", false},
		{"nested file", "manifests/deployment.yaml", "manifests/deployment.yaml", false},
		{"dot-prefixed non-traversal filename", "..hidden", "..hidden", false},
		{"leading dot-slash normalized", "./deployment.yaml", "deployment.yaml", false},
		{"redundant slashes normalized", "manifests//deployment.yaml", "manifests/deployment.yaml", false},

		{"empty path", "", "", true},
		{"whitespace-only path", "   ", "", true},
		{"absolute path", "/etc/passwd", "", true},
		{"bare traversal", "..", "", true},
		{"traversal prefix", "../etc/passwd", "", true},
		{"nested traversal", "manifests/../../etc/passwd", "", true},
		{"double nested traversal", "a/b/../../../etc/passwd", "", true},
		{"traversal via dot segments", "a/./../../b", "", true},
		{"root only", "/", "", true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := resolveWorkdirPath(tc.in)
			if tc.wantErr {
				require.Error(t, err)
				require.ErrorIs(t, err, ErrInvalidPath)
				return
			}
			require.NoError(t, err)
			require.Equal(t, tc.want, got)
		})
	}
}

func TestContainerPath(t *testing.T) {
	require.Equal(t, "/home/labuser/work/deployment.yaml", containerPath("deployment.yaml"))
	require.Equal(t, "/home/labuser/work/manifests/deployment.yaml", containerPath("manifests/deployment.yaml"))
}

func TestShellQuote(t *testing.T) {
	require.Equal(t, "'plain'", shellQuote("plain"))
	require.Equal(t, "'it'\\''s'", shellQuote("it's"))
	require.Equal(t, "''\\'''\\'''", shellQuote("''"))
}

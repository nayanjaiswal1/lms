package labbuild

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"path"
	"sort"
	"strings"
)

// Bounds for tars read from untrusted-ish sources (block payloads, sandbox
// output). Renderer output is trusted code's, but is still bounded.
const (
	maxTarFileBytes  = 16 << 20
	maxTarTotalBytes = 96 << 20
	maxTarEntries    = 20000
)

// tarEntry is one file to write into a tar.
type tarEntry struct {
	Name string
	Data []byte
	Mode int64
}

// packTarGz writes entries (sorted by name for determinism) as a tar.gz.
func packTarGz(entries []tarEntry) ([]byte, error) {
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for _, e := range entries {
		mode := e.Mode
		if mode == 0 {
			mode = 0o644
		}
		if err := tw.WriteHeader(&tar.Header{Name: e.Name, Mode: mode, Size: int64(len(e.Data)), Typeflag: tar.TypeReg}); err != nil {
			return nil, fmt.Errorf("labbuild.packTarGz: %w", err)
		}
		if _, err := tw.Write(e.Data); err != nil {
			return nil, fmt.Errorf("labbuild.packTarGz: %w", err)
		}
	}
	if err := tw.Close(); err != nil {
		return nil, fmt.Errorf("labbuild.packTarGz: %w", err)
	}
	if err := gz.Close(); err != nil {
		return nil, fmt.Errorf("labbuild.packTarGz: %w", err)
	}
	return buf.Bytes(), nil
}

// cleanTarName rejects absolute and escaping paths.
func cleanTarName(name string) (string, error) {
	n := path.Clean(strings.TrimPrefix(name, "./"))
	if n == "." || n == ".." || strings.HasPrefix(n, "../") || strings.HasPrefix(n, "/") {
		return "", fmt.Errorf("unsafe tar path %q", name)
	}
	return n, nil
}

// readTar reads regular files from a tar or tar.gz (detected by magic bytes)
// into a map keyed by cleaned path. Directories are skipped; symlinks and other
// special entries are rejected.
func readTar(data []byte) (map[string][]byte, error) {
	var r io.Reader = bytes.NewReader(data)
	if len(data) > 2 && data[0] == 0x1f && data[1] == 0x8b {
		gz, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			return nil, fmt.Errorf("labbuild.readTar: gzip: %w", err)
		}
		defer gz.Close()
		r = gz
	}
	tr := tar.NewReader(r)
	out := map[string][]byte{}
	var total int64
	for {
		h, err := tr.Next()
		if err == io.EOF {
			return out, nil
		}
		if err != nil {
			return nil, fmt.Errorf("labbuild.readTar: %w", err)
		}
		switch h.Typeflag {
		case tar.TypeDir:
			continue
		case tar.TypeReg:
		default:
			return nil, fmt.Errorf("labbuild.readTar: %q is not a regular file", h.Name)
		}
		name, err := cleanTarName(h.Name)
		if err != nil {
			return nil, fmt.Errorf("labbuild.readTar: %w", err)
		}
		if h.Size > maxTarFileBytes {
			return nil, fmt.Errorf("labbuild.readTar: %q is too large", name)
		}
		total += h.Size
		if total > maxTarTotalBytes || len(out) >= maxTarEntries {
			return nil, fmt.Errorf("labbuild.readTar: archive is too large")
		}
		b, err := io.ReadAll(io.LimitReader(tr, maxTarFileBytes+1))
		if err != nil {
			return nil, fmt.Errorf("labbuild.readTar: %w", err)
		}
		out[name] = b
	}
}

// replaceTarEntry returns tgz with the regular file `name` replaced by data,
// preserving every other entry (headers included) and order.
func replaceTarEntry(tgz []byte, name string, data []byte) ([]byte, error) {
	gr, err := gzip.NewReader(bytes.NewReader(tgz))
	if err != nil {
		return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
	}
	defer gr.Close()
	tr := tar.NewReader(gr)
	var buf bytes.Buffer
	gw, _ := gzip.NewWriterLevel(&buf, gzip.BestCompression)
	tw := tar.NewWriter(gw)
	found := false
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
		}
		if h.Typeflag == tar.TypeReg && path.Clean(strings.TrimPrefix(h.Name, "./")) == name {
			h.Size = int64(len(data))
			found = true
			if err := tw.WriteHeader(h); err != nil {
				return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
			}
			if _, err := tw.Write(data); err != nil {
				return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
			}
			continue
		}
		if err := tw.WriteHeader(h); err != nil {
			return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
		}
		if _, err := io.Copy(tw, tr); err != nil {
			return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
		}
	}
	if !found {
		return nil, fmt.Errorf("labbuild.replaceTarEntry: %q not in archive", name)
	}
	if err := tw.Close(); err != nil {
		return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
	}
	if err := gw.Close(); err != nil {
		return nil, fmt.Errorf("labbuild.replaceTarEntry: %w", err)
	}
	return buf.Bytes(), nil
}

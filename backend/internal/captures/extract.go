package captures

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"

	"golang.org/x/net/html"

	"github.com/mindforge/backend/internal/netguard"
)

// pdftotextTimeout bounds a single pdftotext invocation — a pathological PDF
// (huge page count, hostile embedded content) must not hang a job worker
// slot forever.
const pdftotextTimeout = 30 * time.Second

// ExtractPDFText shells out to poppler-utils' pdftotext (already in the
// backend image — see Dockerfile) to pull plain text out of a PDF. Reading
// via stdin/stdout ("-" for both) avoids writing the upload to a temp file
// just to hand pdftotext a path.
func ExtractPDFText(ctx context.Context, pdfBytes []byte) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, pdftotextTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, "pdftotext", "-layout", "-", "-")
	cmd.Stdin = bytes.NewReader(pdfBytes)
	var out, errOut bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errOut
	if err := cmd.Run(); err != nil {
		if stderr := strings.TrimSpace(errOut.String()); stderr != "" {
			return "", fmt.Errorf("captures: pdftotext: %s: %w", stderr, err)
		}
		return "", fmt.Errorf("captures: pdftotext: %w", err)
	}
	text := strings.TrimSpace(out.String())
	if text == "" {
		return "", fmt.Errorf("captures: pdftotext produced no text (scanned/image-only PDF?)")
	}
	return text, nil
}

// maxLinkFetchBytes bounds how much of a linked page this reads — a personal
// capture is one article/post, never a reason to stream an unbounded body.
const maxLinkFetchBytes = 5 << 20 // 5 MB

var linkFetchClient = &http.Client{
	Timeout:   15 * time.Second,
	Transport: netguard.GuardedTransport(10 * time.Second),
}

// noRedirectPastFirstHop re-validates the SSRF denylist isn't enough on its
// own if a redirect chain is allowed to run unchecked — the guarded
// transport re-checks every dial, including ones a redirect triggers, so no
// separate CheckRedirect override is needed here; this comment exists so a
// future change to linkFetchClient doesn't accidentally drop that transport.

// FetchLinkText validates rawURL, fetches it through the SSRF-guarded
// client (internal/netguard — the same dial-time defense internal/gitlab
// uses for admin-configured URLs), and extracts its title and visible text.
func FetchLinkText(ctx context.Context, rawURL string) (title, text string, err error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", "", fmt.Errorf("captures: parse url: %w", err)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return "", "", fmt.Errorf("captures: url must be http or https")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", "", fmt.Errorf("captures: build request: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; MindForgeCaptureBot/1.0)")

	resp, err := linkFetchClient.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("captures: fetch url: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("captures: fetch url: status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxLinkFetchBytes+1))
	if err != nil {
		return "", "", fmt.Errorf("captures: read response body: %w", err)
	}

	title, text = extractHTML(bytes.NewReader(body))
	if strings.TrimSpace(text) == "" {
		return "", "", fmt.Errorf("captures: no extractable text on page")
	}
	return title, text, nil
}

// skipTextTags are elements whose text content is never part of the actual
// article — navigation chrome, scripts/styles, and embedded media metadata.
var skipTextTags = map[string]bool{
	"script": true, "style": true, "nav": true, "footer": true, "header": true,
	"noscript": true, "svg": true, "form": true, "button": true, "aside": true,
}

// extractHTML walks the parsed DOM and returns the <title> plus the visible
// text of the body, skipping chrome elements — a minimal, dependency-free
// readability pass (golang.org/x/net/html is already an indirect dependency
// via other packages; this just promotes it to direct rather than adding a
// full readability library for what is, per element, a plain text-node walk).
func extractHTML(r io.Reader) (title, text string) {
	doc, err := html.Parse(r)
	if err != nil {
		return "", ""
	}

	var sb strings.Builder
	var walk func(n *html.Node, skip bool)
	walk = func(n *html.Node, skip bool) {
		if n.Type == html.ElementNode {
			if n.Data == "title" && title == "" {
				if n.FirstChild != nil && n.FirstChild.Type == html.TextNode {
					title = strings.TrimSpace(n.FirstChild.Data)
				}
			}
			if skipTextTags[n.Data] {
				skip = true
			}
		}
		if !skip && n.Type == html.TextNode {
			t := strings.TrimSpace(n.Data)
			if t != "" {
				sb.WriteString(t)
				sb.WriteString("\n")
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c, skip)
		}
	}
	walk(doc, false)

	text = sb.String()
	if len(text) > maxLinkFetchBytes {
		text = text[:maxLinkFetchBytes]
	}
	return title, text
}

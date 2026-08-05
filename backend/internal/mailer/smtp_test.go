package mailer

import (
	"strings"
	"testing"
)

// TestBuildMessageStripsHeaderInjection guards against a caller-supplied
// Subject (e.g. a user's ticket subject) smuggling extra headers or a fake
// body via embedded CR/LF — see crlf().
func TestBuildMessageStripsHeaderInjection(t *testing.T) {
	msg := buildMessage("from@x.com", "to@x.com", "Hi\r\nBcc: evil@x.com", "body",
		map[string]string{"Message-Id": "<a@x.com>\r\nX-Injected: yes"})

	for _, line := range strings.Split(msg, "\r\n") {
		if strings.HasPrefix(line, "Bcc:") {
			t.Fatalf("subject-injected header became its own line:\n%s", msg)
		}
		if strings.HasPrefix(line, "X-Injected:") {
			t.Fatalf("header-value-injected header became its own line:\n%s", msg)
		}
	}
	if !strings.Contains(msg, "Message-Id: <a@x.com>X-Injected: yes\r\n") {
		t.Fatalf("expected sanitized Message-Id header collapsed onto one line, got:\n%s", msg)
	}
}

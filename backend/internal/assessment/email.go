package assessment

import (
	"log/slog"
	"net/smtp"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// sendEvalComplete notifies a student that their interview evaluation is ready.
// In dev mode it logs to stdout; in production it uses SMTP.
// Errors are logged and never surfaced to the caller — email is best-effort.
func sendEvalComplete(cfg *config.Config, to, name, assessmentTitle, attemptID string) {
	if !cfg.IsProd() {
		slog.Info("DEV EMAIL: eval complete", "to", to, "attempt", attemptID, "assessment", assessmentTitle)
		return
	}

	greeting := "Hi there"
	if name != "" {
		greeting = "Hi " + strings.SplitN(name, " ", 2)[0]
	}
	link := cfg.FrontendURL + "/assessments/result/" + attemptID
	body := greeting + ",\n\n" +
		"Your AI evaluation for \"" + assessmentTitle + "\" is ready.\n\n" +
		"View your score, dimension breakdown, and improvement suggestions:\n" + link +
		"\n\n— MindForge"

	addr := cfg.SMTPHost + ":" + cfg.SMTPPort
	var auth smtp.Auth
	if cfg.SMTPUser != "" {
		auth = smtp.PlainAuth("", cfg.SMTPUser, cfg.SMTPPass, cfg.SMTPHost)
	}

	var sb strings.Builder
	sb.WriteString("From: " + cfg.EmailFrom + "\r\n")
	sb.WriteString("To: " + to + "\r\n")
	sb.WriteString("Subject: Your interview evaluation is ready\r\n")
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(body)

	if err := smtp.SendMail(addr, auth, cfg.EmailFrom, []string{to}, []byte(sb.String())); err != nil {
		slog.Warn("eval: send complete email", "to", to, "attempt", attemptID, "error", err)
	}
}

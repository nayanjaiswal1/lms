package calendar

import (
	"fmt"
	"strings"
	"time"
)

const icsDateTimeLayout = "20060102T150405Z"

// BuildICS renders events as a minimal RFC 5545 VCALENDAR/VEVENT feed: UID,
// DTSTAMP, DTSTART, DTEND (when known), SUMMARY, DESCRIPTION. No alarms,
// attendees, or recurrence rules in the output — consumers (Google Calendar,
// Outlook, Apple Calendar) that subscribe to this feed only need to render
// the expanded, concrete occurrences Repo.ListRange already produced.
func BuildICS(events []Event) string {
	var sb strings.Builder
	sb.WriteString("BEGIN:VCALENDAR\r\n")
	sb.WriteString("VERSION:2.0\r\n")
	sb.WriteString("PRODID:-//MindForge//Calendar//EN\r\n")
	sb.WriteString("CALSCALE:GREGORIAN\r\n")

	now := time.Now().UTC().Format(icsDateTimeLayout)
	for i, ev := range events {
		sb.WriteString("BEGIN:VEVENT\r\n")
		sb.WriteString("UID:" + icsUID(ev, i) + "\r\n")
		sb.WriteString("DTSTAMP:" + now + "\r\n")
		sb.WriteString("DTSTART:" + ev.StartsAt.UTC().Format(icsDateTimeLayout) + "\r\n")
		if ev.EndsAt != nil {
			sb.WriteString("DTEND:" + ev.EndsAt.UTC().Format(icsDateTimeLayout) + "\r\n")
		}
		sb.WriteString("SUMMARY:" + icsEscape(ev.Title) + "\r\n")
		if ev.Notes != nil && *ev.Notes != "" {
			sb.WriteString("DESCRIPTION:" + icsEscape(*ev.Notes) + "\r\n")
		}
		sb.WriteString("STATUS:" + icsStatus(ev.Status) + "\r\n")
		sb.WriteString("END:VEVENT\r\n")
	}

	sb.WriteString("END:VCALENDAR\r\n")
	return sb.String()
}

// icsUID builds a UID unique per occurrence: recurring events share an ID
// across occurrences, so the occurrence's own start time (plus its position
// in the slice as a final tiebreaker) disambiguates them.
func icsUID(ev Event, index int) string {
	return fmt.Sprintf("%s-%d-%d@mindforge", ev.ID, ev.StartsAt.UTC().Unix(), index)
}

func icsStatus(status string) string {
	if status == EventStatusCancelled {
		return "CANCELLED"
	}
	return "CONFIRMED"
}

// icsEscape escapes the characters RFC 5545 §3.3.11 requires escaping in
// TEXT values, and folds newlines into the literal "\n" escape sequence.
func icsEscape(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, "\r\n", "\\n")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}

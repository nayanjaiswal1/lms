package tickets

import "testing"

func TestCanAccess(t *testing.T) {
	requester := "user-1"
	assignee := "user-2"
	stranger := "user-3"
	assigned := &assignee

	cases := []struct {
		name      string
		ticket    Ticket
		callerID  string
		canManage bool
		want      bool
	}{
		{"requester without manage", Ticket{RequesterID: requester}, requester, false, true},
		{"manage holder, not requester", Ticket{RequesterID: requester}, stranger, true, true},
		{"assignee without manage", Ticket{RequesterID: requester, AssignedTo: assigned}, assignee, false, true},
		{"stranger without manage", Ticket{RequesterID: requester, AssignedTo: assigned}, stranger, false, false},
		{"stranger, unassigned ticket", Ticket{RequesterID: requester}, stranger, false, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := canAccess(c.ticket, c.callerID, c.canManage); got != c.want {
				t.Errorf("canAccess() = %v, want %v", got, c.want)
			}
		})
	}
}

func TestIsValidStatus(t *testing.T) {
	cases := []struct {
		kind, status string
		want         bool
	}{
		{KindSupport, StatusOpen, true},
		{KindSupport, StatusInProgress, true},
		{KindSupport, StatusResolved, true},
		{KindSupport, StatusClosed, true},
		{KindSupport, StatusAssigned, false}, // mentorship-only status
		{KindMentorship, StatusOpen, true},
		{KindMentorship, StatusAssigned, true},
		{KindMentorship, StatusClosed, true},
		{KindMentorship, StatusInProgress, false}, // support-only status
		{KindMentorship, StatusResolved, false},   // support-only status
		{"bogus", StatusOpen, false},
	}
	for _, c := range cases {
		if got := IsValidStatus(c.kind, c.status); got != c.want {
			t.Errorf("IsValidStatus(%q, %q) = %v, want %v", c.kind, c.status, got, c.want)
		}
	}
}

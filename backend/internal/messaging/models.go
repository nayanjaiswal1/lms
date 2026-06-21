package messaging

import "time"

type MessageType string

const (
	TypeQuestion     MessageType = "question"
	TypeAnswer       MessageType = "answer"
	TypeAnnouncement MessageType = "announcement"
	TypeResource     MessageType = "resource"
)

type Reaction string

const (
	ReactionUpvote  Reaction = "upvote"
	ReactionHelpful Reaction = "helpful"
)

type BatchMessage struct {
	ID         string         `json:"id"`
	BatchID    string         `json:"batch_id"`
	SenderID   string         `json:"sender_id"`
	SenderName string         `json:"sender_name"`
	ParentID   *string        `json:"parent_id"`
	Body       string         `json:"body"`
	Type       MessageType    `json:"type"`
	IsPinned   bool           `json:"is_pinned"`
	IsResolved bool           `json:"is_resolved"`
	EditedAt   *time.Time     `json:"edited_at"`
	CreatedAt  time.Time      `json:"created_at"`
	Reactions  []ReactionCount `json:"reactions"`
	ReplyCount int            `json:"reply_count"`
}

type ReactionCount struct {
	Reaction    Reaction `json:"reaction"`
	Count       int      `json:"count"`
	UserReacted bool     `json:"user_reacted"`
}

type CourseFAQ struct {
	ID              string    `json:"id"`
	CourseID        string    `json:"course_id"`
	OrgID           string    `json:"org_id"`
	Question        string    `json:"question"`
	Answer          string    `json:"answer"`
	AIGenerated     bool      `json:"ai_generated"`
	SourceMessageID *string   `json:"source_message_id"`
	Position        int       `json:"position"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type ListMessagesFilter struct {
	Before     string
	Limit      int
	Type       string
	Unresolved bool
	Pinned     bool
}

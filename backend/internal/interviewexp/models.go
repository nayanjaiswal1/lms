package interviewexp

import "time"

// Post is a company/position-tagged interview experience thread. Unlike
// every other domain table, this carries no org_id — content is
// platform-wide (see docs/interview-experiences.md); reads are never
// filtered by tenant, only writes require an authenticated member.
type Post struct {
	ID        string    `json:"id"`
	AuthorID  string    `json:"author_id"`
	Company   string    `json:"company"`
	Position  string    `json:"position"`
	Tags      []string  `json:"tags"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Entry is one round/continuation added to a post — by the original author
// or anyone else who interviewed for the same role. Optional: a post can
// carry zero entries and just have standalone Q&A (see Qna.EntryID).
type Entry struct {
	ID         string    `json:"id"`
	PostID     string    `json:"post_id"`
	AuthorID   string    `json:"author_id"`
	RoundLabel string    `json:"round_label"`
	Content    string    `json:"content"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// Qna is one question (+ optional answer). EntryID nil means it's a
// standalone question on the post, not tied to a specific round.
type Qna struct {
	ID        string    `json:"id"`
	PostID    string    `json:"post_id"`
	EntryID   *string   `json:"entry_id,omitempty"`
	AuthorID  string    `json:"author_id"`
	Question  string    `json:"question"`
	Answer    *string   `json:"answer,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Score     int       `json:"score"`
	MyVote    int       `json:"my_vote"` // -1, 0, or 1
}

// Comment is one node of a qna's discussion thread. Nesting is unlimited
// depth via ParentID self-reference (unlike wiki_comments, which caps at
// one level — this feature was explicitly asked to nest further).
type Comment struct {
	ID        string    `json:"id"`
	QnaID     string    `json:"qna_id"`
	ParentID  *string   `json:"parent_id,omitempty"`
	AuthorID  string    `json:"author_id"`
	Content   string    `json:"content"`
	Deleted   bool      `json:"deleted"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Score     int       `json:"score"`
	MyVote    int       `json:"my_vote"`
	Replies   []Comment `json:"replies"`
}

// QnaWithComments is one question thread as returned in a post detail.
type QnaWithComments struct {
	Qna
	Comments []Comment `json:"comments"`
}

// EntryWithQna is one round with the Q&A pairs scoped to it.
type EntryWithQna struct {
	Entry
	Qna []QnaWithComments `json:"qna"`
}

// PostDetail is what GET /api/interview-exp/posts/:id returns.
type PostDetail struct {
	Post
	Entries       []EntryWithQna    `json:"entries"`
	StandaloneQna []QnaWithComments `json:"standalone_qna"`
}

// ─── Request bodies ─────────────────────────────────────────────────────────

type CreatePostRequest struct {
	Company  string   `json:"company"`
	Position string   `json:"position"`
	Tags     []string `json:"tags"`
	Title    string   `json:"title"`
}

type CreateEntryRequest struct {
	RoundLabel string `json:"round_label"`
	Content    string `json:"content"`
}

type CreateQnaRequest struct {
	Question string  `json:"question"`
	Answer   *string `json:"answer"`
}

type UpdateQnaRequest struct {
	Question *string `json:"question"`
	Answer   *string `json:"answer"`
}

type CreateCommentRequest struct {
	Content  string  `json:"content"`
	ParentID *string `json:"parent_id"`
}

type UpdateCommentRequest struct {
	Content string `json:"content"`
}

type VoteRequest struct {
	TargetType string `json:"target_type"` // "qna" | "comment"
	TargetID   string `json:"target_id"`
	Value      int    `json:"value"` // -1, 0 (clear), or 1
}

// ListFilter narrows GET /api/interview-exp/posts.
type ListFilter struct {
	Company  *string
	Position *string
	Tag      *string
	Query    *string
}

// FaqItem is one row of the cross-post /api/interview-exp/faq aggregate —
// a qna joined with its parent post's company/position/tags, its vote score
// (the "frequency" signal), and the calling user's own progress. Mirrors
// sheets' ProgressStatus (todo/done/revisit) + is_starred, not its SRS
// revision-date fields — see docs/interview-experiences.md.
type FaqItem struct {
	QnaID      string    `json:"qna_id"`
	PostID     string    `json:"post_id"`
	Question   string    `json:"question"`
	Answer     *string   `json:"answer,omitempty"`
	Company    string    `json:"company"`
	Position   string    `json:"position"`
	Tags       []string  `json:"tags"`
	Score      int       `json:"score"`
	Status     string    `json:"status"` // "todo" | "done" | "revisit"
	IsStarred  bool      `json:"is_starred"`
	CreatedAt  time.Time `json:"created_at"`
}

// FaqFilter narrows GET /api/interview-exp/faq.
type FaqFilter struct {
	Company *string
	Tag     *string
	Status  *string
}

type UpdateFaqStatusRequest struct {
	Status string `json:"status"`
}

type UpdateFaqStarredRequest struct {
	Starred bool `json:"starred"`
}

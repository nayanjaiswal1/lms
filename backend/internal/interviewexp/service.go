package interviewexp

import (
	"context"
	"errors"
	"strings"

	"github.com/mindforge/backend/internal/middleware"
)

var (
	ErrForbidden  = errors.New("interviewexp: forbidden")
	ErrValidation = errors.New("interviewexp: validation failed")
)

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// ─── Posts ────────────────────────────────────────────────────────────────────

func (s *Service) ListPosts(ctx context.Context, f ListFilter) ([]Post, error) {
	return s.repo.ListPosts(ctx, f)
}

func (s *Service) CreatePost(ctx context.Context, userID string, req CreatePostRequest) (Post, error) {
	company := strings.TrimSpace(req.Company)
	position := strings.TrimSpace(req.Position)
	title := strings.TrimSpace(req.Title)
	if company == "" || position == "" || title == "" {
		return Post{}, ErrValidation
	}
	return s.repo.CreatePost(ctx, userID, company, position, title, normalizeTags(req.Tags))
}

// GetPostDetail assembles the full thread: entries with their Q&A, standalone
// Q&A, each Q&A's nested comment tree, and vote scores — in a fixed number
// of queries regardless of thread size (no N+1).
func (s *Service) GetPostDetail(ctx context.Context, userID, postID string) (PostDetail, error) {
	post, err := s.repo.GetPost(ctx, postID)
	if err != nil {
		return PostDetail{}, err
	}
	entries, err := s.repo.ListEntries(ctx, postID)
	if err != nil {
		return PostDetail{}, err
	}
	allQna, err := s.repo.ListQnaByPost(ctx, postID)
	if err != nil {
		return PostDetail{}, err
	}

	qnaIDs := make([]string, len(allQna))
	for i, q := range allQna {
		qnaIDs[i] = q.ID
	}
	comments, err := s.repo.ListCommentsByQnaIDs(ctx, qnaIDs)
	if err != nil {
		return PostDetail{}, err
	}
	commentIDs := make([]string, len(comments))
	for i, c := range comments {
		commentIDs[i] = c.ID
	}

	qnaScores, qnaMine, err := s.repo.VoteScores(ctx, "qna", qnaIDs, userID)
	if err != nil {
		return PostDetail{}, err
	}
	commentScores, commentMine, err := s.repo.VoteScores(ctx, "comment", commentIDs, userID)
	if err != nil {
		return PostDetail{}, err
	}
	for i := range comments {
		comments[i].Score = commentScores[comments[i].ID]
		comments[i].MyVote = commentMine[comments[i].ID]
	}

	commentsByQna := map[string][]Comment{}
	for _, c := range comments {
		commentsByQna[c.QnaID] = append(commentsByQna[c.QnaID], c)
	}

	qnaByEntry := map[string][]QnaWithComments{}
	standalone := []QnaWithComments{}
	for _, q := range allQna {
		q.Score = qnaScores[q.ID]
		q.MyVote = qnaMine[q.ID]
		withComments := QnaWithComments{Qna: q, Comments: buildCommentTree(commentsByQna[q.ID])}
		if q.EntryID == nil {
			standalone = append(standalone, withComments)
			continue
		}
		qnaByEntry[*q.EntryID] = append(qnaByEntry[*q.EntryID], withComments)
	}

	entriesOut := make([]EntryWithQna, len(entries))
	for i, e := range entries {
		qna := qnaByEntry[e.ID]
		if qna == nil {
			qna = []QnaWithComments{}
		}
		entriesOut[i] = EntryWithQna{Entry: e, Qna: qna}
	}

	return PostDetail{Post: post, Entries: entriesOut, StandaloneQna: standalone}, nil
}

// buildCommentTree groups a flat, already-scored list of one qna's comments
// into a reply tree of unlimited depth.
func buildCommentTree(flat []Comment) []Comment {
	byParent := map[string][]Comment{}
	for _, c := range flat {
		key := ""
		if c.ParentID != nil {
			key = *c.ParentID
		}
		byParent[key] = append(byParent[key], c)
	}
	var attach func(parentKey string) []Comment
	attach = func(parentKey string) []Comment {
		children := byParent[parentKey]
		out := make([]Comment, 0, len(children))
		for _, c := range children {
			c.Replies = attach(c.ID)
			out = append(out, c)
		}
		return out
	}
	return attach("")
}

// ─── Entries ──────────────────────────────────────────────────────────────────

// CreateEntry lets any authenticated member continue a post with another
// round — not just the original author (docs/interview-experiences.md
// "continue add exp").
func (s *Service) CreateEntry(ctx context.Context, userID, postID string, req CreateEntryRequest) (Entry, error) {
	if _, err := s.repo.GetPost(ctx, postID); err != nil {
		return Entry{}, err
	}
	label := strings.TrimSpace(req.RoundLabel)
	content := strings.TrimSpace(req.Content)
	if label == "" || content == "" {
		return Entry{}, ErrValidation
	}
	return s.repo.CreateEntry(ctx, postID, userID, label, content)
}

// ─── Qna ──────────────────────────────────────────────────────────────────────

func (s *Service) CreateStandaloneQna(ctx context.Context, userID, postID string, req CreateQnaRequest) (Qna, error) {
	if _, err := s.repo.GetPost(ctx, postID); err != nil {
		return Qna{}, err
	}
	return s.createQna(ctx, postID, nil, userID, req)
}

func (s *Service) CreateEntryQna(ctx context.Context, userID, entryID string, req CreateQnaRequest) (Qna, error) {
	entry, err := s.repo.GetEntry(ctx, entryID)
	if err != nil {
		return Qna{}, err
	}
	return s.createQna(ctx, entry.PostID, &entryID, userID, req)
}

func (s *Service) createQna(ctx context.Context, postID string, entryID *string, userID string, req CreateQnaRequest) (Qna, error) {
	question := strings.TrimSpace(req.Question)
	if question == "" {
		return Qna{}, ErrValidation
	}
	var answer *string
	if req.Answer != nil {
		trimmed := strings.TrimSpace(*req.Answer)
		if trimmed != "" {
			answer = &trimmed
		}
	}
	return s.repo.CreateQna(ctx, postID, entryID, userID, question, answer)
}

func (s *Service) UpdateQna(ctx context.Context, userID, orgRole, id string, req UpdateQnaRequest) (Qna, error) {
	q, err := s.repo.GetQna(ctx, id)
	if err != nil {
		return Qna{}, err
	}
	if q.AuthorID != userID && orgRole != middleware.RoleAdmin {
		return Qna{}, ErrForbidden
	}
	if req.Question != nil && strings.TrimSpace(*req.Question) == "" {
		return Qna{}, ErrValidation
	}
	return s.repo.UpdateQna(ctx, id, req.Question, req.Answer)
}

func (s *Service) DeleteQna(ctx context.Context, userID, orgRole, id string) error {
	q, err := s.repo.GetQna(ctx, id)
	if err != nil {
		return err
	}
	if q.AuthorID != userID && orgRole != middleware.RoleAdmin {
		return ErrForbidden
	}
	return s.repo.DeleteQna(ctx, id)
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func (s *Service) CreateComment(ctx context.Context, userID, qnaID string, req CreateCommentRequest) (Comment, error) {
	if _, err := s.repo.GetQna(ctx, qnaID); err != nil {
		return Comment{}, err
	}
	if req.ParentID != nil {
		parent, err := s.repo.GetComment(ctx, *req.ParentID)
		if err != nil {
			return Comment{}, err
		}
		if parent.QnaID != qnaID {
			return Comment{}, ErrValidation
		}
	}
	content := strings.TrimSpace(req.Content)
	if content == "" {
		return Comment{}, ErrValidation
	}
	return s.repo.CreateComment(ctx, qnaID, userID, content, req.ParentID)
}

func (s *Service) UpdateComment(ctx context.Context, userID, id, content string) (Comment, error) {
	c, err := s.repo.GetComment(ctx, id)
	if err != nil {
		return Comment{}, err
	}
	if c.AuthorID != userID {
		return Comment{}, ErrForbidden
	}
	trimmed := strings.TrimSpace(content)
	if trimmed == "" {
		return Comment{}, ErrValidation
	}
	return s.repo.UpdateComment(ctx, id, trimmed)
}

func (s *Service) DeleteComment(ctx context.Context, userID, orgRole, id string) error {
	c, err := s.repo.GetComment(ctx, id)
	if err != nil {
		return err
	}
	if c.AuthorID != userID && orgRole != middleware.RoleAdmin {
		return ErrForbidden
	}
	return s.repo.DeleteComment(ctx, id)
}

// ─── Votes ────────────────────────────────────────────────────────────────────

func (s *Service) Vote(ctx context.Context, userID string, req VoteRequest) error {
	if req.Value < -1 || req.Value > 1 {
		return ErrValidation
	}
	switch req.TargetType {
	case "qna":
		if _, err := s.repo.GetQna(ctx, req.TargetID); err != nil {
			return err
		}
	case "comment":
		if _, err := s.repo.GetComment(ctx, req.TargetID); err != nil {
			return err
		}
	default:
		return ErrValidation
	}
	return s.repo.Vote(ctx, userID, req.TargetType, req.TargetID, req.Value)
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────

var validFaqStatuses = map[string]struct{}{"todo": {}, "done": {}, "revisit": {}}

func (s *Service) ListFaq(ctx context.Context, userID string, f FaqFilter) ([]FaqItem, error) {
	return s.repo.ListFaq(ctx, userID, f)
}

func (s *Service) UpdateFaqStatus(ctx context.Context, userID, qnaID, status string) error {
	if _, ok := validFaqStatuses[status]; !ok {
		return ErrValidation
	}
	if _, err := s.repo.GetQna(ctx, qnaID); err != nil {
		return err
	}
	return s.repo.UpsertFaqStatus(ctx, userID, qnaID, status)
}

func (s *Service) UpdateFaqStarred(ctx context.Context, userID, qnaID string, starred bool) error {
	if _, err := s.repo.GetQna(ctx, qnaID); err != nil {
		return err
	}
	return s.repo.UpsertFaqStarred(ctx, userID, qnaID, starred)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// normalizeTags trims, lowercases, and drops blanks so tag filtering
// (exact array membership) matches consistently regardless of input casing.
func normalizeTags(tags []string) []string {
	out := make([]string, 0, len(tags))
	for _, t := range tags {
		t = strings.ToLower(strings.TrimSpace(t))
		if t != "" {
			out = append(out, t)
		}
	}
	return out
}

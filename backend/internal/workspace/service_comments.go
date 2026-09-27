package workspace

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/pagination"
)

// service_comments.go — question-thread and item-thread comments
// (contract-phase3.md: "Question comment threads reuse the existing comments
// table"). Both subjects are viewer-read / member-write with no extra role
// check beyond the route gate (StatusesDiscuss), so one shared implementation
// serves both subject types.

func (s *Service) listComments(ctx context.Context, subjectType, subjectID, cursor string, limit int) (Page[Comment], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace_comments")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListComments(ctx, s.pool, subjectType, subjectID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[Comment]{}, err
	}
	page := Page[Comment]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

func (s *Service) createComment(ctx context.Context, subjectType, subjectID, authorID string, req CreateCommentRequest) (*Comment, error) {
	content := strings.TrimSpace(req.Content)
	if len(content) < CommentMinLen || len(content) > CommentMaxLen {
		return nil, fmt.Errorf("%w: content must be %d-%d characters", ErrInvalidInput, CommentMinLen, CommentMaxLen)
	}
	return s.repo.InsertComment(ctx, s.pool, subjectType, subjectID, authorID, content, req.ParentID)
}

// ListQuestionComments/CreateQuestionComment are GET/POST
// …/questions/{questionID}/comments.
func (s *Service) ListQuestionComments(ctx context.Context, pc *ProjectCtx, questionID, cursor string, limit int) (Page[Comment], error) {
	if _, err := s.repo.GetQuestion(ctx, s.pool, pc.ProjectID, questionID); err != nil {
		return Page[Comment]{}, err
	}
	return s.listComments(ctx, "requirement_question", questionID, cursor, limit)
}

func (s *Service) CreateQuestionComment(ctx context.Context, pc *ProjectCtx, questionID string, req CreateCommentRequest) (*Comment, error) {
	if _, err := s.repo.GetQuestion(ctx, s.pool, pc.ProjectID, questionID); err != nil {
		return nil, err
	}
	return s.createComment(ctx, "requirement_question", questionID, pc.UserID, req)
}

// ListItemComments/CreateItemComment are GET/POST …/items/{itemID}/comments.
func (s *Service) ListItemComments(ctx context.Context, pc *ProjectCtx, itemRef, cursor string, limit int) (Page[Comment], error) {
	item, err := s.resolveItemRef(ctx, s.pool, pc.ProjectID, itemRef)
	if err != nil {
		return Page[Comment]{}, err
	}
	return s.listComments(ctx, "work_item", item.ID, cursor, limit)
}

func (s *Service) CreateItemComment(ctx context.Context, pc *ProjectCtx, itemRef string, req CreateCommentRequest) (*Comment, error) {
	item, err := s.resolveItemRef(ctx, s.pool, pc.ProjectID, itemRef)
	if err != nil {
		return nil, err
	}
	return s.createComment(ctx, "work_item", item.ID, pc.UserID, req)
}

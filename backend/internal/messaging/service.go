package messaging

import (
	"context"
	"fmt"
	"regexp"
)

var htmlTag = regexp.MustCompile(`<[^>]*>`)

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

func (s *Service) PostMessage(ctx context.Context, orgID, batchID, senderID, body string, msgType MessageType, parentID *string) (BatchMessage, error) {
	if len(body) == 0 || len(body) > 5000 {
		return BatchMessage{}, fmt.Errorf("%w: body must be 1–5000 characters", ErrForbidden)
	}
	if msgType == "" {
		msgType = TypeQuestion
	}
	return s.repo.CreateMessage(ctx, orgID, batchID, senderID, body, msgType, parentID)
}

func (s *Service) EditMessage(ctx context.Context, orgID, msgID, senderID, body string) (BatchMessage, error) {
	if len(body) == 0 || len(body) > 5000 {
		return BatchMessage{}, fmt.Errorf("%w: body must be 1–5000 characters", ErrForbidden)
	}
	return s.repo.UpdateMessage(ctx, orgID, msgID, senderID, body)
}

func (s *Service) DeleteMessage(ctx context.Context, orgID, msgID, userID, orgRole string) error {
	return s.repo.SoftDeleteMessage(ctx, orgID, msgID, userID, orgRole)
}

func (s *Service) React(ctx context.Context, msgID, userID string, reaction Reaction) (bool, error) {
	if reaction != ReactionUpvote && reaction != ReactionHelpful {
		return false, fmt.Errorf("%w: invalid reaction", ErrForbidden)
	}
	return s.repo.ToggleReaction(ctx, msgID, userID, reaction)
}

func (s *Service) Resolve(ctx context.Context, orgID, msgID string) error {
	return s.repo.ResolveMessage(ctx, orgID, msgID)
}

func (s *Service) Pin(ctx context.Context, orgID, msgID string) error {
	return s.repo.TogglePinMessage(ctx, orgID, msgID)
}

func (s *Service) PromoteToFAQ(ctx context.Context, orgID, courseID, msgID, createdBy, question, answer string) (CourseFAQ, error) {
	question = htmlTag.ReplaceAllString(question, "")
	answer = htmlTag.ReplaceAllString(answer, "")
	if len(question) < 10 || len(question) > 500 {
		return CourseFAQ{}, fmt.Errorf("%w: question must be 10–500 characters", ErrForbidden)
	}
	if len(answer) < 10 || len(answer) > 5000 {
		return CourseFAQ{}, fmt.Errorf("%w: answer must be 10–5000 characters", ErrForbidden)
	}
	return s.repo.PromoteToFAQ(ctx, orgID, courseID, msgID, createdBy, question, answer)
}

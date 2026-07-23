package wiki

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/middleware"
)

var (
	ErrForbidden       = errors.New("wiki: forbidden")
	ErrValidation      = errors.New("wiki: validation failed")
	ErrCourseNotFound  = errors.New("wiki: course not found")
	ErrTemplateInvalid = errors.New("wiki: template not accessible")
)

// emptyDoc is a minimal valid TipTap/ProseMirror document — used as a new
// page's starting content when no template is supplied. An actually-empty
// `{}` is not a document TipTap can load.
var emptyDoc = json.RawMessage(`{"type":"doc","content":[{"type":"paragraph"}]}`)

type Service struct {
	repo        *Repo
	coursesRepo *courses.Repo
}

func NewService(repo *Repo, coursesRepo *courses.Repo) *Service {
	return &Service{repo: repo, coursesRepo: coursesRepo}
}

func isManager(orgRole string) bool {
	return orgRole == middleware.RoleAdmin || orgRole == middleware.RoleInstructor || orgRole == middleware.RoleMentor
}

func canCreateSpace(orgRole string) bool {
	return orgRole == middleware.RoleAdmin || orgRole == middleware.RoleInstructor
}

// canEditPage mirrors docs/wiki.md's permission table: admin edits any page,
// instructor/mentor only pages they created, students never.
func canEditPage(orgRole, userID string, p Page) bool {
	if orgRole == middleware.RoleAdmin {
		return true
	}
	if orgRole == middleware.RoleInstructor || orgRole == middleware.RoleMentor {
		return p.CreatedBy == userID
	}
	return false
}

// ─── Spaces ───────────────────────────────────────────────────────────────────

// ListSpaces hides course-linked spaces from students not enrolled in that
// course — org-wide spaces (CourseID nil) are visible to every org member.
func (s *Service) ListSpaces(ctx context.Context, orgID, userID, orgRole string) ([]Space, error) {
	all, err := s.repo.ListSpaces(ctx, orgID)
	if err != nil {
		return nil, err
	}
	if isManager(orgRole) {
		return all, nil
	}
	out := make([]Space, 0, len(all))
	for _, sp := range all {
		visible, err := s.canReadSpace(ctx, orgRole, userID, sp)
		if err != nil {
			return nil, err
		}
		if visible {
			out = append(out, sp)
		}
	}
	return out, nil
}

func (s *Service) canReadSpace(ctx context.Context, orgRole, userID string, sp Space) (bool, error) {
	if sp.CourseID == nil || isManager(orgRole) {
		return true, nil
	}
	enrolled, err := s.coursesRepo.IsEnrolled(ctx, userID, *sp.CourseID)
	if err != nil {
		return false, fmt.Errorf("wiki: check enrollment: %w", err)
	}
	return enrolled, nil
}

func (s *Service) CreateSpace(ctx context.Context, orgID, userID, orgRole string, req CreateSpaceRequest) (Space, error) {
	if !canCreateSpace(orgRole) {
		return Space{}, ErrForbidden
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return Space{}, ErrValidation
	}
	visibility := req.Visibility
	if visibility == "" {
		visibility = "members"
	}
	if req.CourseID != nil {
		if _, err := s.coursesRepo.GetCourse(ctx, orgID, *req.CourseID); err != nil {
			if errors.Is(err, courses.ErrNotFound) {
				return Space{}, ErrCourseNotFound
			}
			return Space{}, fmt.Errorf("wiki: load course: %w", err)
		}
	}
	slug := courses.Slugify(name)
	return s.repo.CreateSpace(ctx, orgID, name, slug, req.Description, req.Icon, req.CourseID, visibility, userID)
}

func (s *Service) GetSpace(ctx context.Context, orgID, userID, orgRole, slug string) (SpaceWithTree, error) {
	sp, err := s.repo.GetSpaceBySlug(ctx, orgID, slug)
	if err != nil {
		return SpaceWithTree{}, err
	}
	visible, err := s.canReadSpace(ctx, orgRole, userID, sp)
	if err != nil {
		return SpaceWithTree{}, err
	}
	if !visible {
		return SpaceWithTree{}, ErrForbidden
	}
	tree, err := s.repo.GetPageTree(ctx, sp.ID)
	if err != nil {
		return SpaceWithTree{}, err
	}
	if !isManager(orgRole) {
		tree = filterPublished(tree)
	}
	return SpaceWithTree{Space: sp, Tree: tree}, nil
}

// filterPublished drops draft pages from a tree shown to students — instructors
// and above see drafts so they can finish writing them.
func filterPublished(nodes []PageTreeNode) []PageTreeNode {
	out := []PageTreeNode{}
	for _, n := range nodes {
		n.Children = filterPublished(n.Children)
		if n.Status == "published" || len(n.Children) > 0 {
			out = append(out, n)
		}
	}
	return out
}

// GetPageTree returns just the tree for a space already resolved to an ID
// (the sidebar re-fetches this after a page create/move without re-fetching
// the whole space+tree payload GetSpace returns).
func (s *Service) GetPageTree(ctx context.Context, orgID, userID, orgRole, spaceID string) ([]PageTreeNode, error) {
	sp, err := s.repo.GetSpaceByID(ctx, orgID, spaceID)
	if err != nil {
		return nil, err
	}
	visible, err := s.canReadSpace(ctx, orgRole, userID, sp)
	if err != nil {
		return nil, err
	}
	if !visible {
		return nil, ErrForbidden
	}
	tree, err := s.repo.GetPageTree(ctx, sp.ID)
	if err != nil {
		return nil, err
	}
	if !isManager(orgRole) {
		tree = filterPublished(tree)
	}
	return tree, nil
}

func (s *Service) UpdateSpace(ctx context.Context, orgID, userID, orgRole, id string, req UpdateSpaceRequest) (Space, error) {
	sp, err := s.repo.GetSpaceByID(ctx, orgID, id)
	if err != nil {
		return Space{}, err
	}
	if orgRole != middleware.RoleAdmin && sp.CreatedBy != userID {
		return Space{}, ErrForbidden
	}
	return s.repo.UpdateSpace(ctx, orgID, id, req)
}

// DeleteSpace is additionally gated at the route layer to admin-only via
// middleware.RequireOrgRole — this check is defense in depth.
func (s *Service) DeleteSpace(ctx context.Context, orgID, orgRole, id string) error {
	if orgRole != middleware.RoleAdmin {
		return ErrForbidden
	}
	return s.repo.DeleteSpace(ctx, orgID, id)
}

// ─── Pages ────────────────────────────────────────────────────────────────────

func (s *Service) CreatePage(ctx context.Context, orgID, userID, orgRole, spaceID string, req CreatePageRequest) (Page, error) {
	if !isManager(orgRole) {
		return Page{}, ErrForbidden
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return Page{}, ErrValidation
	}
	if _, err := s.repo.GetSpaceByID(ctx, orgID, spaceID); err != nil {
		return Page{}, err
	}

	content := emptyDoc
	if req.TemplateID != nil {
		tpl, err := s.repo.GetTemplate(ctx, *req.TemplateID)
		if err != nil {
			return Page{}, err
		}
		if tpl.OrgID != nil && *tpl.OrgID != orgID {
			return Page{}, ErrTemplateInvalid
		}
		content = tpl.Content
	}

	slug := courses.Slugify(title)
	searchText := extractText(content)
	return s.repo.CreatePage(ctx, spaceID, title, slug, req.ParentID, req.Emoji, content, searchText, userID)
}

func (s *Service) GetPage(ctx context.Context, orgID, userID, orgRole, id string) (PageDetail, error) {
	p, err := s.repo.GetPage(ctx, orgID, id)
	if err != nil {
		return PageDetail{}, err
	}
	sp, err := s.repo.GetSpaceByID(ctx, orgID, p.SpaceID)
	if err != nil {
		return PageDetail{}, err
	}
	visible, err := s.canReadSpace(ctx, orgRole, userID, sp)
	if err != nil {
		return PageDetail{}, err
	}
	if !visible || (p.Status != "published" && !isManager(orgRole)) {
		return PageDetail{}, ErrForbidden
	}
	breadcrumb, err := s.repo.GetBreadcrumb(ctx, id)
	if err != nil {
		return PageDetail{}, err
	}
	return PageDetail{Page: p, SpaceSlug: sp.Slug, SpaceName: sp.Name, Breadcrumb: breadcrumb}, nil
}

func (s *Service) UpdatePage(ctx context.Context, orgID, userID, orgRole, id string, req UpdatePageRequest) (Page, error) {
	existing, err := s.repo.GetPage(ctx, orgID, id)
	if err != nil {
		return Page{}, err
	}
	if !canEditPage(orgRole, userID, existing) {
		return Page{}, ErrForbidden
	}
	if req.Title != nil && strings.TrimSpace(*req.Title) == "" {
		return Page{}, ErrValidation
	}

	var searchText *string
	if req.Content != nil {
		t := extractText(*req.Content)
		searchText = &t
	}
	return s.repo.UpdatePage(ctx, orgID, id, req.Title, req.Content, searchText, req.Status, req.Emoji, req.ParentID, req.OrderIndex, userID)
}

func (s *Service) MovePage(ctx context.Context, orgID, userID, orgRole, id string, req MovePageRequest) (Page, error) {
	existing, err := s.repo.GetPage(ctx, orgID, id)
	if err != nil {
		return Page{}, err
	}
	if !canEditPage(orgRole, userID, existing) {
		return Page{}, ErrForbidden
	}
	return s.repo.MovePage(ctx, orgID, id, req.ParentID, req.OrderIndex)
}

func (s *Service) DeletePage(ctx context.Context, orgID, userID, orgRole, id string) error {
	existing, err := s.repo.GetPage(ctx, orgID, id)
	if err != nil {
		return err
	}
	if !canEditPage(orgRole, userID, existing) {
		return ErrForbidden
	}
	return s.repo.DeletePage(ctx, orgID, id)
}

// ─── Version history ─────────────────────────────────────────────────────────

func (s *Service) ListVersions(ctx context.Context, orgID, userID, orgRole, pageID string) ([]PageVersionSummary, error) {
	if _, err := s.GetPage(ctx, orgID, userID, orgRole, pageID); err != nil {
		return nil, err
	}
	return s.repo.ListVersions(ctx, pageID)
}

func (s *Service) GetVersion(ctx context.Context, orgID, userID, orgRole, pageID string, version int) (PageVersionDetail, error) {
	if _, err := s.GetPage(ctx, orgID, userID, orgRole, pageID); err != nil {
		return PageVersionDetail{}, err
	}
	return s.repo.GetVersion(ctx, pageID, version)
}

// RestoreVersion copies an old version's content back onto the live page —
// itself a content change, so it goes through UpdatePage and appends yet
// another version row rather than rewriting history.
func (s *Service) RestoreVersion(ctx context.Context, orgID, userID, orgRole, pageID string, version int) (Page, error) {
	existing, err := s.repo.GetPage(ctx, orgID, pageID)
	if err != nil {
		return Page{}, err
	}
	if !canEditPage(orgRole, userID, existing) {
		return Page{}, ErrForbidden
	}
	v, err := s.repo.GetVersion(ctx, pageID, version)
	if err != nil {
		return Page{}, err
	}
	searchText := extractText(v.Content)
	content := v.Content
	return s.repo.UpdatePage(ctx, orgID, pageID, &v.Title, &content, &searchText, nil, nil, nil, nil, userID)
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func (s *Service) ListComments(ctx context.Context, orgID, userID, orgRole, pageID string) ([]CommentThread, error) {
	if _, err := s.GetPage(ctx, orgID, userID, orgRole, pageID); err != nil {
		return nil, err
	}
	return s.repo.ListComments(ctx, pageID)
}

func (s *Service) CreateComment(ctx context.Context, orgID, userID, orgRole, pageID string, req CreateCommentRequest) (Comment, error) {
	if _, err := s.GetPage(ctx, orgID, userID, orgRole, pageID); err != nil {
		return Comment{}, err
	}
	content := strings.TrimSpace(req.Content)
	if content == "" {
		return Comment{}, ErrValidation
	}
	return s.repo.CreateComment(ctx, pageID, userID, content, req.ParentID)
}

func (s *Service) UpdateComment(ctx context.Context, userID, orgRole, id, content string) (Comment, error) {
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

// ─── Templates ────────────────────────────────────────────────────────────────

func (s *Service) ListTemplates(ctx context.Context, orgID string) ([]Template, error) {
	return s.repo.ListTemplates(ctx, orgID)
}

func (s *Service) CreateTemplate(ctx context.Context, orgID, userID, orgRole string, req CreateTemplateRequest) (Template, error) {
	if !isManager(orgRole) {
		return Template{}, ErrForbidden
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return Template{}, ErrValidation
	}
	return s.repo.CreateTemplate(ctx, orgID, name, req.Description, req.Content, userID)
}

func (s *Service) DeleteTemplate(ctx context.Context, orgID, userID, orgRole, id string) error {
	tpl, err := s.repo.GetTemplate(ctx, id)
	if err != nil {
		return err
	}
	if tpl.OrgID == nil || *tpl.OrgID != orgID {
		return ErrForbidden // platform template, or another org's — not deletable here
	}
	isCreator := tpl.CreatedBy != nil && *tpl.CreatedBy == userID
	if orgRole != middleware.RoleAdmin && !isCreator {
		return ErrForbidden
	}
	return s.repo.DeleteTemplate(ctx, id)
}

// ─── Search ───────────────────────────────────────────────────────────────────

func (s *Service) Search(ctx context.Context, orgID, query string, spaceSlug *string) ([]SearchResult, error) {
	q := strings.TrimSpace(query)
	if q == "" {
		return []SearchResult{}, nil
	}
	return s.repo.Search(ctx, orgID, q, spaceSlug)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

// extractText walks a TipTap/ProseMirror JSON document collecting every
// "text" leaf, for the search_text column. The schema is deliberately not
// modeled field-by-field (same treatment systemdesign gives Excalidraw's
// scene) — this only needs the text, not the formatting marks around it.
func extractText(content json.RawMessage) string {
	var node any
	if err := json.Unmarshal(content, &node); err != nil {
		return ""
	}
	var b strings.Builder
	walkText(node, &b)
	return strings.TrimSpace(b.String())
}

func walkText(node any, b *strings.Builder) {
	switch v := node.(type) {
	case map[string]any:
		if t, ok := v["text"].(string); ok {
			b.WriteString(t)
			b.WriteString(" ")
		}
		if children, ok := v["content"].([]any); ok {
			for _, c := range children {
				walkText(c, b)
			}
		}
	case []any:
		for _, c := range v {
			walkText(c, b)
		}
	}
}

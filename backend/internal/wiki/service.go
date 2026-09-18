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
	comments, err := s.repo.ListComments(ctx, id)
	if err != nil {
		return PageDetail{}, err
	}
	return PageDetail{Page: p, SpaceSlug: sp.Slug, SpaceName: sp.Name, Breadcrumb: breadcrumb, Comments: comments}, nil
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
	return s.repo.UpdatePage(ctx, orgID, id, req.Title, req.Content, searchText, req.Status, req.Emoji, req.ParentID, req.OrderIndex, req.OKFMetadata, userID)
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
	return s.repo.UpdatePage(ctx, orgID, pageID, &v.Title, &content, &searchText, nil, nil, nil, nil, nil, userID)
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

// ─── Similarity (duplicate detection) ──────────────────────────────────────────

// similarityThreshold/similarityLimit match the defaults captures/journal/
// messaging already settled on for this same pg_trgm convention.
const (
	similarityThreshold = 0.3
	similarityLimit     = 5
)

// FindSimilarToPage flags other published pages that look like they cover
// the same ground as an existing page — call after creating or updating one
// so the caller (human or agent) sees likely duplicates immediately, no
// second round trip needed.
func (s *Service) FindSimilarToPage(ctx context.Context, orgID, userID, orgRole, pageID string) ([]SimilarPage, error) {
	pd, err := s.GetPage(ctx, orgID, userID, orgRole, pageID)
	if err != nil {
		return nil, err
	}
	text := pd.Title + " " + extractText(pd.Content)
	return s.repo.FindSimilarPages(ctx, orgID, &pageID, text, similarityThreshold, similarityLimit)
}

// FindSimilarByText checks freeform text (e.g. a draft title/summary before
// a page even exists) against the org's published wiki content.
func (s *Service) FindSimilarByText(ctx context.Context, orgID, text string) ([]SimilarPage, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return []SimilarPage{}, nil
	}
	return s.repo.FindSimilarPages(ctx, orgID, nil, text, similarityThreshold, similarityLimit)
}

// ─── Search ───────────────────────────────────────────────────────────────────

func (s *Service) Search(ctx context.Context, orgID, query string, spaceSlug *string) ([]SearchResult, error) {
	q := strings.TrimSpace(query)
	if q == "" {
		return []SearchResult{}, nil
	}
	return s.repo.Search(ctx, orgID, q, spaceSlug)
}

// ─── OKF export/import (SPEC.md) ───────────────────────────────────────────

// GetPageOKF renders one page as an OKF v0.2 concept document. generated.by
// defaults to the human who last touched the native wiki row; a page last
// written through UpdatePageOKF (e.g. by the MCP connector) carries its own
// producer-declared `generated` in okf_metadata, which ToOKFMarkdown
// honors instead of this default.
func (s *Service) GetPageOKF(ctx context.Context, orgID, userID, orgRole, id string) (string, error) {
	pd, err := s.GetPage(ctx, orgID, userID, orgRole, id)
	if err != nil {
		return "", err
	}
	actor := ActorForUser(pd.CreatedBy)
	if pd.UpdatedBy != nil {
		actor = ActorForUser(*pd.UpdatedBy)
	}
	return ToOKFMarkdown(pd.Page, pd.Breadcrumb, actor, nil)
}

// UpdatePageOKF parses an OKF concept document and applies it through the
// same UpdatePage path (and so the same RBAC/versioning) a native TipTap
// PATCH would use. The submitted frontmatter's `generated`/`sources`/
// `verified`/etc. are preserved verbatim in okf_metadata (see
// FromOKFMarkdown) — callers that want the edit attributed to an agent
// rather than the calling user set `generated.by` in the markdown they PUT.
func (s *Service) UpdatePageOKF(ctx context.Context, orgID, userID, orgRole, id, markdown string) (Page, error) {
	title, status, okfMeta, content, err := FromOKFMarkdown(markdown)
	if err != nil {
		return Page{}, fmt.Errorf("%w: %s", ErrValidation, err)
	}
	stamped, err := StampGenerated(okfMeta, ActorForUser(userID))
	if err != nil {
		return Page{}, fmt.Errorf("%w: %s", ErrValidation, err)
	}
	req := UpdatePageRequest{Content: &content, OKFMetadata: &stamped, Status: status}
	if title != "" {
		req.Title = &title
	}
	return s.UpdatePage(ctx, orgID, userID, orgRole, id, req)
}

// GetSpaceOKFBundle renders every page a caller can read in a space as an
// OKF bundle: one .md file per page (path = slug.md, flat — page nesting is
// carried by index.md's structure per SPEC.md §8, not by subdirectories),
// plus a bundle index.md and log.md. Returned as a filename->content map so
// the caller can zip it however it likes.
func (s *Service) GetSpaceOKFBundle(ctx context.Context, orgID, userID, orgRole, slug string) (map[string]string, error) {
	swt, err := s.GetSpace(ctx, orgID, userID, orgRole, slug)
	if err != nil {
		return nil, err
	}
	flat := flattenTree(swt.Tree)

	// ponytail: link resolution is a substring match on page id against the
	// href, not a parse of the app's internal-link URL scheme — good enough
	// while that scheme is a single, uninspected convention; tighten if it
	// ever produces a false match.
	slugByID := map[string]string{}
	for _, n := range flat {
		slugByID[n.ID] = okfFilename(n.Slug)
	}
	resolveLink := func(href string) string {
		for id, path := range slugByID {
			if strings.Contains(href, id) {
				return path
			}
		}
		return href
	}

	files := map[string]string{}
	pages := make([]Page, 0, len(flat))
	for _, n := range flat {
		p, err := s.repo.GetPage(ctx, orgID, n.ID)
		if err != nil {
			return nil, err
		}
		breadcrumb, err := s.repo.GetBreadcrumb(ctx, n.ID)
		if err != nil {
			return nil, err
		}
		actor := ActorForUser(p.CreatedBy)
		if p.UpdatedBy != nil {
			actor = ActorForUser(*p.UpdatedBy)
		}
		md, err := ToOKFMarkdown(p, breadcrumb, actor, resolveLink)
		if err != nil {
			return nil, err
		}
		files[okfFilename(n.Slug)] = md
		pages = append(pages, p)
	}
	files["index.md"] = BuildOKFIndex(swt.Space.Name, swt.Tree)
	files["log.md"] = BuildOKFLog(pages)
	return files, nil
}

func flattenTree(nodes []PageTreeNode) []PageTreeNode {
	var out []PageTreeNode
	for _, n := range nodes {
		out = append(out, n)
		out = append(out, flattenTree(n.Children)...)
	}
	return out
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

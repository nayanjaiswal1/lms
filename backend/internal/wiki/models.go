package wiki

import (
	"encoding/json"
	"time"
)

// Space is a topic container for a tree of pages — either org-wide
// (CourseID nil) or scoped to one course ("Course Docs").
type Space struct {
	ID          string    `json:"id"`
	OrgID       string    `json:"org_id"`
	CourseID    *string   `json:"course_id,omitempty"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description *string   `json:"description,omitempty"`
	Icon        *string   `json:"icon,omitempty"`
	Visibility  string    `json:"visibility"` // "members" | "public"
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// SpaceWithTree is what GET /api/wiki/spaces/:slug returns — space metadata
// plus the full nested page tree in one round trip.
type SpaceWithTree struct {
	Space
	Tree []PageTreeNode `json:"tree"`
}

// PageTreeNode is metadata-only (no content) — enough to render the sidebar
// tree and to resolve a `[...path]` URL segment chain to a page ID.
type PageTreeNode struct {
	ID         string         `json:"id"`
	ParentID   *string        `json:"parent_id,omitempty"`
	Title      string         `json:"title"`
	Slug       string         `json:"slug"`
	Emoji      *string        `json:"emoji,omitempty"`
	OrderIndex int            `json:"order_index"`
	Status     string         `json:"status"`
	Children   []PageTreeNode `json:"children"`
}

// Page is the full content payload. Content is kept opaque (raw TipTap JSON)
// — this backend never inspects its shape beyond extracting plain text for
// search_text, the same treatment systemdesign gives its Excalidraw scene.
type Page struct {
	ID         string          `json:"id"`
	SpaceID    string          `json:"space_id"`
	ParentID   *string         `json:"parent_id,omitempty"`
	Title      string          `json:"title"`
	Slug       string          `json:"slug"`
	Content    json.RawMessage `json:"content"`
	OrderIndex int             `json:"order_index"`
	Status     string          `json:"status"`
	Emoji      *string         `json:"emoji,omitempty"`
	Version    int             `json:"version"`
	CreatedBy  string          `json:"created_by"`
	UpdatedBy  *string         `json:"updated_by,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

// BreadcrumbItem is one ancestor in a page's path from the space root.
type BreadcrumbItem struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Slug  string `json:"slug"`
}

// PageDetail is what GET /api/wiki/pages/:id returns. Comments are embedded
// here (rather than left to a separate GET .../comments call) so a page view
// costs one HTTP round trip from the Next.js server to the Go API instead of
// two — the comments list itself is still a second, cheap same-network SQL
// query inside GetPage.
type PageDetail struct {
	Page
	SpaceSlug  string           `json:"space_slug"`
	SpaceName  string           `json:"space_name"`
	Breadcrumb []BreadcrumbItem `json:"breadcrumb"`
	Comments   []CommentThread  `json:"comments"`
}

// PageVersionSummary is one row in the version history list — no content.
type PageVersionSummary struct {
	Version int       `json:"version"`
	Title   string    `json:"title"`
	SavedBy string    `json:"saved_by"`
	SavedAt time.Time `json:"saved_at"`
}

// PageVersionDetail is a single version's full content, for preview/restore.
type PageVersionDetail struct {
	PageVersionSummary
	Content json.RawMessage `json:"content"`
}

// Comment is one node in a page's (at most one-level-deep) comment thread.
type Comment struct {
	ID        string    `json:"id"`
	PageID    string    `json:"page_id"`
	ParentID  *string   `json:"parent_id,omitempty"`
	AuthorID  string    `json:"author_id"`
	Content   string    `json:"content"`
	Deleted   bool      `json:"deleted"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// CommentThread groups a top-level comment with its replies.
type CommentThread struct {
	Comment
	Replies []Comment `json:"replies"`
}

// Template is a reusable starter document — platform built-ins have OrgID nil.
type Template struct {
	ID          string          `json:"id"`
	OrgID       *string         `json:"org_id,omitempty"`
	Name        string          `json:"name"`
	Description *string         `json:"description,omitempty"`
	Content     json.RawMessage `json:"content"`
	CreatedBy   *string         `json:"created_by,omitempty"`
	CreatedAt   time.Time       `json:"created_at"`
}

// SearchResult is one full-text search hit.
type SearchResult struct {
	PageID    string    `json:"page_id"`
	Title     string    `json:"title"`
	SpaceName string    `json:"space_name"`
	SpaceSlug string    `json:"space_slug"`
	Excerpt   string    `json:"excerpt"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ─── Request bodies ─────────────────────────────────────────────────────────

type CreateSpaceRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
	Icon        *string `json:"icon"`
	Visibility  string  `json:"visibility"`
	CourseID    *string `json:"course_id"`
}

type UpdateSpaceRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Icon        *string `json:"icon"`
	Visibility  *string `json:"visibility"`
}

type CreatePageRequest struct {
	Title      string  `json:"title"`
	ParentID   *string `json:"parent_id"`
	Emoji      *string `json:"emoji"`
	TemplateID *string `json:"template_id"`
}

type UpdatePageRequest struct {
	Title      *string          `json:"title"`
	Content    *json.RawMessage `json:"content"`
	Status     *string          `json:"status"`
	Emoji      *string          `json:"emoji"`
	OrderIndex *int             `json:"order_index"`
	ParentID   *string          `json:"parent_id"`
}

type MovePageRequest struct {
	ParentID   *string `json:"parent_id"`
	OrderIndex int     `json:"order_index"`
}

type CreateCommentRequest struct {
	Content  string  `json:"content"`
	ParentID *string `json:"parent_id"`
}

type UpdateCommentRequest struct {
	Content string `json:"content"`
}

type CreateTemplateRequest struct {
	Name        string          `json:"name"`
	Description *string         `json:"description"`
	Content     json.RawMessage `json:"content"`
}

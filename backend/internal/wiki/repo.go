package wiki

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("wiki: not found")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("wiki: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("wiki: commit tx: %w", err)
	}
	return nil
}

// ─── Spaces ───────────────────────────────────────────────────────────────────

const spaceCols = `id, org_id, course_id, name, slug, description, icon, visibility, created_by, created_at, updated_at`

func scanSpace(row pgx.Row) (Space, error) {
	var s Space
	err := row.Scan(&s.ID, &s.OrgID, &s.CourseID, &s.Name, &s.Slug, &s.Description, &s.Icon, &s.Visibility, &s.CreatedBy, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Space{}, ErrNotFound
		}
		return Space{}, fmt.Errorf("wiki: scan space: %w", err)
	}
	return s, nil
}

func (r *Repo) ListSpaces(ctx context.Context, orgID string) ([]Space, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+spaceCols+` FROM wiki_spaces WHERE org_id = $1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, fmt.Errorf("wiki: list spaces: %w", err)
	}
	defer rows.Close()

	out := []Space{}
	for rows.Next() {
		s, err := scanSpace(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *Repo) CreateSpace(ctx context.Context, orgID, name, slug string, description, icon, courseID *string, visibility, createdBy string) (Space, error) {
	return scanSpace(r.pool.QueryRow(ctx,
		`INSERT INTO wiki_spaces (org_id, course_id, name, slug, description, icon, visibility, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 RETURNING `+spaceCols,
		orgID, courseID, name, slug, description, icon, visibility, createdBy))
}

func (r *Repo) GetSpaceBySlug(ctx context.Context, orgID, slug string) (Space, error) {
	return scanSpace(r.pool.QueryRow(ctx,
		`SELECT `+spaceCols+` FROM wiki_spaces WHERE org_id = $1 AND slug = $2`, orgID, slug))
}

func (r *Repo) GetSpaceByID(ctx context.Context, orgID, id string) (Space, error) {
	return scanSpace(r.pool.QueryRow(ctx,
		`SELECT `+spaceCols+` FROM wiki_spaces WHERE org_id = $1 AND id = $2`, orgID, id))
}

func (r *Repo) UpdateSpace(ctx context.Context, orgID, id string, req UpdateSpaceRequest) (Space, error) {
	return scanSpace(r.pool.QueryRow(ctx,
		`UPDATE wiki_spaces SET
		   name = COALESCE($3, name),
		   description = COALESCE($4, description),
		   icon = COALESCE($5, icon),
		   visibility = COALESCE($6, visibility),
		   updated_at = now()
		 WHERE org_id = $1 AND id = $2
		 RETURNING `+spaceCols,
		orgID, id, req.Name, req.Description, req.Icon, req.Visibility))
}

func (r *Repo) DeleteSpace(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM wiki_spaces WHERE org_id = $1 AND id = $2`, orgID, id)
	if err != nil {
		return fmt.Errorf("wiki: delete space: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Page tree ────────────────────────────────────────────────────────────────

// GetPageTree returns every non-deleted page in a space (metadata only) as a
// nested tree. The space is small enough (a wiki, not a filesystem) that
// fetching flat and nesting in memory is simpler than a recursive CTE.
func (r *Repo) GetPageTree(ctx context.Context, spaceID string) ([]PageTreeNode, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, parent_id, title, slug, emoji, order_index, status
		 FROM wiki_pages WHERE space_id = $1 AND deleted_at IS NULL
		 ORDER BY order_index ASC, title ASC`, spaceID)
	if err != nil {
		return nil, fmt.Errorf("wiki: get page tree: %w", err)
	}
	defer rows.Close()

	byID := map[string]*PageTreeNode{}
	var flat []*PageTreeNode
	for rows.Next() {
		n := &PageTreeNode{Children: []PageTreeNode{}}
		if err := rows.Scan(&n.ID, &n.ParentID, &n.Title, &n.Slug, &n.Emoji, &n.OrderIndex, &n.Status); err != nil {
			return nil, fmt.Errorf("wiki: scan tree node: %w", err)
		}
		byID[n.ID] = n
		flat = append(flat, n)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	roots := []PageTreeNode{}
	for _, n := range flat {
		if n.ParentID != nil {
			if parent, ok := byID[*n.ParentID]; ok {
				parent.Children = append(parent.Children, *n)
				continue
			}
		}
		roots = append(roots, *n)
	}
	// Second pass: children were appended as value-copies before their own
	// children were attached, so rebuild depth-first from byID instead of the
	// shallow copies above.
	return attachChildren(roots, byID), nil
}

func attachChildren(nodes []PageTreeNode, byID map[string]*PageTreeNode) []PageTreeNode {
	out := make([]PageTreeNode, len(nodes))
	for i, n := range nodes {
		full := byID[n.ID]
		n.Children = attachChildren(full.Children, byID)
		out[i] = n
	}
	return out
}

// ─── Pages ────────────────────────────────────────────────────────────────────

const pageCols = `id, space_id, parent_id, title, slug, content, order_index, status, emoji, version, created_by, updated_by, created_at, updated_at`

func scanPage(row pgx.Row) (Page, error) {
	var p Page
	err := row.Scan(&p.ID, &p.SpaceID, &p.ParentID, &p.Title, &p.Slug, &p.Content, &p.OrderIndex, &p.Status, &p.Emoji, &p.Version, &p.CreatedBy, &p.UpdatedBy, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Page{}, ErrNotFound
		}
		return Page{}, fmt.Errorf("wiki: scan page: %w", err)
	}
	return p, nil
}

func (r *Repo) CreatePage(ctx context.Context, spaceID, title, slug string, parentID, emoji *string, content json.RawMessage, searchText, createdBy string) (Page, error) {
	return scanPage(r.pool.QueryRow(ctx,
		`INSERT INTO wiki_pages (space_id, parent_id, title, slug, content, search_text, emoji, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 RETURNING `+pageCols,
		spaceID, parentID, title, slug, content, searchText, emoji, createdBy))
}

// GetPage is scoped through wiki_spaces.org_id so a page ID from another org
// (IDOR) surfaces as ErrNotFound, matching every other domain's convention.
func (r *Repo) GetPage(ctx context.Context, orgID, id string) (Page, error) {
	return scanPage(r.pool.QueryRow(ctx,
		`SELECT p.id, p.space_id, p.parent_id, p.title, p.slug, p.content, p.order_index, p.status, p.emoji, p.version, p.created_by, p.updated_by, p.created_at, p.updated_at
		 FROM wiki_pages p JOIN wiki_spaces s ON s.id = p.space_id
		 WHERE p.id = $1 AND s.org_id = $2 AND p.deleted_at IS NULL`, id, orgID))
}

// GetBreadcrumb walks the parent_id chain from the page to the space root.
func (r *Repo) GetBreadcrumb(ctx context.Context, pageID string) ([]BreadcrumbItem, error) {
	rows, err := r.pool.Query(ctx,
		`WITH RECURSIVE ancestors AS (
		   SELECT id, parent_id, title, slug, 0 AS depth FROM wiki_pages WHERE id = $1
		   UNION ALL
		   SELECT p.id, p.parent_id, p.title, p.slug, a.depth + 1
		   FROM wiki_pages p JOIN ancestors a ON p.id = a.parent_id
		 )
		 SELECT id, title, slug FROM ancestors ORDER BY depth DESC`, pageID)
	if err != nil {
		return nil, fmt.Errorf("wiki: get breadcrumb: %w", err)
	}
	defer rows.Close()

	out := []BreadcrumbItem{}
	for rows.Next() {
		var b BreadcrumbItem
		if err := rows.Scan(&b.ID, &b.Title, &b.Slug); err != nil {
			return nil, fmt.Errorf("wiki: scan breadcrumb: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// UpdatePage applies a partial edit. When title or content actually change it
// bumps `version` and appends the new state to wiki_page_versions in the same
// transaction, matching docs/wiki.md ("every PATCH that changes title or
// content appends a version row").
func (r *Repo) UpdatePage(ctx context.Context, orgID, id string, title *string, content *json.RawMessage, searchText *string, status, emoji, parentID *string, orderIndex *int, updatedBy string) (Page, error) {
	var out Page
	err := r.tx(ctx, func(tx pgx.Tx) error {
		contentChanged := content != nil || title != nil
		bump := 0
		if contentChanged {
			bump = 1
		}
		row := tx.QueryRow(ctx,
			`UPDATE wiki_pages p SET
			   title = COALESCE($3, title),
			   content = COALESCE($4, content),
			   search_text = COALESCE($5, search_text),
			   status = COALESCE($6, status),
			   emoji = COALESCE($7, emoji),
			   parent_id = CASE WHEN $8::boolean THEN $9::uuid ELSE parent_id END,
			   order_index = COALESCE($10, order_index),
			   version = version + $11,
			   updated_by = $12,
			   updated_at = now()
			 FROM wiki_spaces s
			 WHERE p.space_id = s.id AND s.org_id = $1 AND p.id = $2 AND p.deleted_at IS NULL
			 RETURNING p.id, p.space_id, p.parent_id, p.title, p.slug, p.content, p.order_index, p.status, p.emoji, p.version, p.created_by, p.updated_by, p.created_at, p.updated_at`,
			orgID, id, title, content, searchText, status, emoji,
			parentID != nil, parentID, orderIndex, bump, updatedBy)
		p, err := scanPage(row)
		if err != nil {
			return err
		}
		out = p
		if contentChanged {
			_, err := tx.Exec(ctx,
				`INSERT INTO wiki_page_versions (page_id, version, title, content, saved_by)
				 VALUES ($1,$2,$3,$4,$5)`,
				p.ID, p.Version, p.Title, p.Content, updatedBy)
			if err != nil {
				return fmt.Errorf("wiki: insert page version: %w", err)
			}
		}
		return nil
	})
	return out, err
}

// MovePage is a structural-only change (drag-and-drop) — no version row.
func (r *Repo) MovePage(ctx context.Context, orgID, id string, parentID *string, orderIndex int) (Page, error) {
	return scanPage(r.pool.QueryRow(ctx,
		`UPDATE wiki_pages p SET parent_id = $3, order_index = $4, updated_at = now()
		 FROM wiki_spaces s
		 WHERE p.space_id = s.id AND s.org_id = $1 AND p.id = $2 AND p.deleted_at IS NULL
		 RETURNING p.id, p.space_id, p.parent_id, p.title, p.slug, p.content, p.order_index, p.status, p.emoji, p.version, p.created_by, p.updated_by, p.created_at, p.updated_at`,
		orgID, id, parentID, orderIndex))
}

// DeletePage soft-deletes the page and re-parents its children to the
// grandparent in the same transaction, so no page is ever left orphaned.
func (r *Repo) DeletePage(ctx context.Context, orgID, id string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		var grandparent *string
		err := tx.QueryRow(ctx,
			`SELECT p.parent_id FROM wiki_pages p JOIN wiki_spaces s ON s.id = p.space_id
			 WHERE p.id = $1 AND s.org_id = $2 AND p.deleted_at IS NULL`, id, orgID).Scan(&grandparent)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("wiki: lookup page for delete: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE wiki_pages SET parent_id = $2, updated_at = now() WHERE parent_id = $1`, id, grandparent); err != nil {
			return fmt.Errorf("wiki: reparent children: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE wiki_pages SET deleted_at = now() WHERE id = $1`, id); err != nil {
			return fmt.Errorf("wiki: soft delete page: %w", err)
		}
		return nil
	})
}

// ─── Version history ─────────────────────────────────────────────────────────

func (r *Repo) ListVersions(ctx context.Context, pageID string) ([]PageVersionSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT version, title, saved_by, saved_at FROM wiki_page_versions
		 WHERE page_id = $1 ORDER BY version DESC`, pageID)
	if err != nil {
		return nil, fmt.Errorf("wiki: list versions: %w", err)
	}
	defer rows.Close()

	out := []PageVersionSummary{}
	for rows.Next() {
		var v PageVersionSummary
		if err := rows.Scan(&v.Version, &v.Title, &v.SavedBy, &v.SavedAt); err != nil {
			return nil, fmt.Errorf("wiki: scan version: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

func (r *Repo) GetVersion(ctx context.Context, pageID string, version int) (PageVersionDetail, error) {
	var v PageVersionDetail
	err := r.pool.QueryRow(ctx,
		`SELECT version, title, saved_by, saved_at, content FROM wiki_page_versions
		 WHERE page_id = $1 AND version = $2`, pageID, version,
	).Scan(&v.Version, &v.Title, &v.SavedBy, &v.SavedAt, &v.Content)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PageVersionDetail{}, ErrNotFound
		}
		return PageVersionDetail{}, fmt.Errorf("wiki: get version: %w", err)
	}
	return v, nil
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func (r *Repo) ListComments(ctx context.Context, pageID string) ([]CommentThread, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, page_id, parent_id, author_id, COALESCE(content, ''), deleted_at IS NOT NULL, created_at, updated_at
		 FROM wiki_comments WHERE page_id = $1 ORDER BY created_at ASC`, pageID)
	if err != nil {
		return nil, fmt.Errorf("wiki: list comments: %w", err)
	}
	defer rows.Close()

	var flat []Comment
	for rows.Next() {
		var c Comment
		if err := rows.Scan(&c.ID, &c.PageID, &c.ParentID, &c.AuthorID, &c.Content, &c.Deleted, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("wiki: scan comment: %w", err)
		}
		if c.Deleted {
			c.Content = "[deleted]"
		}
		flat = append(flat, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	byID := map[string]int{}
	threads := []CommentThread{}
	for _, c := range flat {
		if c.ParentID == nil {
			byID[c.ID] = len(threads)
			threads = append(threads, CommentThread{Comment: c, Replies: []Comment{}})
		}
	}
	for _, c := range flat {
		if c.ParentID != nil {
			if idx, ok := byID[*c.ParentID]; ok {
				threads[idx].Replies = append(threads[idx].Replies, c)
			}
		}
	}
	return threads, nil
}

func (r *Repo) CreateComment(ctx context.Context, pageID, authorID, content string, parentID *string) (Comment, error) {
	var c Comment
	err := r.pool.QueryRow(ctx,
		`INSERT INTO wiki_comments (page_id, parent_id, author_id, content)
		 VALUES ($1,$2,$3,$4)
		 RETURNING id, page_id, parent_id, author_id, content, deleted_at IS NOT NULL, created_at, updated_at`,
		pageID, parentID, authorID, content,
	).Scan(&c.ID, &c.PageID, &c.ParentID, &c.AuthorID, &c.Content, &c.Deleted, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return Comment{}, fmt.Errorf("wiki: create comment: %w", err)
	}
	return c, nil
}

func (r *Repo) GetComment(ctx context.Context, id string) (Comment, error) {
	var c Comment
	err := r.pool.QueryRow(ctx,
		`SELECT id, page_id, parent_id, author_id, COALESCE(content, ''), deleted_at IS NOT NULL, created_at, updated_at
		 FROM wiki_comments WHERE id = $1`, id,
	).Scan(&c.ID, &c.PageID, &c.ParentID, &c.AuthorID, &c.Content, &c.Deleted, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Comment{}, ErrNotFound
		}
		return Comment{}, fmt.Errorf("wiki: get comment: %w", err)
	}
	return c, nil
}

func (r *Repo) UpdateComment(ctx context.Context, id, content string) (Comment, error) {
	var c Comment
	err := r.pool.QueryRow(ctx,
		`UPDATE wiki_comments SET content = $2, updated_at = now() WHERE id = $1 AND deleted_at IS NULL
		 RETURNING id, page_id, parent_id, author_id, content, deleted_at IS NOT NULL, created_at, updated_at`,
		id, content,
	).Scan(&c.ID, &c.PageID, &c.ParentID, &c.AuthorID, &c.Content, &c.Deleted, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Comment{}, ErrNotFound
		}
		return Comment{}, fmt.Errorf("wiki: update comment: %w", err)
	}
	return c, nil
}

func (r *Repo) DeleteComment(ctx context.Context, id string) error {
	tag, err := r.pool.Exec(ctx, `UPDATE wiki_comments SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL`, id)
	if err != nil {
		return fmt.Errorf("wiki: delete comment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Templates ────────────────────────────────────────────────────────────────

func (r *Repo) ListTemplates(ctx context.Context, orgID string) ([]Template, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, name, description, content, created_by, created_at
		 FROM wiki_templates WHERE org_id IS NULL OR org_id = $1 ORDER BY org_id NULLS FIRST, name ASC`, orgID)
	if err != nil {
		return nil, fmt.Errorf("wiki: list templates: %w", err)
	}
	defer rows.Close()

	out := []Template{}
	for rows.Next() {
		var t Template
		if err := rows.Scan(&t.ID, &t.OrgID, &t.Name, &t.Description, &t.Content, &t.CreatedBy, &t.CreatedAt); err != nil {
			return nil, fmt.Errorf("wiki: scan template: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r *Repo) GetTemplate(ctx context.Context, id string) (Template, error) {
	var t Template
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, name, description, content, created_by, created_at FROM wiki_templates WHERE id = $1`, id,
	).Scan(&t.ID, &t.OrgID, &t.Name, &t.Description, &t.Content, &t.CreatedBy, &t.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Template{}, ErrNotFound
		}
		return Template{}, fmt.Errorf("wiki: get template: %w", err)
	}
	return t, nil
}

func (r *Repo) CreateTemplate(ctx context.Context, orgID, name string, description *string, content json.RawMessage, createdBy string) (Template, error) {
	var t Template
	err := r.pool.QueryRow(ctx,
		`INSERT INTO wiki_templates (org_id, name, description, content, created_by)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING id, org_id, name, description, content, created_by, created_at`,
		orgID, name, description, content, createdBy,
	).Scan(&t.ID, &t.OrgID, &t.Name, &t.Description, &t.Content, &t.CreatedBy, &t.CreatedAt)
	if err != nil {
		return Template{}, fmt.Errorf("wiki: create template: %w", err)
	}
	return t, nil
}

func (r *Repo) DeleteTemplate(ctx context.Context, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM wiki_templates WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("wiki: delete template: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Search ───────────────────────────────────────────────────────────────────

func (r *Repo) Search(ctx context.Context, orgID, query string, spaceSlug *string) ([]SearchResult, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT p.id, p.title, s.name, s.slug, p.updated_at,
		        ts_headline('english', p.search_text, websearch_to_tsquery('english', $2), 'MaxWords=30, MinWords=15, StartSel=, StopSel=')
		 FROM wiki_pages p JOIN wiki_spaces s ON s.id = p.space_id
		 WHERE s.org_id = $1 AND p.deleted_at IS NULL AND p.status = 'published'
		   AND p.search_vector @@ websearch_to_tsquery('english', $2)
		   AND ($3::text IS NULL OR s.slug = $3)
		 ORDER BY ts_rank(p.search_vector, websearch_to_tsquery('english', $2)) DESC
		 LIMIT 25`,
		orgID, query, spaceSlug)
	if err != nil {
		return nil, fmt.Errorf("wiki: search: %w", err)
	}
	defer rows.Close()

	out := []SearchResult{}
	for rows.Next() {
		var s SearchResult
		if err := rows.Scan(&s.PageID, &s.Title, &s.SpaceName, &s.SpaceSlug, &s.UpdatedAt, &s.Excerpt); err != nil {
			return nil, fmt.Errorf("wiki: scan search result: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_comments.go — the generic `comments` table (already used by wiki,
// messaging, etc.) applied to two new subject types (contract-phase3.md):
// "requirement_question" (question threads) and "work_item" (item threads).
// Raw SQL against the shared table, matching wiki/repo.go's own comments
// section, rather than a shared comments package — see that file's doc
// comment on why every domain owns its own scoped queries here.

const commentColumns = `c.id, c.subject_id, c.parent_id, c.author_id, COALESCE(u.name, 'Former member'), c.content, c.created_at, c.updated_at`

func scanComment(row pgx.Row) (*Comment, error) {
	var c Comment
	err := row.Scan(&c.ID, &c.SubjectID, &c.ParentID, &c.AuthorID, &c.AuthorName, &c.Content, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan comment: %w", err)
	}
	return &c, nil
}

// ListComments cursor-paginates one subject's comment thread, oldest first
// (a thread reads top-to-bottom, unlike every other list in this package).
func (r *Repo) ListComments(ctx context.Context, db DBTX, subjectType, subjectID string, cursorAt time.Time, cursorID string, limit int) ([]Comment, error) {
	var rows pgx.Rows
	var err error
	if cursorAt.IsZero() {
		rows, err = db.Query(ctx,
			`SELECT `+commentColumns+` FROM comments c LEFT JOIN users u ON u.id = c.author_id
			  WHERE c.subject_type = $1 AND c.subject_id = $2 AND c.deleted_at IS NULL
			  ORDER BY c.created_at ASC, c.id ASC LIMIT $3`,
			subjectType, subjectID, limit)
	} else {
		rows, err = db.Query(ctx,
			`SELECT `+commentColumns+` FROM comments c LEFT JOIN users u ON u.id = c.author_id
			  WHERE c.subject_type = $1 AND c.subject_id = $2 AND c.deleted_at IS NULL AND (c.created_at, c.id) > ($3, $4)
			  ORDER BY c.created_at ASC, c.id ASC LIMIT $5`,
			subjectType, subjectID, cursorAt, cursorID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list comments: %w", err)
	}
	defer rows.Close()
	out := []Comment{}
	for rows.Next() {
		c, err := scanComment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

// InsertComment appends one comment row on subjectType/subjectID.
func (r *Repo) InsertComment(ctx context.Context, db DBTX, subjectType, subjectID, authorID, content string, parentID *string) (*Comment, error) {
	row := db.QueryRow(ctx,
		`WITH ins AS (
			INSERT INTO comments (subject_type, subject_id, parent_id, author_id, content)
			VALUES ($1,$2,$3,$4,$5)
			RETURNING id
		 )
		 SELECT `+commentColumns+`
		   FROM comments c LEFT JOIN users u ON u.id = c.author_id
		  WHERE c.id = (SELECT id FROM ins)`,
		subjectType, subjectID, parentID, authorID, content,
	)
	return scanComment(row)
}

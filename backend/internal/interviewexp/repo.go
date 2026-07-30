package interviewexp

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("interviewexp: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ─── Posts ────────────────────────────────────────────────────────────────────

const postCols = `id, author_id, company, position, tags, title, created_at, updated_at`

func scanPost(row pgx.Row) (Post, error) {
	var p Post
	err := row.Scan(&p.ID, &p.AuthorID, &p.Company, &p.Position, &p.Tags, &p.Title, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Post{}, ErrNotFound
		}
		return Post{}, fmt.Errorf("interviewexp: scan post: %w", err)
	}
	return p, nil
}

// ListPosts is unscoped by org — this content is platform-wide (see
// docs/interview-experiences.md). company/position match case-insensitively
// on substring; tag matches an exact element of the tags array; q free-texts
// the title.
func (r *Repo) ListPosts(ctx context.Context, f ListFilter) ([]Post, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+postCols+` FROM interview_exp_posts
		 WHERE deleted_at IS NULL
		   AND ($1::text IS NULL OR company ILIKE '%' || $1 || '%')
		   AND ($2::text IS NULL OR position ILIKE '%' || $2 || '%')
		   AND ($3::text IS NULL OR $3 = ANY(tags))
		   AND ($4::text IS NULL OR title ILIKE '%' || $4 || '%')
		 ORDER BY created_at DESC
		 LIMIT 100`,
		f.Company, f.Position, f.Tag, f.Query)
	if err != nil {
		return nil, fmt.Errorf("interviewexp: list posts: %w", err)
	}
	defer rows.Close()

	out := []Post{}
	for rows.Next() {
		p, err := scanPost(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *Repo) CreatePost(ctx context.Context, authorID, company, position, title string, tags []string) (Post, error) {
	return scanPost(r.pool.QueryRow(ctx,
		`INSERT INTO interview_exp_posts (author_id, company, position, tags, title)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING `+postCols,
		authorID, company, position, tags, title))
}

func (r *Repo) GetPost(ctx context.Context, id string) (Post, error) {
	return scanPost(r.pool.QueryRow(ctx,
		`SELECT `+postCols+` FROM interview_exp_posts WHERE id = $1 AND deleted_at IS NULL`, id))
}

// ─── Entries ──────────────────────────────────────────────────────────────────

const entryCols = `id, post_id, author_id, round_label, content, created_at, updated_at`

func scanEntry(row pgx.Row) (Entry, error) {
	var e Entry
	err := row.Scan(&e.ID, &e.PostID, &e.AuthorID, &e.RoundLabel, &e.Content, &e.CreatedAt, &e.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("interviewexp: scan entry: %w", err)
	}
	return e, nil
}

func (r *Repo) ListEntries(ctx context.Context, postID string) ([]Entry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+entryCols+` FROM interview_exp_entries
		 WHERE post_id = $1 AND deleted_at IS NULL ORDER BY created_at ASC`, postID)
	if err != nil {
		return nil, fmt.Errorf("interviewexp: list entries: %w", err)
	}
	defer rows.Close()

	out := []Entry{}
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *Repo) CreateEntry(ctx context.Context, postID, authorID, roundLabel, content string) (Entry, error) {
	return scanEntry(r.pool.QueryRow(ctx,
		`INSERT INTO interview_exp_entries (post_id, author_id, round_label, content)
		 VALUES ($1,$2,$3,$4)
		 RETURNING `+entryCols,
		postID, authorID, roundLabel, content))
}

func (r *Repo) GetEntry(ctx context.Context, id string) (Entry, error) {
	return scanEntry(r.pool.QueryRow(ctx,
		`SELECT `+entryCols+` FROM interview_exp_entries WHERE id = $1 AND deleted_at IS NULL`, id))
}

// ─── Qna ──────────────────────────────────────────────────────────────────────

const qnaCols = `id, post_id, entry_id, author_id, question, answer, created_at, updated_at`

func scanQna(row pgx.Row) (Qna, error) {
	var q Qna
	err := row.Scan(&q.ID, &q.PostID, &q.EntryID, &q.AuthorID, &q.Question, &q.Answer, &q.CreatedAt, &q.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Qna{}, ErrNotFound
		}
		return Qna{}, fmt.Errorf("interviewexp: scan qna: %w", err)
	}
	return q, nil
}

// ListQnaByPost returns every Q&A on a post — both entry-scoped and
// standalone — for the detail view, which splits them by EntryID itself.
func (r *Repo) ListQnaByPost(ctx context.Context, postID string) ([]Qna, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+qnaCols+` FROM interview_exp_qna
		 WHERE post_id = $1 AND deleted_at IS NULL ORDER BY created_at ASC`, postID)
	if err != nil {
		return nil, fmt.Errorf("interviewexp: list qna: %w", err)
	}
	defer rows.Close()

	out := []Qna{}
	for rows.Next() {
		q, err := scanQna(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

// CreateQna's entryID may be nil (standalone question directly on the post).
func (r *Repo) CreateQna(ctx context.Context, postID string, entryID *string, authorID, question string, answer *string) (Qna, error) {
	return scanQna(r.pool.QueryRow(ctx,
		`INSERT INTO interview_exp_qna (post_id, entry_id, author_id, question, answer)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING `+qnaCols,
		postID, entryID, authorID, question, answer))
}

func (r *Repo) GetQna(ctx context.Context, id string) (Qna, error) {
	return scanQna(r.pool.QueryRow(ctx,
		`SELECT `+qnaCols+` FROM interview_exp_qna WHERE id = $1 AND deleted_at IS NULL`, id))
}

func (r *Repo) UpdateQna(ctx context.Context, id string, question, answer *string) (Qna, error) {
	return scanQna(r.pool.QueryRow(ctx,
		`UPDATE interview_exp_qna SET
		   question = COALESCE($2, question),
		   answer = COALESCE($3, answer),
		   updated_at = now()
		 WHERE id = $1 AND deleted_at IS NULL
		 RETURNING `+qnaCols,
		id, question, answer))
}

func (r *Repo) DeleteQna(ctx context.Context, id string) error {
	tag, err := r.pool.Exec(ctx, `UPDATE interview_exp_qna SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL`, id)
	if err != nil {
		return fmt.Errorf("interviewexp: delete qna: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func scanComment(row pgx.Row) (Comment, error) {
	var c Comment
	err := row.Scan(&c.ID, &c.QnaID, &c.ParentID, &c.AuthorID, &c.Content, &c.Deleted, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Comment{}, ErrNotFound
		}
		return Comment{}, fmt.Errorf("interviewexp: scan comment: %w", err)
	}
	return c, nil
}

const commentSelectCols = `id, qna_id, parent_id, author_id, COALESCE(content, ''), deleted_at IS NOT NULL, created_at, updated_at`

// ListCommentsByQnaIDs returns every (non-deleted-forever, soft-deleted ones
// still render as "[deleted]") comment across the given qna IDs flat — the
// service builds the nested tree per qna from this.
func (r *Repo) ListCommentsByQnaIDs(ctx context.Context, qnaIDs []string) ([]Comment, error) {
	if len(qnaIDs) == 0 {
		return []Comment{}, nil
	}
	rows, err := r.pool.Query(ctx,
		`SELECT `+commentSelectCols+` FROM interview_exp_comments
		 WHERE qna_id = ANY($1) ORDER BY created_at ASC`, qnaIDs)
	if err != nil {
		return nil, fmt.Errorf("interviewexp: list comments: %w", err)
	}
	defer rows.Close()

	out := []Comment{}
	for rows.Next() {
		c, err := scanComment(rows)
		if err != nil {
			return nil, err
		}
		if c.Deleted {
			c.Content = "[deleted]"
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *Repo) CreateComment(ctx context.Context, qnaID, authorID, content string, parentID *string) (Comment, error) {
	c, err := scanComment(r.pool.QueryRow(ctx,
		`INSERT INTO interview_exp_comments (qna_id, parent_id, author_id, content)
		 VALUES ($1,$2,$3,$4)
		 RETURNING `+commentSelectCols,
		qnaID, parentID, authorID, content))
	return c, err
}

func (r *Repo) GetComment(ctx context.Context, id string) (Comment, error) {
	return scanComment(r.pool.QueryRow(ctx,
		`SELECT `+commentSelectCols+` FROM interview_exp_comments WHERE id = $1`, id))
}

func (r *Repo) UpdateComment(ctx context.Context, id, content string) (Comment, error) {
	return scanComment(r.pool.QueryRow(ctx,
		`UPDATE interview_exp_comments SET content = $2, updated_at = now()
		 WHERE id = $1 AND deleted_at IS NULL
		 RETURNING `+commentSelectCols,
		id, content))
}

func (r *Repo) DeleteComment(ctx context.Context, id string) error {
	tag, err := r.pool.Exec(ctx, `UPDATE interview_exp_comments SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL`, id)
	if err != nil {
		return fmt.Errorf("interviewexp: delete comment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── Votes ────────────────────────────────────────────────────────────────────

// VoteScores returns, for every targetID, its aggregate score and the
// calling user's own vote (0 if none) in a single query.
func (r *Repo) VoteScores(ctx context.Context, targetType string, targetIDs []string, userID string) (map[string]int, map[string]int, error) {
	scores := map[string]int{}
	mine := map[string]int{}
	if len(targetIDs) == 0 {
		return scores, mine, nil
	}
	rows, err := r.pool.Query(ctx,
		`SELECT target_id,
		        COALESCE(SUM(value), 0),
		        COALESCE(SUM(value) FILTER (WHERE user_id = $3), 0)
		 FROM interview_exp_votes
		 WHERE target_type = $1 AND target_id = ANY($2)
		 GROUP BY target_id`,
		targetType, targetIDs, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("interviewexp: vote scores: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var id string
		var score, my int
		if err := rows.Scan(&id, &score, &my); err != nil {
			return nil, nil, fmt.Errorf("interviewexp: scan vote score: %w", err)
		}
		scores[id] = score
		mine[id] = my
	}
	return scores, mine, rows.Err()
}

// Vote upserts the caller's vote, or clears it when value is 0.
func (r *Repo) Vote(ctx context.Context, userID, targetType, targetID string, value int) error {
	if value == 0 {
		_, err := r.pool.Exec(ctx,
			`DELETE FROM interview_exp_votes WHERE user_id = $1 AND target_type = $2 AND target_id = $3`,
			userID, targetType, targetID)
		if err != nil {
			return fmt.Errorf("interviewexp: clear vote: %w", err)
		}
		return nil
	}
	_, err := r.pool.Exec(ctx,
		`INSERT INTO interview_exp_votes (user_id, target_type, target_id, value)
		 VALUES ($1,$2,$3,$4)
		 ON CONFLICT (user_id, target_type, target_id) DO UPDATE SET value = EXCLUDED.value`,
		userID, targetType, targetID, value)
	if err != nil {
		return fmt.Errorf("interviewexp: upsert vote: %w", err)
	}
	return nil
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────

// ListFaq is the cross-post aggregate for /api/interview-exp/faq: every
// non-deleted qna joined with its post's company/position/tags, its vote
// score (the "frequency" signal), and the caller's own progress/star —
// all in one query, no N+1 regardless of how many questions exist.
func (r *Repo) ListFaq(ctx context.Context, userID string, f FaqFilter) ([]FaqItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT q.id, q.post_id, q.question, q.answer, p.company, p.position, p.tags,
		        COALESCE(v.score, 0),
		        COALESCE(pr.status, 'todo'),
		        COALESCE(pr.is_starred, false),
		        q.created_at
		 FROM interview_exp_qna q
		 JOIN interview_exp_posts p ON p.id = q.post_id AND p.deleted_at IS NULL
		 LEFT JOIN (
		   SELECT target_id, SUM(value) AS score FROM interview_exp_votes
		   WHERE target_type = 'qna' GROUP BY target_id
		 ) v ON v.target_id = q.id
		 LEFT JOIN interview_exp_qna_progress pr ON pr.qna_id = q.id AND pr.user_id = $1
		 WHERE q.deleted_at IS NULL
		   AND ($2::text IS NULL OR p.company ILIKE '%' || $2 || '%')
		   AND ($3::text IS NULL OR $3 = ANY(p.tags))
		   AND ($4::text IS NULL OR COALESCE(pr.status, 'todo') = $4)
		 ORDER BY COALESCE(v.score, 0) DESC, q.created_at DESC
		 LIMIT 500`,
		userID, f.Company, f.Tag, f.Status)
	if err != nil {
		return nil, fmt.Errorf("interviewexp: list faq: %w", err)
	}
	defer rows.Close()

	out := []FaqItem{}
	for rows.Next() {
		var it FaqItem
		if err := rows.Scan(&it.QnaID, &it.PostID, &it.Question, &it.Answer, &it.Company, &it.Position, &it.Tags,
			&it.Score, &it.Status, &it.IsStarred, &it.CreatedAt); err != nil {
			return nil, fmt.Errorf("interviewexp: scan faq item: %w", err)
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

func (r *Repo) UpsertFaqStatus(ctx context.Context, userID, qnaID, status string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO interview_exp_qna_progress (user_id, qna_id, status)
		 VALUES ($1,$2,$3)
		 ON CONFLICT (user_id, qna_id) DO UPDATE SET status = EXCLUDED.status, updated_at = now()`,
		userID, qnaID, status)
	if err != nil {
		return fmt.Errorf("interviewexp: upsert faq status: %w", err)
	}
	return nil
}

func (r *Repo) UpsertFaqStarred(ctx context.Context, userID, qnaID string, starred bool) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO interview_exp_qna_progress (user_id, qna_id, is_starred)
		 VALUES ($1,$2,$3)
		 ON CONFLICT (user_id, qna_id) DO UPDATE SET is_starred = EXCLUDED.is_starred, updated_at = now()`,
		userID, qnaID, starred)
	if err != nil {
		return fmt.Errorf("interviewexp: upsert faq starred: %w", err)
	}
	return nil
}

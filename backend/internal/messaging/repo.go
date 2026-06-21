package messaging

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound         = errors.New("messaging: not found")
	ErrForbidden        = errors.New("messaging: forbidden")
	ErrEditWindowClosed = errors.New("messaging: edit window closed (15 minutes)")
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
		return fmt.Errorf("messaging: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("messaging: commit tx: %w", err)
	}
	return nil
}

func (r *Repo) ListMessages(ctx context.Context, orgID, batchID, userID string, f ListMessagesFilter) ([]BatchMessage, error) {
	limit := f.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	conds := []string{
		"m.batch_id = $1",
		"m.parent_id IS NULL",
		"m.deleted_at IS NULL",
		"EXISTS(SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $2)",
		"(EXISTS(SELECT 1 FROM batch_members bm WHERE bm.batch_id = $1 AND bm.user_id = $3) OR EXISTS(SELECT 1 FROM org_members om WHERE om.org_id = $2 AND om.user_id = $3 AND om.role IN ('admin','instructor','mentor')))",
	}
	args := []any{batchID, orgID, userID}
	idx := 4

	if f.Before != "" {
		conds = append(conds, fmt.Sprintf("(m.created_at, m.id) < (SELECT created_at, id FROM batch_messages WHERE id = $%d)", idx))
		args = append(args, f.Before)
		idx++
	}
	if f.Type != "" {
		conds = append(conds, fmt.Sprintf("m.type = $%d", idx))
		args = append(args, f.Type)
		idx++
	}
	if f.Unresolved {
		conds = append(conds, "m.is_resolved = false")
	}
	if f.Pinned {
		conds = append(conds, "m.is_pinned = true")
	}

	query := `SELECT m.id, m.batch_id, m.sender_id, u.name,
		m.parent_id,
		CASE WHEN m.deleted_at IS NOT NULL THEN '[deleted]' ELSE m.body END,
		m.type, m.is_pinned, m.is_resolved, m.edited_at, m.created_at,
		(SELECT COUNT(*) FROM batch_messages r WHERE r.parent_id = m.id AND r.deleted_at IS NULL)
	FROM batch_messages m
	JOIN users u ON u.id = m.sender_id
	WHERE ` + strings.Join(conds, " AND ") +
		` ORDER BY m.created_at DESC, m.id DESC LIMIT $` + strconv.Itoa(idx)
	args = append(args, limit)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("messaging: list messages: %w", err)
	}
	defer rows.Close()

	msgs := []BatchMessage{}
	ids := []string{}
	for rows.Next() {
		var m BatchMessage
		if err := rows.Scan(&m.ID, &m.BatchID, &m.SenderID, &m.SenderName,
			&m.ParentID, &m.Body, &m.Type, &m.IsPinned, &m.IsResolved,
			&m.EditedAt, &m.CreatedAt, &m.ReplyCount); err != nil {
			return nil, fmt.Errorf("messaging: scan message: %w", err)
		}
		m.Reactions = []ReactionCount{}
		msgs = append(msgs, m)
		ids = append(ids, m.ID)
	}
	if rows.Err() != nil {
		return nil, rows.Err()
	}
	if len(ids) == 0 {
		return msgs, nil
	}

	// Load reactions for all returned messages
	reactionRows, err := r.pool.Query(ctx,
		`SELECT message_id, reaction, COUNT(*) AS cnt,
		        bool_or(user_id = $1) AS user_reacted
		 FROM batch_message_reactions
		 WHERE message_id = ANY($2::uuid[])
		 GROUP BY message_id, reaction`,
		userID, ids)
	if err != nil {
		return nil, fmt.Errorf("messaging: load reactions: %w", err)
	}
	defer reactionRows.Close()

	reactionMap := map[string][]ReactionCount{}
	for reactionRows.Next() {
		var msgID string
		var rc ReactionCount
		if err := reactionRows.Scan(&msgID, &rc.Reaction, &rc.Count, &rc.UserReacted); err != nil {
			return nil, fmt.Errorf("messaging: scan reaction: %w", err)
		}
		reactionMap[msgID] = append(reactionMap[msgID], rc)
	}
	if reactionRows.Err() != nil {
		return nil, reactionRows.Err()
	}

	for i, m := range msgs {
		if rcs, ok := reactionMap[m.ID]; ok {
			msgs[i].Reactions = rcs
		}
	}
	return msgs, nil
}

func (r *Repo) GetMessage(ctx context.Context, orgID, msgID string) (BatchMessage, error) {
	var m BatchMessage
	err := r.pool.QueryRow(ctx,
		`SELECT m.id, m.batch_id, m.sender_id, u.name, m.parent_id,
		        CASE WHEN m.deleted_at IS NOT NULL THEN '[deleted]' ELSE m.body END,
		        m.type, m.is_pinned, m.is_resolved, m.edited_at, m.created_at, 0
		 FROM batch_messages m
		 JOIN users u ON u.id = m.sender_id
		 WHERE m.id = $1
		   AND EXISTS(SELECT 1 FROM batches b WHERE b.id = m.batch_id AND b.org_id = $2)`,
		msgID, orgID,
	).Scan(&m.ID, &m.BatchID, &m.SenderID, &m.SenderName, &m.ParentID,
		&m.Body, &m.Type, &m.IsPinned, &m.IsResolved, &m.EditedAt, &m.CreatedAt, &m.ReplyCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return BatchMessage{}, ErrNotFound
		}
		return BatchMessage{}, fmt.Errorf("messaging: get message: %w", err)
	}
	m.Reactions = []ReactionCount{}
	return m, nil
}

func (r *Repo) CreateMessage(ctx context.Context, orgID, batchID, senderID string, body string, msgType MessageType, parentID *string) (BatchMessage, error) {
	var m BatchMessage
	m.BatchID = batchID
	m.SenderID = senderID
	m.Body = body
	m.Type = msgType
	m.ParentID = parentID

	err := r.pool.QueryRow(ctx,
		`INSERT INTO batch_messages (batch_id, sender_id, parent_id, body, type)
		 SELECT $1, $2, $3, $4, $5
		 WHERE EXISTS (SELECT 1 FROM batches b WHERE b.id = $1 AND b.org_id = $6)
		 RETURNING id, created_at`,
		batchID, senderID, parentID, body, msgType, orgID,
	).Scan(&m.ID, &m.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return BatchMessage{}, ErrNotFound
		}
		return BatchMessage{}, fmt.Errorf("messaging: create message: %w", err)
	}
	m.Reactions = []ReactionCount{}
	return m, nil
}

func (r *Repo) UpdateMessage(ctx context.Context, orgID, msgID, senderID, body string) (BatchMessage, error) {
	var m BatchMessage
	err := r.pool.QueryRow(ctx,
		`UPDATE batch_messages m
		 SET body = $1, edited_at = now()
		 FROM users u
		 WHERE m.id = $2
		   AND m.sender_id = $3
		   AND m.sender_id = u.id
		   AND m.deleted_at IS NULL
		   AND now() - m.created_at <= interval '15 minutes'
		   AND EXISTS(SELECT 1 FROM batches b WHERE b.id = m.batch_id AND b.org_id = $4)
		 RETURNING m.id, m.batch_id, m.sender_id, u.name, m.parent_id,
		           m.body, m.type, m.is_pinned, m.is_resolved, m.edited_at, m.created_at`,
		body, msgID, senderID, orgID,
	).Scan(&m.ID, &m.BatchID, &m.SenderID, &m.SenderName, &m.ParentID,
		&m.Body, &m.Type, &m.IsPinned, &m.IsResolved, &m.EditedAt, &m.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Could be not found, wrong sender, or edit window closed — check which
			var exists bool
			_ = r.pool.QueryRow(ctx,
				`SELECT EXISTS(SELECT 1 FROM batch_messages WHERE id = $1 AND sender_id = $2 AND deleted_at IS NULL)`,
				msgID, senderID).Scan(&exists)
			if exists {
				return BatchMessage{}, ErrEditWindowClosed
			}
			return BatchMessage{}, ErrNotFound
		}
		return BatchMessage{}, fmt.Errorf("messaging: update message: %w", err)
	}
	m.Reactions = []ReactionCount{}
	return m, nil
}

func (r *Repo) SoftDeleteMessage(ctx context.Context, orgID, msgID, userID, orgRole string) error {
	var senderID string
	var deletedAt *string
	err := r.pool.QueryRow(ctx,
		`SELECT sender_id, deleted_at::text FROM batch_messages m
		 WHERE m.id = $1
		   AND EXISTS(SELECT 1 FROM batches b WHERE b.id = m.batch_id AND b.org_id = $2)`,
		msgID, orgID).Scan(&senderID, &deletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("messaging: check message: %w", err)
	}
	if deletedAt != nil {
		return ErrNotFound
	}
	isStaff := orgRole == "admin" || orgRole == "instructor" || orgRole == "mentor"
	if senderID != userID && !isStaff {
		return ErrForbidden
	}
	_, err = r.pool.Exec(ctx,
		`UPDATE batch_messages SET deleted_at = now() WHERE id = $1`, msgID)
	return err
}

func (r *Repo) ToggleReaction(ctx context.Context, msgID, userID string, reaction Reaction) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO batch_message_reactions (message_id, user_id, reaction)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (message_id, user_id, reaction) DO NOTHING`,
		msgID, userID, reaction)
	if err != nil {
		return false, fmt.Errorf("messaging: toggle reaction: %w", err)
	}
	if tag.RowsAffected() == 1 {
		return true, nil
	}
	_, err = r.pool.Exec(ctx,
		`DELETE FROM batch_message_reactions WHERE message_id = $1 AND user_id = $2 AND reaction = $3`,
		msgID, userID, reaction)
	if err != nil {
		return false, fmt.Errorf("messaging: remove reaction: %w", err)
	}
	return false, nil
}

func (r *Repo) ResolveMessage(ctx context.Context, orgID, msgID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE batch_messages SET is_resolved = true
		 WHERE id = $1
		   AND EXISTS(SELECT 1 FROM batches b WHERE b.id = batch_id AND b.org_id = $2)`,
		msgID, orgID)
	if err != nil {
		return fmt.Errorf("messaging: resolve message: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) TogglePinMessage(ctx context.Context, orgID, msgID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE batch_messages SET is_pinned = NOT is_pinned
		 WHERE id = $1
		   AND EXISTS(SELECT 1 FROM batches b WHERE b.id = batch_id AND b.org_id = $2)`,
		msgID, orgID)
	if err != nil {
		return fmt.Errorf("messaging: toggle pin: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) PromoteToFAQ(ctx context.Context, orgID, courseID, msgID, createdBy, question, answer string) (CourseFAQ, error) {
	var faq CourseFAQ
	err := r.pool.QueryRow(ctx,
		`INSERT INTO course_faqs (course_id, org_id, question, answer, source_message_id, created_by, position)
		 VALUES ($1, $2, $3, $4, $5, $6,
		   COALESCE((SELECT MAX(position)+1 FROM course_faqs WHERE course_id = $1 AND org_id = $2), 0))
		 RETURNING id, course_id, org_id, question, answer, ai_generated, source_message_id, position, created_at, updated_at`,
		courseID, orgID, question, answer, msgID, createdBy,
	).Scan(&faq.ID, &faq.CourseID, &faq.OrgID, &faq.Question, &faq.Answer,
		&faq.AIGenerated, &faq.SourceMessageID, &faq.Position, &faq.CreatedAt, &faq.UpdatedAt)
	if err != nil {
		return CourseFAQ{}, fmt.Errorf("messaging: promote to faq: %w", err)
	}
	return faq, nil
}

func (r *Repo) ListFAQs(ctx context.Context, orgID, courseID string) ([]CourseFAQ, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, course_id, org_id, question, answer, ai_generated, source_message_id, position, created_at, updated_at
		 FROM course_faqs
		 WHERE course_id = $1 AND org_id = $2
		 ORDER BY position`, courseID, orgID)
	if err != nil {
		return nil, fmt.Errorf("messaging: list faqs: %w", err)
	}
	defer rows.Close()
	out := []CourseFAQ{}
	for rows.Next() {
		var f CourseFAQ
		if err := rows.Scan(&f.ID, &f.CourseID, &f.OrgID, &f.Question, &f.Answer,
			&f.AIGenerated, &f.SourceMessageID, &f.Position, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, fmt.Errorf("messaging: scan faq: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (r *Repo) CreateFAQ(ctx context.Context, orgID, courseID, createdBy, question, answer string) (CourseFAQ, error) {
	var faq CourseFAQ
	err := r.pool.QueryRow(ctx,
		`INSERT INTO course_faqs (course_id, org_id, question, answer, created_by, position)
		 VALUES ($1, $2, $3, $4, $5,
		   COALESCE((SELECT MAX(position)+1 FROM course_faqs WHERE course_id = $1 AND org_id = $2), 0))
		 RETURNING id, course_id, org_id, question, answer, ai_generated, source_message_id, position, created_at, updated_at`,
		courseID, orgID, question, answer, createdBy,
	).Scan(&faq.ID, &faq.CourseID, &faq.OrgID, &faq.Question, &faq.Answer,
		&faq.AIGenerated, &faq.SourceMessageID, &faq.Position, &faq.CreatedAt, &faq.UpdatedAt)
	if err != nil {
		return CourseFAQ{}, fmt.Errorf("messaging: create faq: %w", err)
	}
	return faq, nil
}

func (r *Repo) UpdateFAQ(ctx context.Context, orgID, faqID string, question, answer *string) (CourseFAQ, error) {
	var faq CourseFAQ
	err := r.pool.QueryRow(ctx,
		`UPDATE course_faqs
		 SET question   = COALESCE($1, question),
		     answer     = COALESCE($2, answer),
		     updated_at = now()
		 WHERE id = $3 AND org_id = $4
		 RETURNING id, course_id, org_id, question, answer, ai_generated, source_message_id, position, created_at, updated_at`,
		question, answer, faqID, orgID,
	).Scan(&faq.ID, &faq.CourseID, &faq.OrgID, &faq.Question, &faq.Answer,
		&faq.AIGenerated, &faq.SourceMessageID, &faq.Position, &faq.CreatedAt, &faq.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseFAQ{}, ErrNotFound
		}
		return CourseFAQ{}, fmt.Errorf("messaging: update faq: %w", err)
	}
	return faq, nil
}

func (r *Repo) DeleteFAQ(ctx context.Context, orgID, faqID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM course_faqs WHERE id = $1 AND org_id = $2`, faqID, orgID)
	if err != nil {
		return fmt.Errorf("messaging: delete faq: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) ReorderFAQs(ctx context.Context, orgID, courseID string, faqIDs []string) error {
	if len(faqIDs) == 0 {
		return nil
	}
	positions := make([]int, len(faqIDs))
	for i := range positions {
		positions[i] = i
	}
	return r.tx(ctx, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx,
			`UPDATE course_faqs cf
			 SET position   = u.pos,
			     updated_at = now()
			 FROM unnest($1::uuid[], $2::int[]) AS u(id, pos)
			 WHERE cf.id = u.id AND cf.course_id = $3 AND cf.org_id = $4`,
			faqIDs, positions, courseID, orgID)
		if err != nil {
			return fmt.Errorf("messaging: reorder faqs: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
}

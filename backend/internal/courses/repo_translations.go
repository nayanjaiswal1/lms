package courses

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// ModuleTranslation is one language version of a lesson's body
// (course_modules.content_body). Only the body is translated — see
// migration 049_module_translations.sql.
type ModuleTranslation struct {
	ModuleID    string    `json:"module_id"`
	Locale      string    `json:"locale"`
	ContentBody string    `json:"content_body"`
	UpdatedAt   time.Time `json:"updated_at"`
}

const translationColumns = `mt.module_id, mt.locale, mt.content_body, mt.updated_at`

func (r *Repo) scanTranslations(rows pgx.Rows) ([]ModuleTranslation, error) {
	defer rows.Close()
	out := []ModuleTranslation{}
	for rows.Next() {
		var t ModuleTranslation
		if err := rows.Scan(&t.ModuleID, &t.Locale, &t.ContentBody, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("courses: scan module translation: %w", err)
		}
		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("courses: module translation rows: %w", err)
	}
	return out, nil
}

// ListModuleTranslations returns every translation of a lesson in the caller's
// org, ordered by locale. An empty slice (not ErrNotFound) means the lesson
// exists but is untranslated; ErrNotFound means it isn't visible to the org.
func (r *Repo) ListModuleTranslations(ctx context.Context, orgID, moduleID string) ([]ModuleTranslation, error) {
	if _, err := r.GetModule(ctx, orgID, moduleID); err != nil {
		return nil, err
	}
	rows, err := r.pool.Query(ctx,
		`SELECT `+translationColumns+` FROM module_translations mt
		 WHERE mt.module_id = $1 ORDER BY mt.locale`, moduleID)
	if err != nil {
		return nil, fmt.Errorf("courses: list module translations: %w", err)
	}
	return r.scanTranslations(rows)
}

// ListPublicModuleTranslations is the anonymous counterpart of
// ListModuleTranslations, gated by the same published + is_public filter as
// GetPublicCourseBySlug, and by the module belonging to that course.
func (r *Repo) ListPublicModuleTranslations(ctx context.Context, slug, moduleID string) ([]ModuleTranslation, error) {
	c, err := r.GetPublicCourseBySlug(ctx, slug)
	if err != nil {
		return nil, err
	}
	var exists bool
	if err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM course_modules WHERE id = $1 AND course_id = $2 AND deleted_at IS NULL)`,
		moduleID, c.ID).Scan(&exists); err != nil {
		return nil, fmt.Errorf("courses: check public module: %w", err)
	}
	if !exists {
		return nil, ErrNotFound
	}
	rows, err := r.pool.Query(ctx,
		`SELECT `+translationColumns+` FROM module_translations mt
		 WHERE mt.module_id = $1 ORDER BY mt.locale`, moduleID)
	if err != nil {
		return nil, fmt.Errorf("courses: list public module translations: %w", err)
	}
	return r.scanTranslations(rows)
}

// UpsertModuleTranslation creates or replaces one language version. The
// INSERT ... SELECT joins through courses so a module outside the caller's org
// (or soft-deleted) inserts nothing and surfaces as ErrNotFound.
func (r *Repo) UpsertModuleTranslation(ctx context.Context, orgID, moduleID, locale, body string) (ModuleTranslation, error) {
	var t ModuleTranslation
	err := r.pool.QueryRow(ctx,
		`INSERT INTO module_translations (module_id, locale, content_body)
		 SELECT cm.id, $3, $4 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE cm.id = $1 AND c.org_id = $2 AND cm.deleted_at IS NULL
		 ON CONFLICT (module_id, locale) DO UPDATE SET content_body = EXCLUDED.content_body, updated_at = now()
		 RETURNING module_id, locale, content_body, updated_at`,
		moduleID, orgID, locale, body,
	).Scan(&t.ModuleID, &t.Locale, &t.ContentBody, &t.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ModuleTranslation{}, ErrNotFound
		}
		return ModuleTranslation{}, fmt.Errorf("courses: upsert module translation: %w", err)
	}
	return t, nil
}

// DeleteModuleTranslation removes one language version; ErrNotFound when it
// doesn't exist or the module isn't in the caller's org.
func (r *Repo) DeleteModuleTranslation(ctx context.Context, orgID, moduleID, locale string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM module_translations mt USING course_modules cm, courses c
		 WHERE mt.module_id = $1 AND mt.locale = $3
		   AND cm.id = mt.module_id AND c.id = cm.course_id AND c.org_id = $2`,
		moduleID, orgID, locale)
	if err != nil {
		return fmt.Errorf("courses: delete module translation: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

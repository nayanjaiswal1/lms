package assessment

import (
	"context"
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

// mentorBatchScope limits a mentor to the batches they mentor (a batch_members
// row with role 'mentor', or batches.mentor_id). Owners, admins and
// instructors pass through. Apply to routes carrying a {batchID} URL param.
func mentorBatchScope(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
			role, _ := middleware.LiveOrgRole(r.Context(), pool, claims.UserID, claims.OrgID)
			if role != middleware.RoleMentor {
				next.ServeHTTP(w, r)
				return
			}
			var mentors bool
			err := pool.QueryRow(r.Context(),
				`SELECT EXISTS (
				   SELECT 1 FROM batches b
				   WHERE b.id = $1 AND b.org_id = $2
				     AND (b.mentor_id = $3 OR EXISTS (
				       SELECT 1 FROM batch_members bm
				       WHERE bm.batch_id = b.id AND bm.user_id = $3 AND bm.role = 'mentor')))`,
				httputil.URLParam(r, "batchID"), claims.OrgID, claims.UserID).Scan(&mentors)
			if err != nil || !mentors {
				httputil.WriteError(w, http.StatusForbidden, "You can only access batches you mentor.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// mentoredBatchesSQL selects the ids of the batches a user mentors in an org
// ($1 = org id, $2 = user id). Single source for every mentor predicate.
const mentoredBatchesSQL = `SELECT b.id::text FROM batches b
	WHERE b.org_id = $1
	  AND (b.mentor_id = $2 OR EXISTS (
	    SELECT 1 FROM batch_members bm
	    WHERE bm.batch_id = b.id AND bm.user_id = $2 AND bm.role = 'mentor'))`

// mentorBatchIDs returns the batches userID mentors in orgID.
func mentorBatchIDs(ctx context.Context, pool *pgxpool.Pool, orgID, userID string) ([]string, error) {
	rows, err := pool.Query(ctx, mentoredBatchesSQL, orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("assessment: mentored batches: %w", err)
	}
	defer rows.Close()
	ids := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("assessment: scan mentored batch: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// mentorScopeIDs reports whether the caller is a mentor and, if so, their
// batch ids. Non-mentors (owner/admin/instructor) return scoped=false.
func mentorScopeIDs(ctx context.Context, pool *pgxpool.Pool, claims *auth.Claims) (ids []string, scoped bool, err error) {
	role, _ := middleware.LiveOrgRole(ctx, pool, claims.UserID, claims.OrgID)
	if role != middleware.RoleMentor {
		return nil, false, nil
	}
	ids, err = mentorBatchIDs(ctx, pool, claims.OrgID, claims.UserID)
	return ids, true, err
}

// mentorGate lets non-mentors through and, for a mentor, requires visible to
// accept the request's resource given the mentor's batch ids.
func mentorGate(pool *pgxpool.Pool, deny string,
	visible func(ctx context.Context, r *http.Request, batchIDs []string) (bool, error)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
			ids, scoped, err := mentorScopeIDs(r.Context(), pool, claims)
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "Could not verify access.")
				return
			}
			if scoped {
				ok, err := visible(r.Context(), r, ids)
				if err != nil || !ok {
					httputil.WriteError(w, http.StatusForbidden, deny)
					return
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

// mentorAssessmentScope: a mentor may only open assessments assigned to a
// batch they mentor. Apply to routes carrying {assessmentID}.
func mentorAssessmentScope(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return mentorGate(pool, "You can only access assessments assigned to your batches.",
		func(ctx context.Context, r *http.Request, batchIDs []string) (bool, error) {
			var ok bool
			err := pool.QueryRow(ctx,
				`SELECT EXISTS (SELECT 1 FROM content_assignments ca
				   WHERE ca.content_type = 'assessment' AND ca.content_id::text = $1
				     AND ca.assignee_type = 'batch' AND ca.assignee_id::text = ANY($2))`,
				httputil.URLParam(r, "assessmentID"), batchIDs).Scan(&ok)
			return ok, err
		})
}

// mentorAttemptScope: a mentor may only open attempts made by members of a
// batch they mentor. Apply to routes carrying {attemptID}.
func mentorAttemptScope(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return mentorGate(pool, "You can only access attempts from your batches.",
		func(ctx context.Context, r *http.Request, batchIDs []string) (bool, error) {
			var ok bool
			err := pool.QueryRow(ctx,
				`SELECT EXISTS (SELECT 1 FROM assessment_attempts at
				   JOIN batch_members bm ON bm.user_id = at.user_id
				   WHERE at.id::text = $1 AND bm.batch_id::text = ANY($2))`,
				httputil.URLParam(r, "attemptID"), batchIDs).Scan(&ok)
			return ok, err
		})
}

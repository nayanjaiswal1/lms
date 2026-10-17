package assessment

import (
	"context"
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

// PermManageBatches is the batch-authoring code; holders see every batch,
// everyone else on a results route is scoped to the batches they mentor.
const PermManageBatches = "assessments.manage_batches"

// mentorScoped reports whether the caller must be limited to the batches
// they mentor: true unless they hold assessments.manage_batches.
func mentorScoped(ctx context.Context, perms *authz.Service, claims *auth.Claims) (bool, error) {
	unscoped, err := perms.HasPermission(ctx, claims.UserID, claims.OrgID, PermManageBatches)
	if err != nil {
		return false, fmt.Errorf("assessment: mentor scope: %w", err)
	}
	return !unscoped, nil
}

// mentorBatchScope limits a caller without assessments.manage_batches to the
// batches they mentor (a batch_members row with role 'mentor', or
// batches.mentor_id). Apply to routes carrying a {batchID} URL param.
func mentorBatchScope(pool *pgxpool.Pool, perms *authz.Service) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.RequireClaims(w, r)
			if !ok {
				return
			}
			scoped, err := mentorScoped(r.Context(), perms, claims)
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "Could not verify access.")
				return
			}
			if !scoped {
				next.ServeHTTP(w, r)
				return
			}
			var mentors bool
			err = pool.QueryRow(r.Context(),
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

// mentorScopeIDs reports whether the caller is mentor-scoped and, if so,
// their batch ids. assessments.manage_batches holders return scoped=false.
func mentorScopeIDs(ctx context.Context, pool *pgxpool.Pool, perms *authz.Service, claims *auth.Claims) (ids []string, scoped bool, err error) {
	if scoped, err = mentorScoped(ctx, perms, claims); err != nil || !scoped {
		return nil, false, err
	}
	ids, err = mentorBatchIDs(ctx, pool, claims.OrgID, claims.UserID)
	return ids, true, err
}

// mentorGate lets unscoped callers through and, for a mentor-scoped one,
// requires visible to accept the request's resource given their batch ids.
func mentorGate(pool *pgxpool.Pool, perms *authz.Service, deny string,
	visible func(ctx context.Context, r *http.Request, batchIDs []string) (bool, error)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.RequireClaims(w, r)
			if !ok {
				return
			}
			ids, scoped, err := mentorScopeIDs(r.Context(), pool, perms, claims)
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
func mentorAssessmentScope(pool *pgxpool.Pool, perms *authz.Service) func(http.Handler) http.Handler {
	return mentorGate(pool, perms, "You can only access assessments assigned to your batches.",
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
func mentorAttemptScope(pool *pgxpool.Pool, perms *authz.Service) func(http.Handler) http.Handler {
	return mentorGate(pool, perms, "You can only access attempts from your batches.",
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

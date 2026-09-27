package workspace

import (
	"context"
	"fmt"
)

// sod.go is the single separation-of-duties check (02 §8, 00-decisions D13).
// Every transition, review, approval and assignment path calls it; nobody —
// owner, manager or overseer — skips it. It reads the assignee and version
// rows inside the caller's transaction, after the item row is locked, so a
// concurrent reassignment can't slip between the check and the write.

// SoD actions.
const (
	SodReviewCode = "review_code" // approve/request changes on code
	SodApproveDoc = "approve_doc" // approve a feature spec version
	SodTestPass   = "test_pass"   // testing → done
	SodTestFail   = "test_fail"   // testing → reopened
	SodSetDone    = "set_done"    // any path into done
)

// SodCheck returns ErrSoD when actorID may not perform action on itemID.
//   - review_code: actor holds reviewer and is not a developer on the item.
//   - approve_doc: actor holds reviewer and authored no version of the spec
//     page since the last approved version (the creator of v1 counts while
//     the spec was never approved).
//   - test_pass / test_fail / set_done: actor is not a developer on the item.
func SodCheck(ctx context.Context, db DBTX, itemID, actorID, action string) error {
	var isDeveloper, isReviewer bool
	if err := db.QueryRow(ctx,
		`SELECT COALESCE(bool_or(role = 'developer'), false), COALESCE(bool_or(role = 'reviewer'), false)
		   FROM work_item_assignees WHERE item_id = $1 AND user_id = $2`,
		itemID, actorID,
	).Scan(&isDeveloper, &isReviewer); err != nil {
		return fmt.Errorf("workspace: sod: load roles: %w", err)
	}

	switch action {
	case SodReviewCode:
		if !isReviewer || isDeveloper {
			return ErrSoD
		}
	case SodApproveDoc:
		if !isReviewer {
			return ErrSoD
		}
		var authored bool
		if err := db.QueryRow(ctx,
			`SELECT EXISTS(
			   SELECT 1 FROM work_items w
			   JOIN content_versions cv ON cv.content_type = 'wiki_page' AND cv.content_id = w.doc_wiki_page_id
			  WHERE w.id = $1 AND cv.created_by = $2
			    AND cv.version > COALESCE(w.approved_doc_version, 0))`,
			itemID, actorID,
		).Scan(&authored); err != nil {
			return fmt.Errorf("workspace: sod: doc authorship: %w", err)
		}
		if authored {
			return ErrSoD
		}
	case SodTestPass, SodTestFail, SodSetDone:
		if isDeveloper {
			return ErrSoD
		}
	default:
		return fmt.Errorf("workspace: sod: unknown action %q", action)
	}
	return nil
}

// ValidateAssigneeRoles enforces the per-item role rules that don't need the
// database: exactly-one-owner is also a partial unique index, but reviewer ≠
// developer and tester ≠ developer can only be checked here (design §7).
func ValidateAssigneeRoles(in []AssigneeInput) error {
	dev := map[string]bool{}
	owners := 0
	for _, a := range in {
		switch a.Role {
		case AssigneeDeveloper:
			dev[a.UserID] = true
		case AssigneeOwner:
			owners++
		case AssigneeReviewer, AssigneeTester:
		default:
			return fmt.Errorf("%w: unknown assignee role %q", ErrInvalidInput, a.Role)
		}
	}
	if owners > 1 {
		return fmt.Errorf("%w: an item has exactly one owner", ErrInvalidInput)
	}
	for _, a := range in {
		if (a.Role == AssigneeReviewer || a.Role == AssigneeTester) && dev[a.UserID] {
			return ErrSoD
		}
	}
	return nil
}

// Package labblock is the leaf (import-cycle-free) vocabulary of the lab
// authoring engine: the block.yaml manifest types, the structured validation
// Issue, the resolved-recipe model and a tiny semver implementation. It is
// imported by both internal/labkinds (lab-kind plugins implement
// ValidateRecipe over these types) and internal/labauthor (the engine), so it
// must not import either. See docs/debug-labs.md Part 2 §B1-B2.
package labblock

// Severity of an Issue. Only SeverityError issues make a recipe invalid.
type Severity string

const (
	SeverityError   Severity = "error"
	SeverityWarning Severity = "warning"
	SeverityInfo    Severity = "info"
)

// Issue is one structured validation finding, shaped for the builder UI to
// render per wizard step: Code is stable and machine-readable, Block is the
// block key (or "" for a recipe-level finding), Message is human text.
type Issue struct {
	Code     string   `json:"code"`
	Block    string   `json:"block,omitempty"`
	Message  string   `json:"message"`
	Severity Severity `json:"severity"`
}

// Errf builds an error-severity Issue.
func Errf(code, block, msg string) Issue {
	return Issue{Code: code, Block: block, Message: msg, Severity: SeverityError}
}

// Warnf builds a warning-severity Issue.
func Warnf(code, block, msg string) Issue {
	return Issue{Code: code, Block: block, Message: msg, Severity: SeverityWarning}
}

// HasErrors reports whether any issue is error-severity.
func HasErrors(issues []Issue) bool {
	for _, i := range issues {
		if i.Severity == SeverityError {
			return true
		}
	}
	return false
}

// Issue codes emitted by the engine (labauthor) and by lab-kind plugins.
// Stable: the frontend keys per-step messages off them.
const (
	CodeManifestInvalid   = "manifest_invalid"
	CodeUnknownKind       = "unknown_block_kind"
	CodeStackMismatch     = "stack_mismatch"
	CodeAppRange          = "app_version_range"
	CodeUnsatisfied       = "requirement_unsatisfied"
	CodeSlotConflict      = "slot_conflict"
	CodeChainInvalid      = "chain_invalid"
	CodeChainTooLong      = "chain_too_long"
	CodeConflict          = "block_conflict"
	CodeCheckCoverage     = "check_coverage"
	CodeCarrierCoverage   = "carrier_coverage"
	CodeBudget            = "budget_exceeded"
	CodeBlockYanked       = "block_yanked"
	CodeBlockNotFound     = "block_not_found"
	CodeBlockForeignOrg   = "block_foreign_org"
	CodeParamInvalid      = "param_invalid"
	CodeParamLiteral      = "param_literal_unsafe"
	CodePoolInvalid       = "pool_invalid"
	CodeVariantsCapped    = "variants_capped"
	CodeRoleCardinality   = "role_cardinality"
	CodeDifficultyDerived = "difficulty_derived"
)

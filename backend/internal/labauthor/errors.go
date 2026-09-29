package labauthor

import (
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// Domain errors. Each maps to an HTTP status and a stable envelope `code`
// (see errSpecs); clients switch on the code, never the message.
var (
	ErrBlockNotFound    = errors.New("labauthor: block not found")
	ErrBlockKeyTaken    = errors.New("labauthor: block key already exists in this organization")
	ErrBlockIdentity    = errors.New("labauthor: a block's key and kind cannot change between versions")
	ErrBlockInUse       = errors.New("labauthor: block is used by a recipe or build")
	ErrBlockNotEditable = errors.New("labauthor: only ticket, hints, rubric and preset blocks can be authored in the UI")
	ErrVersionImmutable = errors.New("labauthor: that version already exists; block versions are immutable, publish a new version")
	ErrNoChange         = errors.New("labauthor: content is identical to an existing version")
	ErrAlreadyYanked    = errors.New("labauthor: version is already yanked")
	ErrRecipeNotFound   = errors.New("labauthor: recipe not found")
	ErrRevisionConflict = errors.New("labauthor: recipe was changed by someone else; reload and retry")
	ErrRecipeInUse      = errors.New("labauthor: recipe has published labs")
	ErrUnknownLabKind   = errors.New("labauthor: unknown lab kind")
	ErrRateLimited      = errors.New("labauthor: too many AI drafts; try again later")
	ErrAIUnavailable    = errors.New("labauthor: AI drafting is unavailable")
	ErrInvalidInput     = errors.New("labauthor: invalid input")
)

// Machine-readable codes in the API error envelope. The frontend mirrors them
// (frontend/lib/labauthor.ts, added with the builder UI) - keep in sync.
const (
	CodeRecipeInvalid      = "recipe_invalid"
	CodeBlockYanked        = "block_yanked"
	CodeBlockVersionImmut  = "block_version_immutable"
	CodeBlockNotFound      = "block_not_found"
	CodeBlockKeyTaken      = "block_key_taken"
	CodeBlockInUse         = "block_in_use"
	CodeBlockNotEditable   = "block_not_editable"
	CodeBlockNoChange      = "block_no_change"
	CodeBlockAlreadyYanked = "block_already_yanked"
	CodeRecipeNotFound     = "recipe_not_found"
	CodeRevisionConflict   = "recipe_revision_conflict"
	CodeRecipeInUse        = "recipe_in_use"
	CodeUnknownLabKind     = "unknown_lab_kind"
	CodeRateLimited        = "rate_limited"
	CodeAIUnavailable      = "ai_unavailable"
	CodeInvalidInput       = "invalid_input"
)

var errSpecs = map[error]httputil.ErrSpec{
	ErrBlockNotFound:    {Status: http.StatusNotFound, Code: CodeBlockNotFound, Message: "Block not found."},
	ErrBlockKeyTaken:    {Status: http.StatusConflict, Code: CodeBlockKeyTaken},
	ErrBlockIdentity:    {Status: http.StatusUnprocessableEntity, Code: CodeInvalidInput},
	ErrBlockInUse:       {Status: http.StatusConflict, Code: CodeBlockInUse},
	ErrBlockNotEditable: {Status: http.StatusForbidden, Code: CodeBlockNotEditable},
	ErrVersionImmutable: {Status: http.StatusConflict, Code: CodeBlockVersionImmut},
	ErrNoChange:         {Status: http.StatusConflict, Code: CodeBlockNoChange},
	ErrAlreadyYanked:    {Status: http.StatusConflict, Code: CodeBlockAlreadyYanked},
	ErrRecipeNotFound:   {Status: http.StatusNotFound, Code: CodeRecipeNotFound, Message: "Recipe not found."},
	ErrRevisionConflict: {Status: http.StatusConflict, Code: CodeRevisionConflict},
	ErrRecipeInUse:      {Status: http.StatusConflict, Code: CodeRecipeInUse},
	ErrUnknownLabKind:   {Status: http.StatusUnprocessableEntity, Code: CodeUnknownLabKind},
	ErrRateLimited:      {Status: http.StatusTooManyRequests, Code: CodeRateLimited},
	ErrAIUnavailable:    {Status: http.StatusServiceUnavailable, Code: CodeAIUnavailable},
	ErrInvalidInput:     {Status: http.StatusUnprocessableEntity, Code: CodeInvalidInput},
}

// InvalidRecipeError carries the validation issues that made a recipe (or a
// save of one) unacceptable.
type InvalidRecipeError struct{ Analysis *Analysis }

func (e *InvalidRecipeError) Error() string { return "labauthor: recipe is invalid" }

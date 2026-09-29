package handlers

import "github.com/mindforge/backend/internal/labbuild"

// Lab-authoring build pipeline job names (bodies live in internal/labbuild,
// which owns the render/verify/publish flow; see docs/debug-labs.md Phase 1c-ii).
const (
	// HandlerLabRecipeBuild renders a queued build's variants in a sandbox.
	HandlerLabRecipeBuild = labbuild.HandlerRecipeBuild
	// HandlerLabRecipeVerify runs the verification matrix for a rendered build.
	HandlerLabRecipeVerify = labbuild.HandlerRecipeVerify
	// HandlerLabPlatformRecipes builds and auto-publishes platform recipes.
	HandlerLabPlatformRecipes = labbuild.HandlerPlatformRecipes
	// HandlerLabBuildGC deletes failed/superseded unpublished builds after 30 days.
	HandlerLabBuildGC = labbuild.HandlerBuildGC
)

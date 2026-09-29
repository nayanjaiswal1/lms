package canonical

import "github.com/google/uuid"

// Namespace seeds every deterministic ID this package generates. It is a
// fixed constant (not uuid.New()) so that regenerating fixtures from the same
// canonical markdown always produces byte-identical UUIDs — required for the
// generator's idempotent ON CONFLICT DO UPDATE fixture output described in
// the content-pipeline plan.
var Namespace = uuid.MustParse("d103a75d-059a-4aa1-ad6e-faffdc931000")

// ID derives a stable UUID for an entity from its canonical id_key. suffix
// disambiguates rows derived from the same id_key — e.g. a lab's own row vs.
// its section vs. one of its tasks — so unrelated entities never collide even
// when they share an id_key prefix.
//
// Suffixes used by downstream consumers (the generator):
//
//	"course"                 - courses row
//	"section"                - course_sections row
//	"module"                 - course_modules row
//	"lab"                    - lab_definitions row
//	"task:"+task.IDKey       - lab_tasks row
//	"version"                - lab_task_versions row
//	"assessment"             - assessments row
//	"question:"+q.IDKey      - questions row
//	"qversion:"+q.IDKey      - question_versions row
//	"aq:"+q.IDKey            - assessment_questions row
func ID(idKey, suffix string) string {
	return uuid.NewSHA1(Namespace, []byte(idKey+":"+suffix)).String()
}

// Platform lab-block ids: a block shipped in the repo (content/lab-blocks,
// synced by `coursegen blocks sync`) has a UUIDv5 identity derived from its key
// (and version), so recipes authored in canonical markdown can reference block
// versions by id before the blocks are ever loaded into a database. labauthor
// uses the same functions when it emits the sync SQL.

// LabBlockID is the lab_blocks.id of a platform block key.
func LabBlockID(key string) string { return ID(key, "lab_block") }

// LabBlockVersionID is the lab_block_versions.id of a platform block version.
func LabBlockVersionID(key, version string) string { return ID(key+"@"+version, "lab_block_version") }

// LabRecipeID is the lab_recipes.id of a canonical lab document's platform recipe.
func LabRecipeID(labIDKey string) string { return ID(labIDKey, "recipe") }

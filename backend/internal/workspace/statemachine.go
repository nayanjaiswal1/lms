package workspace

// statemachine.go is the only place the workspace lifecycle rules live:
// project status, brief status, feature-doc status, work-item status and the
// item hierarchy. Services ask these tables; nothing else hard-codes an edge.

// Machine is an allow-list of from→to edges.
type Machine map[string]map[string]bool

// Allowed reports whether from→to is a legal edge.
func (m Machine) Allowed(from, to string) bool { return m[from][to] }

// Next lists the legal targets from a state (unordered).
func (m Machine) Next(from string) []string {
	out := make([]string, 0, len(m[from]))
	for to := range m[from] {
		out = append(out, to)
	}
	return out
}

func newMachine(edges map[string][]string) Machine {
	m := make(Machine, len(edges))
	for from, tos := range edges {
		m[from] = make(map[string]bool, len(tos))
		for _, to := range tos {
			m[from][to] = true
		}
	}
	return m
}

// ProjectStatusMachine is the project lifecycle (design §4).
var ProjectStatusMachine = newMachine(map[string][]string{
	ProjectDraft:      {ProjectRecruiting, ProjectCancelled},
	ProjectRecruiting: {ProjectActive, ProjectCancelled},
	ProjectActive:     {ProjectPaused, ProjectCompleted, ProjectCancelled},
	ProjectPaused:     {ProjectActive, ProjectCancelled},
	ProjectCompleted:  {ProjectArchived},
	ProjectCancelled:  {ProjectArchived},
})

// BriefStatusMachine is the vague-requirement → agreed-brief flow (design §6b).
var BriefStatusMachine = newMachine(map[string][]string{
	BriefRaw:        {BriefClarifying},
	BriefClarifying: {BriefAgreed},
	BriefAgreed:     {BriefClarifying},
})

// DocStatusMachine is the feature-spec review gate (design §8).
var DocStatusMachine = newMachine(map[string][]string{
	DocDraft:            {DocInReview},
	DocInReview:         {DocApproved, DocChangesRequested},
	DocChangesRequested: {DocInReview},
	DocApproved:         {DocInReview},
})

// WorkItemStatusMachine covers task/bug/subtask. Epic and feature status is a
// roll-up of children and is never transitioned by hand.
var WorkItemStatusMachine = newMachine(map[string][]string{
	ItemTodo:       {ItemInProgress, ItemBlocked, ItemWontDo},
	ItemInProgress: {ItemInReview, ItemBlocked, ItemWontDo},
	ItemInReview:   {ItemTesting, ItemInProgress, ItemBlocked, ItemWontDo},
	ItemTesting:    {ItemDone, ItemReopened, ItemBlocked},
	ItemBlocked:    {ItemTodo, ItemInProgress, ItemInReview, ItemTesting, ItemWontDo},
	ItemDone:       {ItemReopened},
	ItemReopened:   {ItemInProgress},
})

// HierarchyRules maps a parent type ("" = project root) to the child types it
// may hold: epic > feature > task|bug > subtask. Because a parent is always a
// strictly higher level, parent chains can't form cycles.
var HierarchyRules = map[string][]string{
	"":              {ItemTypeEpic, ItemTypeBug},
	ItemTypeEpic:    {ItemTypeFeature, ItemTypeBug},
	ItemTypeFeature: {ItemTypeTask, ItemTypeBug},
	ItemTypeTask:    {ItemTypeSubtask},
	ItemTypeBug:     {ItemTypeSubtask},
}

// ChildAllowed reports whether childType may sit under parentType ("" = root).
func ChildAllowed(parentType, childType string) bool {
	for _, t := range HierarchyRules[parentType] {
		if t == childType {
			return true
		}
	}
	return false
}

// IsRollupType reports whether an item's status is computed from children.
func IsRollupType(itemType string) bool {
	return itemType == ItemTypeEpic || itemType == ItemTypeFeature
}

// IsOpenItemStatus reports whether a status still counts as open work.
func IsOpenItemStatus(status string) bool {
	return status != ItemDone && status != ItemWontDo
}

// HasPath reports whether target is reachable from start over edges — the
// shared DFS used for blocks-link cycle checks once the graph is loaded
// under the project graph lock.
func HasPath(edges map[string][]string, start, target string) bool {
	seen := map[string]bool{}
	stack := []string{start}
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if n == target {
			return true
		}
		if seen[n] {
			continue
		}
		seen[n] = true
		stack = append(stack, edges[n]...)
	}
	return false
}

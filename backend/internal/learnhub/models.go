package learnhub

// Stats is the payload for GET /api/learn/hub-stats — one cheap count per
// Learn hub card, computed with COUNT(*)/SUM() queries instead of the
// per-domain full-list fetches the hub page used to make.
type Stats struct {
	EnrollmentCount        int  `json:"enrollment_count"`
	HasRoadmap             bool `json:"has_roadmap"`
	RoadmapModuleCount     int  `json:"roadmap_module_count"`
	RoadmapCompletedCount  int  `json:"roadmap_completed_count"`
	PrepPlanCount          int  `json:"prep_plan_count"`
	PendingAssessmentCount int  `json:"pending_assessment_count"`
	SavedHighlightCount    int  `json:"saved_highlight_count"`
	DueCardCount           int  `json:"due_card_count"`
	SheetTotalCount        int  `json:"sheet_total_count"`
	SheetSolvedCount       int  `json:"sheet_solved_count"`
	WikiSpaceCount         int  `json:"wiki_space_count"`
	InterviewExpPostCount  int  `json:"interview_exp_post_count"`
}

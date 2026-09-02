package project

import "time"

// Project is a lightweight, personally-owned named list — not
// project_requirements (an org-scoped staff marketplace board, a different
// domain). Exists primarily as a task_links target_type='project' target and
// a simple grouping label: no status workflow, no members.
type Project struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"createdAt"`
}

// CreateRequest is the body for POST /api/projects.
type CreateRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

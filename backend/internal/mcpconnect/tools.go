package mcpconnect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/interviewprep"
	"github.com/mindforge/backend/internal/mistakes"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/systemdesign"
)

var errMissingScope = errors.New("mcpconnect: connection is missing a required scope")

// mcpTool bundles a tool's MCP-facing definition with its handler, so
// tools/list and tools/call always agree on name/schema/required-scope in one
// place instead of two definitions drifting apart.
type mcpTool struct {
	Name        string
	Description string
	Scope       string
	InputSchema map[string]any
	Call        func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error)
	// TargetType labels the kind of thing this tool acts on, for the action
	// log's display — "" for tools with no single target (list/get-context).
	TargetType string
	// BeforeState captures the pre-call snapshot a Revert will restore. nil
	// for read-only tools (nothing to revert) and create-type tools (nothing
	// existed before).
	BeforeState func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error)
	// Revert undoes a previously-applied call of this tool using its logged
	// before/after snapshots. nil means the tool is not revertible (every
	// read-only tool, plus any mutation whose undo would touch state outside
	// the caller's control — see propose_module_to_org_course once approved).
	Revert func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error
}

func argString(args map[string]any, key string) (string, error) {
	v, ok := args[key].(string)
	if !ok || v == "" {
		return "", fmt.Errorf("missing required argument %q", key)
	}
	return v, nil
}

// optString returns args[key] as a *string, nil if absent/empty — for
// optional patch-style fields (notes, event_type overrides).
func optString(args map[string]any, key string) *string {
	v, ok := args[key].(string)
	if !ok || v == "" {
		return nil
	}
	return &v
}

// argTime parses a required RFC3339 timestamp argument (e.g. "2026-08-01T15:00:00Z").
func argTime(args map[string]any, key string) (time.Time, error) {
	raw, err := argString(args, key)
	if err != nil {
		return time.Time{}, err
	}
	t, err := time.Parse(time.RFC3339, raw)
	if err != nil {
		return time.Time{}, fmt.Errorf("%q must be an RFC3339 timestamp (e.g. 2026-08-01T15:00:00Z): %w", key, err)
	}
	return t, nil
}

// optTime parses an optional RFC3339 timestamp argument, nil if absent/empty.
func optTime(args map[string]any, key string) (*time.Time, error) {
	raw, ok := args[key].(string)
	if !ok || raw == "" {
		return nil, nil
	}
	t, err := time.Parse(time.RFC3339, raw)
	if err != nil {
		return nil, fmt.Errorf("%q must be an RFC3339 timestamp (e.g. 2026-08-01T15:00:00Z): %w", key, err)
	}
	return &t, nil
}

// argScene decodes args[key] (a JSON-RPC object) into a systemdesign.Scene —
// the MCP wire format for a scene arg is already the same shape Scene
// marshals to, so round-tripping through json is simpler than hand-mapping
// each field.
func argScene(args map[string]any, key string) (systemdesign.Scene, error) {
	raw, ok := args[key]
	if !ok {
		return systemdesign.Scene{}, fmt.Errorf("missing required argument %q", key)
	}
	b, err := json.Marshal(raw)
	if err != nil {
		return systemdesign.Scene{}, fmt.Errorf("%q: %w", key, err)
	}
	var scene systemdesign.Scene
	if err := json.Unmarshal(b, &scene); err != nil {
		return systemdesign.Scene{}, fmt.Errorf("%q must be an Excalidraw scene object ({\"elements\": [...], \"appState\": {...}}): %w", key, err)
	}
	return scene, nil
}

// entryArgString reads a string field back out of a logged ActionLogEntry's
// Args — which decodes from jsonb as map[string]any, not the original
// map[string]any the tool call received, so this is a plain type assertion
// rather than a second argString-style validator.
func entryArgString(entry ActionLogEntry, key string) (string, bool) {
	m, ok := entry.Args.(map[string]any)
	if !ok {
		return "", false
	}
	v, ok := m[key].(string)
	return v, ok
}

var tools = []mcpTool{
	{
		Name:        "list_my_courses",
		Description: "List the courses the connected student is enrolled in.",
		Scope:       ScopeCoursesRead,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.coursesRepo.GetMyEnrollments(ctx, id.UserID, id.OrgID)
		},
	},
	{
		Name:        "get_lesson",
		Description: "Read a lesson module's content (title, body, knowledge checks) the student is enrolled to see.",
		Scope:       ScopeCoursesRead,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"module_id": map[string]any{"type": "string"}},
			"required":   []string{"module_id"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.GetModuleContent(ctx, id.OrgID, id.UserID, moduleID)
		},
	},
	{
		Name:        "get_my_lesson_note",
		Description: "Read the student's personal note for a lesson module, if they have one.",
		Scope:       ScopeNotesWrite,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"module_id": map[string]any{"type": "string"}},
			"required":   []string{"module_id"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			note, err := rt.coursesSvc.GetMyLessonNote(ctx, id.OrgID, id.UserID, moduleID)
			if errors.Is(err, courses.ErrNotFound) {
				return map[string]any{"content": nil}, nil
			}
			return note, err
		},
	},
	{
		Name:        "save_my_lesson_note",
		Description: "Write or replace the student's personal note for a lesson module — use this when the student asks you to save an explanation or summary to their notes.",
		Scope:       ScopeNotesWrite,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id": map[string]any{"type": "string"},
				"content":   map[string]any{"type": "string", "description": "The full note text to save, replacing any previous note for this module."},
			},
			"required": []string{"module_id", "content"},
		},
		TargetType: "course_module",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			note, err := rt.coursesSvc.GetMyLessonNote(ctx, id.OrgID, id.UserID, moduleID)
			if errors.Is(err, courses.ErrNotFound) {
				return nil, nil
			}
			return note, err
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			content, err := argString(args, "content")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.SaveLessonNote(ctx, id.OrgID, id.UserID, moduleID, content, "ai")
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			if entry.BeforeState == nil {
				return rt.coursesRepo.DeleteLessonNote(ctx, id.OrgID, id.UserID, entry.TargetID)
			}
			var before courses.LessonNote
			if err := decodeBeforeState(entry, &before); err != nil {
				return err
			}
			_, err := rt.coursesSvc.SaveLessonNote(ctx, id.OrgID, id.UserID, entry.TargetID, before.Content, before.Source)
			return err
		},
	},
	{
		Name:        "log_understanding",
		Description: "Record what the student said they understood or struggled with about a lesson — use this after helping them work through a concept, so MindForge can weight it into their revision plan.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id": map[string]any{"type": "string"},
				"summary":   map[string]any{"type": "string", "description": "A short summary, in the student's own terms where possible, of what they now understand or where they're still stuck."},
			},
			"required": []string{"module_id", "summary"},
		},
		TargetType: "course_module",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			ref, err := rt.coursesSvc.GetMyReflection(ctx, id.OrgID, id.UserID, moduleID)
			if errors.Is(err, courses.ErrNotFound) {
				return nil, nil
			}
			return ref, err
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			summary, err := argString(args, "summary")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.LogUnderstanding(ctx, id.OrgID, id.UserID, moduleID, summary)
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			if entry.BeforeState == nil {
				return rt.coursesRepo.DeleteReflection(ctx, id.OrgID, id.UserID, entry.TargetID)
			}
			var before courses.LessonReflection
			if err := decodeBeforeState(entry, &before); err != nil {
				return err
			}
			_, err := rt.coursesRepo.UpsertReflection(ctx, courses.LessonReflection{
				OrgID: id.OrgID, UserID: id.UserID, ModuleID: entry.TargetID, Response: before.Response, Source: before.Source,
			})
			return err
		},
	},
	{
		Name:        "list_calendar_events",
		Description: "List the student's calendar events within a date range.",
		Scope:       ScopeCalendarManage,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"from": map[string]any{"type": "string", "description": "RFC3339 start of range, e.g. 2026-08-01T00:00:00Z"},
				"to":   map[string]any{"type": "string", "description": "RFC3339 end of range, e.g. 2026-08-31T23:59:59Z"},
			},
			"required": []string{"from", "to"},
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			from, err := argTime(args, "from")
			if err != nil {
				return nil, err
			}
			to, err := argTime(args, "to")
			if err != nil {
				return nil, err
			}
			return rt.calendarSvc.ListRange(ctx, id.OrgID, id.UserID, from, to)
		},
	},
	{
		Name:        "create_calendar_event",
		Description: "Create a new event on the student's calendar (e.g. a study reminder or deadline).",
		Scope:       ScopeCalendarManage,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"title":      map[string]any{"type": "string"},
				"starts_at":  map[string]any{"type": "string", "description": "RFC3339 timestamp"},
				"ends_at":    map[string]any{"type": "string", "description": "Optional RFC3339 timestamp"},
				"notes":      map[string]any{"type": "string"},
				"event_type": map[string]any{"type": "string", "description": "One of: custom, task, deadline. Defaults to custom."},
				"priority":   map[string]any{"type": "string", "description": "Task priority, one of: low, medium, high, urgent. Only meaningful when event_type is task."},
			},
			"required": []string{"title", "starts_at"},
		},
		TargetType: "calendar_event",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			title, err := argString(args, "title")
			if err != nil {
				return nil, err
			}
			startsAt, err := argTime(args, "starts_at")
			if err != nil {
				return nil, err
			}
			endsAt, err := optTime(args, "ends_at")
			if err != nil {
				return nil, err
			}
			eventType := calendar.EventTypeCustom
			if v, ok := args["event_type"].(string); ok && v != "" {
				eventType = v
			}
			return rt.calendarSvc.CreateEvent(ctx, calendar.Event{
				OrgID:     id.OrgID,
				CreatedBy: id.UserID,
				EventType: eventType,
				Title:     title,
				Notes:     optString(args, "notes"),
				StartsAt:  startsAt,
				EndsAt:    endsAt,
				Priority:  optString(args, "priority"),
			}, nil)
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			return rt.calendarSvc.DeleteEvent(ctx, id.OrgID, entry.TargetID, id.UserID, calendar.ScopeSeries, nil)
		},
	},
	{
		Name:        "update_calendar_event",
		Description: "Update an existing calendar event the student owns or can edit. For a recurring event this updates the whole series.",
		Scope:       ScopeCalendarManage,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"event_id":  map[string]any{"type": "string"},
				"title":     map[string]any{"type": "string"},
				"starts_at": map[string]any{"type": "string", "description": "RFC3339 timestamp"},
				"ends_at":   map[string]any{"type": "string", "description": "Optional RFC3339 timestamp"},
				"notes":     map[string]any{"type": "string"},
				"priority":  map[string]any{"type": "string", "description": "Task priority, one of: low, medium, high, urgent. Only meaningful when event_type is task."},
			},
			"required": []string{"event_id", "title", "starts_at"},
		},
		TargetType: "calendar_event",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			eventID, err := argString(args, "event_id")
			if err != nil {
				return nil, err
			}
			current, _, _, err := rt.calendarSvc.GetEvent(ctx, id.OrgID, eventID, id.UserID)
			return current, err
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			eventID, err := argString(args, "event_id")
			if err != nil {
				return nil, err
			}
			// UpdateEvent overwrites every column Repo.Update touches (including
			// batch_id/course_id/entity_type/entity_id/meeting_url/all_day), so
			// the patch must start from the current row — the same merge the
			// HTTP handler's eventRequest.applyTo does — rather than a bare
			// struct literal, which would silently wipe fields this tool never
			// meant to touch.
			current, _, _, err := rt.calendarSvc.GetEvent(ctx, id.OrgID, eventID, id.UserID)
			if err != nil {
				return nil, err
			}
			title, err := argString(args, "title")
			if err != nil {
				return nil, err
			}
			startsAt, err := argTime(args, "starts_at")
			if err != nil {
				return nil, err
			}
			endsAt, err := optTime(args, "ends_at")
			if err != nil {
				return nil, err
			}
			patch := current
			patch.Title = title
			patch.StartsAt = startsAt
			patch.EndsAt = endsAt
			if notes := optString(args, "notes"); notes != nil {
				patch.Notes = notes
			}
			if priority := optString(args, "priority"); priority != nil {
				patch.Priority = priority
			}
			return rt.calendarSvc.UpdateEvent(ctx, id.OrgID, eventID, id.UserID, calendar.ScopeSeries, nil, patch)
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			var before calendar.Event
			if err := decodeBeforeState(entry, &before); err != nil {
				return err
			}
			_, err := rt.calendarSvc.UpdateEvent(ctx, id.OrgID, entry.TargetID, id.UserID, calendar.ScopeSeries, nil, before)
			return err
		},
	},
	{
		Name:        "delete_calendar_event",
		Description: "Delete a calendar event the student owns or can edit. For a recurring event this deletes the whole series.",
		Scope:       ScopeCalendarManage,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"event_id": map[string]any{"type": "string"}},
			"required":   []string{"event_id"},
		},
		TargetType: "calendar_event",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			eventID, err := argString(args, "event_id")
			if err != nil {
				return nil, err
			}
			current, _, _, err := rt.calendarSvc.GetEvent(ctx, id.OrgID, eventID, id.UserID)
			return current, err
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			eventID, err := argString(args, "event_id")
			if err != nil {
				return nil, err
			}
			if err := rt.calendarSvc.DeleteEvent(ctx, id.OrgID, eventID, id.UserID, calendar.ScopeSeries, nil); err != nil {
				return nil, err
			}
			return map[string]any{"deleted": true}, nil
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			_, err := rt.calendarSvc.RestoreEvent(ctx, id.OrgID, entry.TargetID, id.UserID)
			return err
		},
	},
	{
		Name:        "get_random_topic",
		Description: "Pick one published course from the student's org catalog they haven't tried yet — a \"surprise me\" suggestion for when they don't know what to learn next. Weighted toward their stated topic interests when possible; falls back to any unstarted course, then (only if they've enrolled in everything) any course at all.",
		Scope:       ScopeCoursesRead,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.coursesSvc.GetRandomTopic(ctx, id.OrgID, id.UserID)
		},
	},
	{
		Name:        "get_learning_context",
		Description: "Call this FIRST, before anything else, at the start of any conversation about the student's courses, practice, or progress — including English practice. Returns their enrolled courses with completion percentages, their most recent lesson reflections (what they recently understood or struggled with, across every course), and the most recently added/edited lessons in their own private self-courses. This exists so the student never has to re-explain their level, recent mistakes, or what they were last working on — check here before asking them to recap.",
		Scope:       ScopeCoursesRead,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.coursesSvc.GetLearningContext(ctx, id.OrgID, id.UserID)
		},
	},
	{
		Name:        "create_self_course",
		Description: "Create the student's own private course — either from scratch, or (if fork_from_course_id is given) by forking one of their enrolled published org courses into a private copy. This is the student's personal learning space: their connected AI can freely add and edit its content with no review step, unlike a shared org course. If a self-course with a closely matching title already exists, this returns that existing course (matched_existing: true) instead of creating a duplicate — call list_my_courses or get_learning_context first if unsure whether the student already has this course, and check matched_existing on the result either way before assuming a new course was created.",
		Scope:       ScopeCoursesWrite,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"title":               map[string]any{"type": "string"},
				"description":         map[string]any{"type": "string"},
				"difficulty":          map[string]any{"type": "string", "description": "One of: beginner, intermediate, advanced. Defaults to beginner."},
				"tags":                map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
				"fork_from_course_id": map[string]any{"type": "string", "description": "If set, forks this published org course into the student's private copy instead of starting blank."},
			},
			"required": []string{"title"},
		},
		TargetType: "course",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			title, err := argString(args, "title")
			if err != nil {
				return nil, err
			}
			if forkFrom, ok := args["fork_from_course_id"].(string); ok && forkFrom != "" {
				return rt.coursesSvc.ForkSelfCourseFromOrgCourse(ctx, id.OrgID, id.UserID, forkFrom, title)
			}
			// Guard against a connected AI re-requesting a course the student
			// already has (misread conversation, retried call, etc.) — check
			// DB first per CLAUDE.md rule #4 rather than trusting the caller
			// to have checked list_my_courses itself.
			if existing, found, err := rt.coursesRepo.FindSimilarSelfCourse(ctx, id.OrgID, id.UserID, title); err != nil {
				return nil, err
			} else if found {
				return courses.SelfCourseCreationResult{Course: existing, MatchedExisting: true}, nil
			}
			var tags []string
			if raw, ok := args["tags"].([]any); ok {
				for _, v := range raw {
					if s, ok := v.(string); ok && s != "" {
						tags = append(tags, s)
					}
				}
			}
			created, err := rt.coursesSvc.CreateSelfCourse(ctx, id.OrgID, id.UserID, title, optString(args, "description"), optStringOr(args, "difficulty", ""), tags)
			if err != nil {
				return nil, err
			}
			return courses.SelfCourseCreationResult{Course: created, MatchedExisting: false}, nil
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			return rt.coursesRepo.DeleteOwnedSelfCourse(ctx, id.OrgID, id.UserID, entry.TargetID)
		},
	},
	{
		Name:        "add_self_course_module",
		Description: "Add a new lesson (as markdown notes) to one of the student's own self-courses — use this to record something new the student just learned, so their private course grows as they study. section_id is optional; omitted, it goes into the course's first section. If a closely-titled module already exists in this course, the content is appended to it instead of creating a duplicate lesson (matched_existing: true). If a similar module exists in a DIFFERENT self-course, it's returned as similar_elsewhere instead of being touched — mention it to the student rather than writing the same notes again.",
		Scope:       ScopeCoursesWrite,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"course_id":    map[string]any{"type": "string"},
				"section_id":   map[string]any{"type": "string", "description": "Optional — defaults to the course's first section."},
				"title":        map[string]any{"type": "string"},
				"content_body": map[string]any{"type": "string", "description": "Markdown lesson content."},
			},
			"required": []string{"course_id", "title", "content_body"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			courseID, err := argString(args, "course_id")
			if err != nil {
				return nil, err
			}
			title, err := argString(args, "title")
			if err != nil {
				return nil, err
			}
			contentBody, err := argString(args, "content_body")
			if err != nil {
				return nil, err
			}
			// Ownership check up front (AddSelfCourseModule/UpdateSelfCourseModule
			// each repeat it too, but the dedup lookups below must never run
			// against a course_id the caller doesn't actually own).
			if _, err := rt.coursesRepo.GetOwnedSelfCourse(ctx, id.OrgID, id.UserID, courseID); err != nil {
				return nil, err
			}

			if existing, found, err := rt.coursesRepo.FindSimilarModuleInCourse(ctx, id.OrgID, courseID, title); err != nil {
				return nil, err
			} else if found {
				mergedBody := contentBody
				if existing.ContentBody != nil && *existing.ContentBody != "" {
					mergedBody = *existing.ContentBody + "\n\n---\n\n" + contentBody
				}
				merged, err := rt.coursesSvc.UpdateSelfCourseModule(ctx, id.OrgID, id.UserID, existing.ID, existing.Title, mergedBody)
				if err != nil {
					return nil, err
				}
				return courses.SelfCourseModuleResult{CourseModule: merged, MatchedExisting: true}, nil
			}

			var similarElsewhere *courses.SimilarModuleElsewhere
			if hit, found, err := rt.coursesRepo.FindSimilarModuleElsewhere(ctx, id.OrgID, id.UserID, courseID, title); err == nil && found {
				similarElsewhere = &hit
			}

			created, err := rt.coursesSvc.AddSelfCourseModule(ctx, id.OrgID, id.UserID, courseID, optStringOr(args, "section_id", ""), title, contentBody)
			if err != nil {
				return nil, err
			}
			return courses.SelfCourseModuleResult{CourseModule: created, MatchedExisting: false, SimilarElsewhere: similarElsewhere}, nil
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			return rt.coursesRepo.SoftDeleteModule(ctx, id.OrgID, entry.TargetID)
		},
	},
	{
		Name:        "update_self_course_module",
		Description: "Replace the title/content of a lesson the student already has in one of their own self-courses.",
		Scope:       ScopeCoursesWrite,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id":    map[string]any{"type": "string"},
				"title":        map[string]any{"type": "string"},
				"content_body": map[string]any{"type": "string", "description": "Markdown lesson content, replacing what was there before."},
			},
			"required": []string{"module_id", "title", "content_body"},
		},
		TargetType: "course_module",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.GetModuleContent(ctx, id.OrgID, id.UserID, moduleID)
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			title, err := argString(args, "title")
			if err != nil {
				return nil, err
			}
			contentBody, err := argString(args, "content_body")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.UpdateSelfCourseModule(ctx, id.OrgID, id.UserID, moduleID, title, contentBody)
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			var before courses.ModuleContent
			if err := decodeBeforeState(entry, &before); err != nil {
				return err
			}
			if before.Module.ContentBody == nil {
				return fmt.Errorf("mcpconnect: revert update_self_course_module: prior module had no content_body")
			}
			_, err := rt.coursesSvc.UpdateSelfCourseModule(ctx, id.OrgID, id.UserID, entry.TargetID, before.Module.Title, *before.Module.ContentBody)
			return err
		},
	},
	{
		Name:        "propose_module_to_org_course",
		Description: "Propose a contribution to a shared org course — e.g. \"this vocab list would help the whole class.\" This never edits the shared course directly: it queues a pending proposal that course's instructor/admin must approve before it becomes a real lesson. Prefer source_module_id when the content already exists as a lesson in one of the student's own self-courses (it copies that lesson's current title/content server-side, and lets the reviewer see exactly which lesson it came from) — only pass title/content_body directly for content composed fresh in this conversation with no backing self-course lesson.",
		Scope:       ScopeCoursesWrite,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"target_course_id":  map[string]any{"type": "string", "description": "The shared org course to propose this lesson to."},
				"target_section_id": map[string]any{"type": "string", "description": "Optional — which section of the target course to propose it under."},
				"source_module_id":  map[string]any{"type": "string", "description": "Optional — a module id from one of the student's own self-courses to propose as-is. If given, title/content_body are ignored."},
				"title":             map[string]any{"type": "string", "description": "Required only when source_module_id is not given."},
				"content_body":      map[string]any{"type": "string", "description": "Markdown lesson content. Required only when source_module_id is not given."},
			},
			"required": []string{"target_course_id"},
		},
		TargetType: "course_content_proposal",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			targetCourseID, err := argString(args, "target_course_id")
			if err != nil {
				return nil, err
			}
			return rt.coursesSvc.ProposeModuleToOrgCourse(ctx, id.OrgID, id.UserID, targetCourseID,
				optString(args, "target_section_id"), optString(args, "source_module_id"),
				optStringOr(args, "title", ""), optStringOr(args, "content_body", ""))
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			_, err := rt.coursesRepo.RejectProposal(ctx, id.OrgID, entry.TargetID, id.UserID, nil)
			if errors.Is(err, courses.ErrConflict) {
				return fmt.Errorf("mcpconnect: this proposal has already been approved or rejected and can't be auto-reverted")
			}
			return err
		},
	},
	{
		Name:        "log_mistake",
		Description: "Record a distinct mistake the student made (grammar, concept, spelling, etc.) as a structured, timestamped event. Call this once per distinct error after correcting any piece of student writing or work — never explain a mistake in chat and let it disappear, and never create a course module just to store one; this is the only place mistakes are recorded. Before re-explaining a rule, check get_mistake_history first — if the student has seen it 3+ times with no improvement, change the example or analogy instead of repeating the same explanation.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"category":         map[string]any{"type": "string", "description": "One of: tense, article, preposition, subject_verb_agreement, spelling, sentence_fragment, run_on, vocabulary, punctuation, other."},
				"sub_topic":        map[string]any{"type": "string", "description": "The specific rule, e.g. \"present perfect vs simple past\"."},
				"original_text":    map[string]any{"type": "string", "description": "What the student wrote or said."},
				"corrected_text":   map[string]any{"type": "string", "description": "The corrected version."},
				"context_tag":      map[string]any{"type": "string", "description": "Free label grouping the activity, e.g. image-description, presentation-practice, journal-writing, interview-prep."},
				"source_module_id": map[string]any{"type": "string", "description": "Optional — set only if this happened while working through a specific lesson."},
			},
			"required": []string{"category", "sub_topic", "original_text", "corrected_text"},
		},
		TargetType: "mistake_entry",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			category, err := argString(args, "category")
			if err != nil {
				return nil, err
			}
			if !mistakes.ValidCategories[category] {
				return nil, fmt.Errorf("mcpconnect: invalid category %q", category)
			}
			subTopic, err := argString(args, "sub_topic")
			if err != nil {
				return nil, err
			}
			originalText, err := argString(args, "original_text")
			if err != nil {
				return nil, err
			}
			correctedText, err := argString(args, "corrected_text")
			if err != nil {
				return nil, err
			}
			return rt.mistakesSvc.LogMistake(ctx, id.UserID, mistakes.LogRequest{
				Category:       category,
				SubTopic:       subTopic,
				OriginalText:   originalText,
				CorrectedText:  correctedText,
				ContextTag:     optString(args, "context_tag"),
				SourceModuleID: optString(args, "source_module_id"),
			})
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			return rt.mistakesRepo.Delete(ctx, id.UserID, entry.TargetID)
		},
	},
	{
		Name:        "get_mistake_history",
		Description: "List the student's past mistakes in chronological order (newest first), optionally filtered by category and/or context_tag — use this to see the pattern behind a mistake before re-explaining a rule.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"category":    map[string]any{"type": "string", "description": "Optional — one of: tense, article, preposition, subject_verb_agreement, spelling, sentence_fragment, run_on, vocabulary, punctuation, other."},
				"context_tag": map[string]any{"type": "string", "description": "Optional — filter to one activity, e.g. journal-writing."},
			},
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			return rt.mistakesRepo.List(ctx, id.UserID, mistakes.ListFilter{
				Category:   optString(args, "category"),
				ContextTag: optString(args, "context_tag"),
			})
		},
	},
	{
		Name:        "get_progress_summary",
		Description: "Get the student's mistake counts and trend (worsening/stable/improving) per category — call this to answer \"what am I actually struggling with\" or to pick which weak area to focus a session on.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.mistakesRepo.Summary(ctx, id.UserID)
		},
	},
	{
		Name:        "get_due_revisions",
		Description: "Get the student's mistakes that are due for spaced revision right now. Call this FIRST, before starting any new practice or writing session, and surface anything due before jumping into new content.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.srsRepo.GetDueCardsBySource(ctx, id.UserID, "mistake")
		},
	},
	{
		Name:        "mark_revision_result",
		Description: "Record whether the student got a due revision right or wrong just now, and reschedule it — the interval grows on a correct answer and shortens/resets on a wrong one. card_id comes from get_due_revisions.",
		Scope:       ScopeSignals,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"card_id":               map[string]any{"type": "string", "description": "The srs card id from get_due_revisions."},
				"was_correct_this_time": map[string]any{"type": "boolean"},
			},
			"required": []string{"card_id", "was_correct_this_time"},
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			cardID, err := argString(args, "card_id")
			if err != nil {
				return nil, err
			}
			wasCorrect, _ := args["was_correct_this_time"].(bool)
			return srs.ReviewCard(ctx, rt.srsRepo, id.UserID, cardID, qualityFromBool(wasCorrect))
		},
	},
	{
		Name:        "list_interview_prep_plans",
		Description: "List the student's interview-prep plans — quick practice drills and job-targeted mock tests — newest first.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{"type": "object", "properties": map[string]any{}},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, _ map[string]any) (any, error) {
			return rt.interviewPrepSvc.ListPlans(ctx, id.UserID)
		},
	},
	{
		Name:        "get_interview_prep_plan",
		Description: "Get one interview-prep plan by id, including its rounds (conceptual/behavioral/coding) and their status/score — use this to check whether a round is ready to take or what's left before a report can be generated. This does NOT include the actual question text for a conceptual/behavioral round — call get_interview_prep_round with that round's practice_session_id for the questions themselves.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"plan_id": map[string]any{"type": "string"}},
			"required":   []string{"plan_id"},
		},
		TargetType: "interview_prep_plan",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			planID, err := argString(args, "plan_id")
			if err != nil {
				return nil, err
			}
			return rt.interviewPrepSvc.GetPlan(ctx, planID, id.UserID)
		},
	},
	{
		Name:        "create_interview_prep_plan",
		Description: "Start a new interview-prep plan for the student — either a 'quick' practice drill on one technology, or a 'targeted' mock test derived from a job title/description (conceptual + coding rounds, scored readiness report once both are completed). Capped at 5 new plans per day, same as the in-app form.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"mode":           map[string]any{"type": "string", "description": "One of: quick, targeted."},
				"technology":     map[string]any{"type": "string", "description": "Quick mode only, required — the technology/topic to practice, e.g. \"Go concurrency\"."},
				"difficulty":     map[string]any{"type": "string", "description": "Quick mode only — one of: beginner, intermediate, advanced. Defaults to intermediate."},
				"category":       map[string]any{"type": "string", "description": "Quick mode only — one of: technical, behavioral. Defaults to technical."},
				"question_count": map[string]any{"type": "integer", "description": "Quick mode only — number of questions, 1-20. Defaults to 5."},
				"job_title":      map[string]any{"type": "string", "description": "Targeted mode only, required — the role to prep for, e.g. \"Senior Backend Engineer\"."},
				"jd_text":        map[string]any{"type": "string", "description": "Targeted mode only, optional — the full job description text, used to extract role/seniority/skills and tailor the rounds. Up to 10,000 characters."},
			},
			"required": []string{"mode"},
		},
		TargetType: "interview_prep_plan",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			mode, err := argString(args, "mode")
			if err != nil {
				return nil, err
			}
			var orgID *string
			if id.OrgID != "" {
				orgID = &id.OrgID
			}
			return rt.interviewPrepSvc.CreatePlan(ctx, id.UserID, orgID, interviewprep.CreatePlanInput{
				Mode:          mode,
				JobTitle:      optStringOr(args, "job_title", ""),
				JDText:        optStringOr(args, "jd_text", ""),
				Technology:    optStringOr(args, "technology", ""),
				Difficulty:    optStringOr(args, "difficulty", ""),
				Category:      optStringOr(args, "category", ""),
				QuestionCount: optInt(args, "question_count", 0),
			})
		},
		// ponytail: no Revert — creation is capped at interviewprep.MaxPlansPerDay
		// per day via CountRecentPlans; deleting the row on revert would let a
		// connected client bypass that cap by looping create+revert, and the AI
		// cost of generating the plan has already been spent either way.
	},
	{
		Name:        "get_interview_prep_round",
		Description: "Get the actual questions, any answers already given, and AI feedback for an interview-prep plan's conceptual or behavioral round (round_type is 'conceptual' or 'behavioral' on get_interview_prep_plan/list_interview_prep_plans — every plan has exactly one such round; a targeted technical plan also has a separate coding round, which uses submit_interview_prep_coding_item instead). Pass the round's practice_session_id, not the round_id or plan_id.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"session_id": map[string]any{"type": "string", "description": "The round's practice_session_id, from get_interview_prep_plan."}},
			"required":   []string{"session_id"},
		},
		TargetType: "interview_prep_round",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			sessionID, err := argString(args, "session_id")
			if err != nil {
				return nil, err
			}
			return rt.interviewPrepSvc.GetRoundSession(ctx, sessionID, id.UserID)
		},
	},
	{
		Name:        "submit_interview_prep_round_answer",
		Description: "Submit the student's answer to one question of an interview-prep plan's conceptual or behavioral round (from get_interview_prep_round). Grades it with AI feedback (score, strengths, gaps, a suggested answer) the same as the in-app round UI — call get_interview_prep_round again afterward to see it.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"session_id":  map[string]any{"type": "string", "description": "The round's practice_session_id, from get_interview_prep_plan."},
				"position":    map[string]any{"type": "integer", "description": "The question's position within the round, from get_interview_prep_round."},
				"answer_text": map[string]any{"type": "string"},
			},
			"required": []string{"session_id", "position", "answer_text"},
		},
		TargetType: "interview_prep_round",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			sessionID, err := argString(args, "session_id")
			if err != nil {
				return nil, err
			}
			answerText, err := argString(args, "answer_text")
			if err != nil {
				return nil, err
			}
			position := optInt(args, "position", -1)
			if position < 0 {
				return nil, fmt.Errorf("missing required argument %q", "position")
			}
			return rt.interviewPrepSvc.SubmitRoundAnswer(ctx, sessionID, id.UserID, position, answerText)
		},
		// ponytail: no Revert — like submit_interview_prep_coding_item, the AI
		// grading has already run by the time this returns; there's no
		// meaningful undo for an answer that's already been scored.
	},
	{
		Name:        "submit_interview_prep_coding_item",
		Description: "Submit the student's code for one item of an interview-prep plan's coding round — runs it against the item's test cases and grades it, the same as the in-app code editor's submit button.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"plan_id":  map[string]any{"type": "string"},
				"round_id": map[string]any{"type": "string"},
				"item_id":  map[string]any{"type": "string"},
				"code":     map[string]any{"type": "string"},
				"language": map[string]any{"type": "string"},
			},
			"required": []string{"plan_id", "round_id", "item_id", "code", "language"},
		},
		TargetType: "interview_prep_coding_item",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			planID, err := argString(args, "plan_id")
			if err != nil {
				return nil, err
			}
			roundID, err := argString(args, "round_id")
			if err != nil {
				return nil, err
			}
			itemID, err := argString(args, "item_id")
			if err != nil {
				return nil, err
			}
			code, err := argString(args, "code")
			if err != nil {
				return nil, err
			}
			language, err := argString(args, "language")
			if err != nil {
				return nil, err
			}
			return rt.interviewPrepSvc.SubmitCodingItem(ctx, planID, roundID, itemID, id.UserID, code, language)
		},
		// ponytail: no Revert — the code has already run against the test cases
		// by the time this returns; there's no meaningful undo for an executed
		// submission, only for the stored answer text, which isn't worth
		// reverting on its own.
	},
	{
		Name:        "get_interview_prep_report",
		Description: "Get the aggregate readiness report for a job-targeted interview-prep plan — readiness score, conceptual/coding scores, strong and weak skills, a summary, and next steps. Only available once both rounds are completed; quick plans never generate a report.",
		Scope:       ScopeInterviewPrep,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"plan_id": map[string]any{"type": "string"}},
			"required":   []string{"plan_id"},
		},
		TargetType: "interview_prep_plan",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			planID, err := argString(args, "plan_id")
			if err != nil {
				return nil, err
			}
			return rt.interviewPrepSvc.GetReport(ctx, planID, id.UserID)
		},
	},
	{
		Name:        "list_system_design_attempts",
		Description: "List the student's whiteboard attempts at a system-design question (a course module of type system_design), newest first — use this to see whether they've already started before creating a new attempt.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"module_id": map[string]any{"type": "string"}},
			"required":   []string{"module_id"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.ListAttempts(ctx, id.OrgID, id.UserID, moduleID)
		},
	},
	{
		Name:        "create_system_design_attempt",
		Description: "Start a fresh, blank-canvas attempt at a system-design question. Earlier attempts (and their feedback) are kept, not overwritten — call list_system_design_attempts first if the student may already have one in progress.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"module_id": map[string]any{"type": "string"}},
			"required":   []string{"module_id"},
		},
		TargetType: "system_design_attempt",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.CreateAttempt(ctx, id.OrgID, id.UserID, moduleID)
		},
		// ponytail: no Revert — systemdesign.Repo has no attempt-delete method
		// (the in-app UI never deletes an attempt either, only supersedes it
		// with a new one), so there's nothing to undo it into.
	},
	{
		Name:        "get_system_design_attempt",
		Description: "Read one system-design attempt — its current Excalidraw scene (elements/appState) and any AI feedback already generated for it.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id":  map[string]any{"type": "string"},
				"attempt_id": map[string]any{"type": "string"},
			},
			"required": []string{"module_id", "attempt_id"},
		},
		TargetType: "system_design_attempt",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			attemptID, err := argString(args, "attempt_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.GetAttempt(ctx, id.OrgID, id.UserID, moduleID, attemptID)
		},
	},
	{
		Name:        "save_system_design_scene",
		Description: "Replace an attempt's whole Excalidraw canvas with a new scene — use this to draw or edit the diagram on the student's behalf (e.g. add a component, connect two boxes, label an edge). scene must be the full canvas content, not a partial patch: {\"elements\": [...], \"appState\": {...}}. Call get_system_design_attempt first to see the current scene's exact element shape before editing it, so existing elements aren't dropped.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id":  map[string]any{"type": "string"},
				"attempt_id": map[string]any{"type": "string"},
				"scene": map[string]any{
					"type":        "object",
					"description": "Full Excalidraw scene, replacing what's currently on the canvas. Each element needs at least id/type/x/y/width/height (plus type-specific fields like text for a text element, or startBinding/endBinding for an arrow).",
					"properties": map[string]any{
						"elements": map[string]any{"type": "array", "items": map[string]any{"type": "object"}},
						"appState": map[string]any{"type": "object"},
					},
					"required": []string{"elements"},
				},
			},
			"required": []string{"module_id", "attempt_id", "scene"},
		},
		TargetType: "system_design_attempt",
		BeforeState: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			attemptID, err := argString(args, "attempt_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.GetAttempt(ctx, id.OrgID, id.UserID, moduleID, attemptID)
		},
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			attemptID, err := argString(args, "attempt_id")
			if err != nil {
				return nil, err
			}
			scene, err := argScene(args, "scene")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.SaveScene(ctx, id.UserID, moduleID, attemptID, scene)
		},
		Revert: func(ctx context.Context, rt *Router, id mcpIdentity, entry ActionLogEntry) error {
			var before systemdesign.Attempt
			if err := decodeBeforeState(entry, &before); err != nil {
				return err
			}
			moduleID, ok := entryArgString(entry, "module_id")
			if !ok {
				return fmt.Errorf("mcpconnect: revert save_system_design_scene: missing module_id in logged args")
			}
			_, err := rt.systemDesignSvc.SaveScene(ctx, id.UserID, moduleID, entry.TargetID, before.Scene)
			return err
		},
	},
	{
		Name:        "generate_system_design_feedback",
		Description: "Ask MindForge's AI to critique this attempt's current whiteboard against the question's guidance — reads back any text/labels already on the canvas and returns feedback, which is also saved on the attempt.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id":  map[string]any{"type": "string"},
				"attempt_id": map[string]any{"type": "string"},
			},
			"required": []string{"module_id", "attempt_id"},
		},
		TargetType: "system_design_attempt",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			attemptID, err := argString(args, "attempt_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.GenerateFeedback(ctx, id.OrgID, id.UserID, moduleID, attemptID)
		},
		// ponytail: no Revert — the AI feedback has already been generated (and
		// billed) by the time this returns, same as submit_interview_prep_coding_item;
		// there's no meaningful undo for feedback that was already produced.
	},
	{
		Name:        "list_system_design_chat",
		Description: "List the clarifying-question thread for a system-design question, oldest first.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type":       "object",
			"properties": map[string]any{"module_id": map[string]any{"type": "string"}},
			"required":   []string{"module_id"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.ListChat(ctx, id.OrgID, id.UserID, moduleID)
		},
	},
	{
		Name:        "send_system_design_chat_message",
		Description: "Ask a clarifying question about a system-design question on the student's behalf — answered with the question's guidance as grounding context plus recent thread history, the same as the in-app chat panel. Returns both the sent message and the AI's reply.",
		Scope:       ScopeSystemDesign,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"module_id": map[string]any{"type": "string"},
				"content":   map[string]any{"type": "string"},
			},
			"required": []string{"module_id", "content"},
		},
		TargetType: "course_module",
		Call: func(ctx context.Context, rt *Router, id mcpIdentity, args map[string]any) (any, error) {
			moduleID, err := argString(args, "module_id")
			if err != nil {
				return nil, err
			}
			content, err := argString(args, "content")
			if err != nil {
				return nil, err
			}
			return rt.systemDesignSvc.SendChatMessage(ctx, id.OrgID, id.UserID, moduleID, content)
		},
		// ponytail: no Revert — like send-message tools elsewhere in this file,
		// the AI reply has already been generated by the time this returns.
	},
}

// qualityFromBool maps the boolean grading a caller of mark_revision_result
// has (right/wrong) onto an SM-2 quality grade: 2 ("Good") on a correct
// answer, 0 ("Again") on a wrong one.
// ponytail: a caller with finer-grained recall (hesitated but got it right,
// etc.) should call POST /api/srs/review directly with a 0-3 quality instead.
func qualityFromBool(wasCorrect bool) int {
	if wasCorrect {
		return 2
	}
	return 0
}

// optStringOr returns args[key] as a string, or def if absent/empty — for
// optional non-pointer string fields where the callee expects a plain ""
// sentinel rather than a *string (e.g. Service.AddSelfCourseModule's
// sectionID, Service.CreateSelfCourse's difficulty).
func optStringOr(args map[string]any, key, def string) string {
	if v, ok := args[key].(string); ok && v != "" {
		return v
	}
	return def
}

// optInt returns args[key] as an int, or def if absent — JSON-RPC numeric
// arguments decode as float64, so this is the numeric counterpart to
// optStringOr (e.g. create_interview_prep_plan's question_count).
func optInt(args map[string]any, key string, def int) int {
	if v, ok := args[key].(float64); ok {
		return int(v)
	}
	return def
}

func findTool(name string) (mcpTool, bool) {
	for _, t := range tools {
		if t.Name == name {
			return t, true
		}
	}
	return mcpTool{}, false
}

// callTool enforces the connection's granted scope before invoking a tool —
// the single choke point every /mcp tools/call request passes through. This
// is also where every call gets logged to mcp_action_log (before-state
// captured first, so a later revert can restore it) — one instrumentation
// point covers every tool instead of repeating it in each Call closure.
func (rt *Router) callTool(ctx context.Context, id mcpIdentity, name string, args map[string]any) (json.RawMessage, error) {
	tool, ok := findTool(name)
	if !ok {
		return nil, fmt.Errorf("unknown tool %q", name)
	}
	if !id.hasScope(tool.Scope) {
		return nil, errMissingScope
	}

	var before any
	if tool.BeforeState != nil {
		var err error
		before, err = tool.BeforeState(ctx, rt, id, args)
		if err != nil {
			return nil, err
		}
	}

	result, err := tool.Call(ctx, rt, id, args)
	if err != nil {
		return nil, err
	}

	rt.logAction(ctx, id, tool, args, before, result)
	return json.Marshal(result)
}

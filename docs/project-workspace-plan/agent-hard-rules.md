# Hard rules for every Project Workspace agent (verbatim from the lead's brief)

- The local DATABASE_URL points at the PRODUCTION database, and migrations run automatically at startup. NEVER start the backend against it and NEVER apply migrations 036–040 to it. Test only with internal/testdb. If a live DB is needed, stop and report back instead.
- Every migration: its own .down.sql; `SET LOCAL lock_timeout = '5s'` on any file altering an existing table; no CREATE INDEX CONCURRENTLY.
- Locks cover both the check and the write, in one transaction. The project role is read live on every request, never cached (non-member → 404, below required role → 403). sod.Check is the only place for separation-of-duties; no role bypasses it.
- AI: check the cache before calling, wrap every user input in delimiters, JSON mode, suggest-only (except assignee suggestion, which is not cached — see D20).
- Production-ready only: fmt.Errorf("…: %w") wrapping, validate input at the boundary, transactions for multi-table writes, cursor-paginated lists, rate limits on every costly or public endpoint. No TODO/FIXME/HACK, no stubs, no hardcoded values (limits come from cfg.Workspace / constants in models.go).
- Don't change project_tasks (except the 00-decisions D16 orgs.Join fix). The projectmarket marketplace was deleted in the Projects → Workspaces merge; its service_score.go delimiting fix is moot.
- If the plan is wrong against the real code, fix it the way 00-decisions would and record the deviation in your final report. If the intent is unclear, stop and report back.
- Edit ONLY the files your brief says you own. Other agents are editing other files in the same working tree right now. Never run `git checkout`, `git stash`, `git reset`, or any git command that changes files. Never commit.
- Follow CLAUDE.md, frontend/CLAUDE.md, docs/ai-pattern-learnings.md, docs/frontend-gotchas.md.

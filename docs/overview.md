# MindForge — Overview

## Product Vision

Multi-tenant learning platform where organizations (colleges, bootcamps, companies) and individual instructors publish structured courses. Students learn through lessons, coding challenges, quizzes, mentor guidance, and end with an AI-generated revision plan and final certification test.

Inspired by: LeetCode (coding problems + in-browser compiler) · KodeKloud (hands-on labs) · Udemy (course marketplace) · Notion (fork & modify).

Stack: Go 1.26.4 + Chi v5 + pgx/v5 · Next.js 16.2.9 + React 19 + Tailwind v4 + shadcn/ui · PostgreSQL · Docker Compose.

---

## User Roles

| Role | Scope |
|---|---|
| `super_admin` | Manages the entire platform |
| `org_admin` | Manages their organization, approves course publishing |
| `instructor` | Creates and publishes courses within their org or as individual |
| `mentor` | Guides assigned students, reviews code, answers questions |
| `student` | Enrolls, learns, submits code, takes quizzes |
| `guest` | Views free preview modules only — no account needed |
| `anonymous` | Takes public tests via shareable link — no account required |

---

## Multi-Tenancy Model

```
Platform (MindForge)
  └─ Organizations (colleges, bootcamps, companies)
  │    └─ org_admin manages members
  │    └─ instructors create courses under the org
  │    └─ students enroll via org invite or org-specific link
  │    └─ mentors assigned per course or per student
  │
  └─ Individual users (no org)
       └─ instructors publish courses independently
       └─ students browse and enroll (paid or free)
```

Org roles (`org_members.role`): `admin` · `instructor` · `mentor` · `student`
Platform role (`users.platform_role`): `super_admin` · `user`

---

## API Response Format

```json
// success
{ "data": { ... } }

// paginated
{ "data": [...], "pagination": { "page": 1, "per_page": 20, "total": 100 } }

// error
{ "error": "human readable message" }
```

---

## Build Phases

| # | Phase | Covers |
|---|---|---|
| 1 | Foundation | Docker, go.mod, config, DB pool, full SQL migration |
| 2 | Auth + Roles | register, email verification, login, refresh tokens, jti blocklist, session_version, logout, password reset, social OAuth, magic-link, per-org auth config, org invites, switch-org, impossible-travel detection, role + tenant middleware |
| 3 | LLM Abstraction | Provider interface, OpenAI-compat, Anthropic |
| 4 | Orgs + Members | org CRUD, invite, role assignment |
| 5 | Courses + Sections + Modules | CRUD, fork, publish workflow |
| 6 | Enrollment + Progress | enroll (free/paid), module progress tracking |
| 7 | Coding Problems + Executor | Monaco editor, WASM runner, Docker sandbox |
| 8 | Quiz + Cards (SM-2) | quiz CRUD, attempt scoring, spaced repetition |
| 9 | Mentors + Messages | assignment, chat thread |
| 10 | Revision Plan + Final Test + Certificates | AI revision, final test, cert issuance |
| 11 | Payments | Stripe/Razorpay integration |
| 12 | Frontend — Auth + Dashboard + Browse | Next.js 16 setup, auth pages, course browse |
| 13 | Frontend — Learning flow | lesson, coding editor, quiz, progress |
| 14 | Frontend — Review + Mentor + Cert | spaced repetition UI, mentor chat, cert page |
| 15 | Frontend — Instructor tools | course builder, module editor, analytics |
| 16 | Sheet Tracker + Overlap | sheets CRUD, per-item progress, multi-sheet overlap view |
| 17 | Wiki / Docs | wiki_spaces, nested page tree, TipTap editor, autosave, version history, comments, templates, full-text search |
| 18 | System Design Canvas | React Flow canvas, component palette, custom nodes, undo/redo, version history, PNG export, wiki embed |
| 19 | Interview Board + Load Test | live coding + system design (Yjs WebSocket), question bank, scorecards; real HTTP load test runner (Go goroutines, p50/p95/p99) |

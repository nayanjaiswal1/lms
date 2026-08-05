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
| 2 | Auth + Roles | register, email verification, login, refresh tokens, jti blocklist, session_version, logout, password reset, social OAuth, per-org auth config, org invites, switch-org, role + tenant middleware |
| 3 | LLM Abstraction | Provider interface, OpenAI-compat, Anthropic; async job queue (Go worker pool + Redis) for AI calls; per-IP Redis sliding-window rate limiting on all AI endpoints |
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
| 20 | AI Personalized Roadmaps | User states a goal → AI generates a roadmap (phases → milestones → modules); GENERATED vs DEFINED mode; status tracking (active, completed, archived); progress on AI-generated paths; roadmap regeneration / refinement |
| 21 | Semantic Search + RAG | pgvector embeddings on courses, wiki pages, modules; "find content by meaning" across all of MindForge; RAG context injection for AI tutor (Phase 10) and revision plan (Phase 10); embedding refresh on content update |

---

## Features Backlog (Sourced from Competitive Research)

### High Value — Not yet in MindForge

| Feature | What it does | MindForge fit |
|---|---|---|
| AI-generated learning roadmaps | User describes a goal → GPT-4o generates a Phase → Milestone → Module learning path | Strong. MindForge has courses but no personalized AI-generated paths → planned as Phase 20 |
| pgvector + RAG | Embeds course/wiki content into vectors for semantic search | Would supercharge course/wiki search — find "explain closures" across all content → planned as Phase 21 |
| Async job queue | Background queue for AI calls, email, code execution | MindForge AI calls are sync — prevents request timeouts on heavy AI work → added to Phase 3 |
| Per-IP rate limiting on AI endpoints | In-memory (dev) → Redis sliding window (prod) per IP | MindForge has no rate limiting on AI endpoints — needed before launch → added to Phase 3 |

### From Teachyst (white-label course-selling LMS) — not yet scheduled

| Feature | What it does | MindForge fit |
|---|---|---|
| White-labeling + custom domains | Org hosts its course catalog under its own branded domain, no platform branding | Natural extension of the multi-org model — orgs already get their own tenant, but no white-label/custom-domain support exists yet |
| SAML / OpenID Connect SSO | Enterprise identity-provider login for org members | `auth.md` covers social OAuth + magic link only — SAML/OIDC is what a college or company's IT team actually asks for before rolling out org accounts |
| DRM / video content protection | Encrypted video delivery that resists downloading of paid course video | Courses already support video lessons, no DRM — matters once paid video courses are common |
| Purchase-power-parity pricing | Auto-adjusts a course's price by the buyer's country purchasing power | Payments (Phase 11) is Stripe/Razorpay checkout only, no regional pricing logic |
| Built-in course SEO | Meta tags, sitemap entries, structured data per public course page | Public course pages exist (`getPublicCourses`) but have no SEO tooling beyond page `<title>`/description |
| Zapier / webhook automation | Lets an org admin pipe platform events (new enrollment, certificate issued) into external tools | MindForge has no outbound webhook/automation layer — GitLab integration is the only external connector today |
| Community / discussion space | Cross-course discussion forum or persistent community chat, distinct from per-course mentor chat | Wiki, batch chat, and mentor messaging exist, but there's no open community/discussion feature |

### Useful Patterns / Practices

| Pattern | Status | Notes |
|---|---|---|
| Security headers middleware | ✅ Done | `next.config.ts` — CSP, HSTS, X-Frame-Options, Permissions-Policy already wired |
| Monaco Editor lazy loading | ✅ Done | `components/shared/code-editor.tsx` — `dynamic()` + Suspense skeleton, JetBrains Mono font |
| Piston code execution | ✅ Done | `internal/assessment/executor.go` — `pistonExecutor` implementing `CodeExecutor` interface; priority over Judge0 when `PISTON_URL` set |
| Type sync script | ✅ Done | `scripts/gen-types.sh` + `backend/tygo.yaml` — generates `frontend/types/generated/*.ts` from Go structs |

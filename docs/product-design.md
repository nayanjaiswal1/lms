# MindForge — Product Design Strategy

> Auth, Onboarding & User Journey  
> Status: Adopted — implementation targets Phase 2+ onboarding redesign

---

## 1. User Personas

### Individual Learner (self-directed, career-motivated)
- **Goals:** Acquire a skill for promotion / career switch / freelance; earn a credible certificate
- **Pain points:** Starts 5 courses, finishes none; generic recommendations; no clear next step
- **Expected outcome:** A personalized path from current level to their goal, with proof of progress

### Working Professional (upskiller, time-poor)
- **Goals:** Apply learning to current job within weeks; learn in 15–20 min sessions; skip content they already know
- **Pain points:** Forced through beginner content; can't pick up where they left off; learning doesn't connect to real work
- **Expected outcome:** Micro-learning that slots into the workday with immediate practical application

### Team Manager
- **Goals:** Upskill team without disrupting delivery; track completions; justify ROI to leadership
- **Pain points:** No visibility into absorption; can't customize to team's stack; manual reporting
- **Expected outcome:** Assign, track, and prove team skill growth

### Organization Admin (L&D / HR)
- **Goals:** Enforce compliance training on schedule; provision/deprovision users; integrate with HRIS
- **Pain points:** Spreadsheet-based completion tracking; chasing employees for overdue training; tool sprawl
- **Expected outcome:** One system of record, automated compliance enforcement, audit-ready reports

### Enterprise Employee (assigned learner)
- **Goals:** Complete required training as fast as possible; optionally discover something personally useful
- **Pain points:** Mandatory content feels irrelevant; no personal benefit; SSO friction
- **Expected outcome:** Frictionless completion of required work + pathways they might actually want

---

## 2. Authentication Strategy

### Core Principle
Authentication is the first moment of trust. Target: **user reaches value in < 90 seconds**.

### Individual Registration Flow

1. **Single CTA** — "Start Learning Free" (no pricing gate before registration)
2. **Social-first** — Google / GitHub OAuth, or email only (no password at this step)
3. **Magic link (default)** or "Set a password instead" — reduces failed logins ~60%
4. **First name only** on account activation — last name deferred to certificate generation

**Not collected at registration:** phone, date of birth, address, payment info, company name

### Organization Admin Registration

1. Standard email registration
2. Post-confirm: "Personal learning or for your organization?" → branches to org setup
3. Work email detected → soft nudge: "Looks like you're from Acme Corp. Bring your team?" (skippable)

### Invited User (Employee)

1. Branded invite email: "Acme Corp has invited you to MindForge"
2. Pre-filled email, one field (password or "Join with Google")
3. First session drops directly into assigned courses — no generic homepage, no generic onboarding

### SSO

- **Supported:** SAML 2.0 (Okta, Azure AD, ADFS, Ping Identity), OIDC (Google Workspace, Entra)
- **Provisioning:** SCIM for automated user sync / de-provision
- **Tenant discovery:** Enter email → domain match → auto-redirect to org's SSO provider (no "are you an org user?" question)
- **Domain verification:** DNS TXT record before SSO activates (prevents domain spoofing)

### Organization Joining (no invite, work email)

1. User enters `@acme.com` email → system detects registered tenant
2. Show: "Acme Corp uses MindForge. Request to join?" → one-click request → admin approves
3. Org can enable auto-join for verified domains

---

## 3. Onboarding Questions

### The Rule
**Ask a question only if you can act on the answer within the same session.**

### Individual Learner — 5 Questions (one per screen, < 2 minutes total)

| # | Question | Why It Matters | How the Answer Is Used | Unlocks |
|---|---|---|---|---|
| Q1 | "What do you want to achieve?" | North star for everything downstream | Determines path framing, goal language, milestone copy | Goal-aligned paths, motivation copy |
| Q2 | "What's your current role or background?" | Skill baseline; avoids insulting experts | Difficulty calibration, peer benchmarking | Skill gap assessment |
| Q3 | "What do you want to learn?" (multi-select) | Immediate homepage relevance | Seeds homepage and first recommendations | First-session content |
| Q4 | "How much time can you commit each week?" | Path pacing; realistic completion dates | Weekly goal, reminder schedule, estimated completion | Personalized schedule |
| Q5 | "What's your current level in [chosen topic]?" | Skip protection; entry-point calibration | Content level filter; skips modules user likely knows | Level-appropriate content |

**Q1 options:** Get a promotion · Switch careers · Build a side project · Stay current · Compliance requirement

**Q3:** 8–12 category tiles with icons, multi-select (software, data, design, product, marketing, etc.)

**Q4 options:** 1–2 hrs · 3–5 hrs · 5–10 hrs · 10+ hrs

**Q5 options (per chosen topic):** Beginner · Some experience · Intermediate · Advanced

### Questions NOT to Ask

| Question | Why it's wrong |
|---|---|
| Phone number | No value to user; feels like surveillance |
| Date of birth | Not needed unless age-restricted content |
| "How did you hear about us?" | Belongs in analytics, not the user's face |
| Profile photo | High friction; add from settings later |
| "What's your company size?" | Only relevant if org intent was signaled |
| "What's your budget?" | Offensive at registration stage |

### Organization Admin — 5 Fields (one page, 3 minutes)

1. Organization name
2. Industry (dropdown, ~20 options) → unlocks compliance path recommendations
3. Team size → determines pricing tier surface
4. Primary use case: Compliance / Skill development / Both
5. Domain to claim

### Enterprise Employee — 2 Questions (30 seconds)

1. Your role/team at [Org Name]
2. What you hope to learn (optional)

→ Show assigned training immediately after

---

## 4. Individual Learner Journey

### Registration → First Value: Target < 5 minutes

```
[1] CTA on landing page
[2] Google/GitHub OAuth or email
[3] 5 onboarding questions (one screen each, ~90 seconds)
[4] AI-generated learning path preview ("Your 6-week path to [Goal]")
[5] First module begins — no homepage detour
```

**Why skip the homepage on first session:** The homepage is a navigation tool for returning users. New users have no context to navigate. Drop them directly into lesson 1.

### The 20-Minute Rule
If the user hasn't completed something meaningful in their first 20 minutes, churn probability increases sharply. Design the first module to be completable in 15–20 minutes.

### First Session Elements
- Intro acknowledges their level ("Since you have some Python experience, we're skipping the basics")
- Estimated time shown upfront
- Progress bar visible from minute one
- Completion animation + one-sentence summary of concept learned at end of module

### Progress Tracking (Learner Dashboard)
- % complete on current path
- Skills acquired (tag-based, e.g., Python · Pandas · Data Visualization)
- Weekly learning streak
- Estimated time to next milestone
- Hours invested

**Do not surface:** Raw quiz scores on main dashboard (creates anxiety). Show in a detail view only.

### Engagement Loops

| Trigger | Message |
|---|---|
| Daily | "Pick up where you left off — 12 min to complete Module 3" |
| Weekly | Progress summary: streak, skills gained, path position |
| Milestone | Certificate preview before it's earned — pull users forward |
| 7 days inactive | "Still working toward [goal]? Your path is saved." (no guilt) |

### Upgrade Triggers (behavior-based, not time-based)

| Signal | Prompt |
|---|---|
| Completes first path | "Unlock advanced paths with Pro" |
| Hits a Pro course | Show what's locked + why it's worth it |
| Shares a certificate | "Get verified certificates with Pro" |
| 5+ sessions in week 1 | "You're on a roll — never lose your streak" |

**Never:** prompt upgrades on day 1 before value is delivered; paywall the onboarding; require credit card for free tier.

---

## 5. Organization / Tenant Journey

### Organization Creation

1. Admin signals org intent (post-reg question or dedicated CTA)
2. Org profile: name, industry, team size, use case
3. Domain claim + DNS verification
4. Invite first 5 members before leaving setup (momentum)

### Tenant Setup Checklist (drives activation)

1. Branding (logo, accent color) — visual ownership signals legitimacy to employees
2. Default catalog visibility (open browse vs. admin-assigned only)
3. Departments / teams structure
4. SSO configuration
5. First training assignment

### Invitation Flow

| Method | Use case |
|---|---|
| Individual email | Small teams, targeted invites |
| CSV upload | Batch provisioning: name, email, department, role |
| SSO + SCIM | Enterprise auto-provision / auto-deprovision |

Invite email sender shown as "Acme Corp via MindForge" — not "MindForge noreply".

### Compliance & Training Assignment

- Admin selects course → assigns to department / team / individual
- Due date → employee sees countdown
- Recurrence for annual re-certification
- Auto-reminders at 2 weeks, 1 week, 3 days, 1 day before deadline
- Overdue: escalation to manager (configurable); admin sees real-time report

### Reporting

**Manager view:** Team completion rate, individual progress, skills acquired, time invested  
**Admin/L&D view:** Org-wide compliance by deadline, enrollment vs. completion by dept, export to CSV

**Reporting rule:** Always show the denominator. "72 completed" is noise. "72 of 80 (90%)" is actionable.

---

## 6. Data Collection Framework

| Data | Mandatory | Why | Improves | Retention |
|---|---|---|---|---|
| Email | Yes | Identity + auth | Personalization, notifications | Indefinite |
| First name | Yes (post-signup) | Personalization, certificates | "Welcome back, Alex" | Indefinite |
| Learning goal (Q1) | Yes | North star | Path framing, milestone copy | Until updated |
| Job title / background (Q2) | Optional | Skill baseline | Difficulty calibration | Until updated |
| Topics of interest (Q3) | Yes | Immediate relevance | Homepage, first recs | Until updated |
| Weekly time commitment (Q4) | Optional | Pacing | Completion estimates, reminders | Until updated |
| Skill level (Q5) | Yes | Entry-point calibration | Content filtering | Inferred over time |
| Assessment results | Inferred | True skill signal | Overrides self-reported level | Indefinite |
| Session timestamps | Inferred | Learning pattern | Schedule-aware nudges | Rolling 90 days |
| Org / department | Mandatory (org users) | Access control, reporting | Routes assigned content | Until SCIM update |

---

## 7. Future-Ready Data Decisions

### Collect Today for Future Capabilities

| Future feature | What to capture now |
|---|---|
| AI-generated paths | Skill level per topic (skill graph nodes), not just overall level |
| Adaptive difficulty | Completion velocity + drop-off point per module |
| Skill assessments | Question-level result history with timestamps (not just pass/fail) |
| Certificates | Certificate metadata schema: issue date, expiry, credential ID, version |
| Compliance training | Immutable audit log of completion: user + course + version + timestamp |
| Company knowledge bases | Content source tagging (platform vs. org-uploaded) + permission scope |
| Career growth recs | Career trajectory field (optional: "where do you want to be in 2–3 years?") |
| Performance insights | Manager-learner relationship mapping in the data model |

### Critical Architecture Decision
Build the data model around a **Skill Graph**, not courses. Courses are delivery vehicles. Skills are the transferable unit of value. Every completion, quiz result, and assessment maps to skill nodes. This makes AI path generation, career recommendations, and performance insights possible without a migration later.

---

## 8. UX Principles (Non-Negotiable)

1. **Value before friction** — show the product working before asking for anything
2. **Progress visible from minute one** — progress bar exists from the first lesson; humans are loss-averse
3. **Respect stated goals** — if the user said "get a promotion," every touchpoint speaks that language
4. **Separate assigned from chosen** — in orgs, elective learning must always be accessible alongside mandatory training
5. **End every session with a clear next step** — never land the user on a generic homepage after completing a module
6. **Earn the upgrade conversation** — prompt only after a positive event (path completed, certificate earned, streak milestone)
7. **Build for the skeptical org employee** — surface something personally useful within the first two sessions; the platform must give before it takes

---

## 9. Minimum vs. Advanced Data

### Minimum to Start (5 data points)

| Data | Source | Timing |
|---|---|---|
| Email | User | Registration |
| First name | User | First session |
| Learning goal | User | Onboarding Q1 |
| Topics of interest | User | Onboarding Q3 |
| Skill level | User | Onboarding Q5 |

Five data points are enough to generate a meaningful, personalized first session.

### Advanced Data (Progressive Profiling)

| Data | Trigger for collection |
|---|---|
| Detailed skill assessment | After week 1 |
| Career trajectory (2-year goal) | After first path completion |
| Job title / industry | When user earns first certificate |
| Time-of-day pattern | Inferred from behavior after 2 weeks |
| Peer/manager endorsements | At 30-day mark (org users) |
| LinkedIn / GitHub integration | After completing a path relevant to their profile |

**Pattern:** each progressive data request is triggered by a milestone that makes it feel natural, not extractive.

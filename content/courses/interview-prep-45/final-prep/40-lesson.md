---
kind: lesson
id_key: interview-prep-45/day-40
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Company-Specific Preparation"
position: 40
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Generic prep gets you in the room. Company-specific prep gets you the offer over an equally-strong candidate who didn't bother. Today is about closing that gap for your actual target companies, plus two final system designs and locking behavioral delivery.

## Block 1 (90 min): Company-Specific Prep

Research **3 target companies** (the ones you actually have interviews with, not aspirational ones). Spend 30 minutes per company, structured — random browsing wastes the time.

### The 30-minute-per-company research pass

| Minutes | What to look up | Why it matters |
|---|---|---|
| 0-8 | Engineering blog (last 6-12 months of posts) | Reveals real architecture decisions, current problems, and vocabulary the interviewer uses daily |
| 8-14 | Tech stack (job postings, StackShare, engineering blog mentions) | Lets you tailor system design answers to tools they'd actually reach for |
| 14-20 | Recent news (funding, launches, incidents, layoffs, leadership changes) | "Do you have any questions for us" becomes specific, not generic |
| 20-26 | Product itself — actually use it if it's a consumer product, or read the docs if it's dev tooling | You should be able to name one thing you'd improve and why |
| 26-30 | Glassdoor/Blind interview reports for this specific role (skeptically — patterns, not gospel) | Calibrates format and difficulty expectations |

### Turn research into interview material

For each company, write down:

- **One system design tailored to their domain.** If it's a fintech, lean into consistency/idempotency; if it's ad-tech, lean into high-throughput event pipelines; if it's a dev tool, lean into API design and multi-tenancy.
- **Two questions to ask the interviewer** that could only apply to this company (not "what's the culture like" — that's genuinely a wasted question at this stage). Example: "Your engineering blog mentioned moving from a monolith to services around [event] — what's the current pain point in that architecture?"
- **One honest answer to "why us"** that references something specific from your research, not the company's own marketing copy read back to them.

**Verify you're actually strong here:** for each of the 3 companies, say your "why us" answer out loud in under 45 seconds without checking notes. If it sounds like it could apply to any company by swapping the name, it's not specific enough — go back to the blog/product research and find the actual hook.

## Block 2 (75 min): System Design Final

Two designs today, but the focus is different from Day 38 — **clarity and continuous narration**, not new content:

- Design 2 systems, ideally one generic (from your practiced list) and, if you finished Block 1, one shaped toward a target company's domain.
- Constraint: **no silence longer than 5 seconds.** If you're thinking, say what you're thinking ("I'm weighing whether this needs a queue here or if synchronous is fine given the latency budget..."). Interviewers can't grade a silent thought process.
- Practice speaking continuously through the transition between steps too — "okay, requirements are solid, moving to capacity estimation now" — these verbal transitions are what make a design feel driven rather than interviewer-led.

## Block 3 (60 min): Behavioral Final

- Run through **all 10 stories** with perfect timing (2 min hard cap, from Day 37's drilling) — this is the last full pass before mocks are done and interviews start.
- Confirm you have a tailored **company-specific answer** ready for each of your 3 target companies: "why this company," "why this role," and one story pre-mapped to a value/principle they publicly emphasize (check their careers page or engineering blog for stated values — Amazon's Leadership Principles are the most explicit example, but most companies signal something).
- Prepare your **questions to ask** list, finalized: 2 company-specific (from Block 1) + 2-3 generic-but-good ones (team structure, what success looks like in 6 months, current technical challenges). Have more ready than you'll use — interviews sometimes answer your planned questions before you ask them.

**Verify you're actually strong here:** pick one story at random (have someone else pick, or use a die roll against your numbered list) and deliver it cold, timed. If it's not under 2 minutes or you fumble the STAR structure, that story needs one more rehearsal tonight, not tomorrow.

## Key takeaways

- Company research only pays off if it's structured and converted into material (a tailored design angle, specific questions, a real "why us") — passive browsing doesn't transfer to interview performance.
- A good interviewer-facing question references something only that company's research would surface — generic questions signal you didn't prepare.
- System design practice today is about eliminating silence and narrating transitions, not learning new architecture.
- Every one of your 10 STAR stories should be interview-ready cold, at random, under 2 minutes — that's the actual bar, not "I know roughly what I'd say."
- Prepare more closing questions than you'll need; some get answered organically during the interview.
- "Why this company" only works if it's specific enough that it would fail as an answer for a different company.

---
kind: lesson
type: system_design
id_key: interview-prep-45/day-28-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Code Review System"
position: 12
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

A code review system, think GitHub or GitLab pull requests, combines several distinct problems into one product: showing a diff efficiently even for a huge repository, a multi-person approval workflow, real-time commenting, and a live connection to an external CI system whose results decide whether a merge is even allowed. This question tests whether you can break a "big product" prompt into clean service boundaries instead of one giant tangled design.

## Requirements

**Functional requirements**
- Submit a change (a pull or merge request) as a diff against a base branch.
- Reviewers comment on specific lines, and approve or request changes.
- Track review status and merge readiness: approvals, CI status, conflicts.
- Integrate with CI/CD: trigger builds and tests on new commits, surface results, and gate merging on passing checks.

**Non-functional requirements**
- Diff computation and display must stay fast, even for large files and large repositories.
- Comments and status updates should feel real-time to everyone viewing the same pull request.
- Merge decisions must be consistent: a pull request should never be mergeable while it's actually missing required approvals or has failing checks, even under concurrent updates.
- Must scale to many concurrent pull requests across many repositories, without one huge, busy repository slowing down a quiet one.

> **Remember:** this system's hard problem is workflow correctness, not raw throughput. A code review platform handles nowhere near the traffic of a chat app, but getting "is this actually mergeable right now" wrong is a real bug, not a minor inconvenience.

```knowledge-check
{ "questions": [
    { "id": "system-design-codereview-requirements-q1", "type": "mcq", "prompt": "What is the central hard problem in a code review system, compared to a high-traffic consumer app?", "options": [
        {"id": "a", "text": "Handling millions of requests per second"},
        {"id": "b", "text": "Getting workflow correctness right, like accurately knowing whether a pull request is truly mergeable at any given moment"},
        {"id": "c", "text": "Storing large amounts of user-generated video content"},
        {"id": "d", "text": "There is no hard problem, it's a simple CRUD app"}
    ], "correct": "b", "explanation": "Traffic here is modest compared to consumer-scale systems. The genuine difficulty is correctness under concurrent updates: approvals, CI status, and conflicts all have to agree before a merge is allowed." }
] }
```

## Estimates

Assume a large engineering platform: 500,000 active repositories, 2 million open pull requests at any time, and 5 million pull-request events a day (commits pushed, comments added, reviews submitted, CI updates).

- **Event rate:** 5,000,000 / 86,400 ≈ 58/sec average, modest compared to the consumer-scale systems earlier in this course.
- **Diff size:** most diffs are tens of lines, but the system has to survive an occasional huge one, thousands of lines or a large generated file, without falling over. This is a long-tail cost problem, not an average-cost one.
- **CI trigger volume:** assuming every push triggers a run, and pushes happen about 3 times per pull request before merge, that's roughly 6 million CI triggers a day, each one potentially spinning up a build that costs far more compute than the tiny event that triggered it. CI compute cost, not request volume, is the real capacity concern.

## API

```
POST /repos/{repo}/pulls          { source_branch, target_branch, title, description }
  -> { pr_id, diff_id }

GET  /pulls/{pr_id}/diff                                    -> { files[], hunks[] }
POST /pulls/{pr_id}/comments      { file, line, body }        -> { comment_id }
POST /pulls/{pr_id}/review        { verdict: "approve"|"request_changes"|"comment", body }
GET  /pulls/{pr_id}/status                                    -> { approvals[], ci_status, mergeable }
POST /pulls/{pr_id}/merge                                     -> { status }

POST /webhooks/ci-status          { pr_id, commit_sha, status, checks[] }   -- inbound from CI system
```

## Data model

```
pull_requests      id, repo_id, source_branch, target_branch, base_sha, head_sha,
                   status (open|merged|closed), created_at
commits             pr_id, sha, parent_sha, pushed_at
reviews             id, pr_id, reviewer_id, verdict, body, commit_sha_reviewed, created_at
comments            id, pr_id, file_path, line_number, body, thread_id, resolved (bool), created_at
ci_checks           pr_id, commit_sha, check_name, status (pending|success|failure), updated_at
merge_rules         repo_id, required_approvals, required_checks[]
```

Every review is tied to `commit_sha_reviewed`, not just to the pull request as a whole. That detail matters: if a reviewer approves at one commit and the author pushes another commit afterward, whether that approval still counts is a policy decision the system has to make explicit, not something left implicit.

```knowledge-check
{ "questions": [
    { "id": "system-design-codereview-datamodel-q1", "type": "mcq", "prompt": "Why does the reviews table store commit_sha_reviewed instead of just linking a review to the pull request?", "options": [
        {"id": "a", "text": "It's redundant information with no real purpose"},
        {"id": "b", "text": "Without it, the system couldn't answer whether an approval was given against the current head or a since-superseded commit"},
        {"id": "c", "text": "Git requires every table to store a commit sha"},
        {"id": "d", "text": "It's only used for display purposes in the UI"}
    ], "correct": "b", "explanation": "Tracking exactly which commit a review was given against is what makes it possible to enforce a staleness policy when the author pushes new commits after an approval." }
] }
```

## High-level design

```
Author pushes commits --> Git service stores commits/refs (existing git infrastructure,
                          not reinvented here) --> "commits_pushed" event
                                    |
                    Diff service: compute diff between base_sha and head_sha
                    (cached, recomputed only when either sha changes)
                                    |
                    CI trigger --> external CI/CD system runs build/tests -->
                    webhook POST /webhooks/ci-status --> ci_checks updated
                                    |
Reviewer views PR --> Diff service (cached diff) + Comments (real-time via
websocket/long-poll for collaborators viewing the same PR) + reviews
                                    |
PR status aggregation: mergeable = (required_approvals met) AND
(all required_checks passing) AND (no merge conflicts against target_branch)
                                    |
POST /pulls/{pr_id}/merge --> re-validate mergeable at merge time (not just display time)
--> perform the merge --> pr.status = merged
```

## Deep dives

### Should diffs be stored, or computed on demand?

Computed and cached, never stored as a separate copy. The source of truth is the git repository itself, its commits, trees, and blobs. The system shouldn't duplicate that. A pull request's diff is derived on demand between `base_sha` and `head_sha` using standard diff machinery, then cached by that sha pair, since the same diff gets requested repeatedly by every viewer until either side moves. This is the same "keep a durable source of truth separate from a fast derived structure" pattern that shows up in the file storage design, git is the durable source, the diff cache is the fast-read structure on top of it.

For a very large file, the computation itself can get expensive, not just serving the result. Mitigate with size limits (collapse or truncate a diff past some threshold, showing "this file is too large to display inline") and by computing large diffs asynchronously, showing a "diff pending" state instead of blocking the page load.

### How do live comments work without a merge algorithm like Google Docs needs?

Multiple reviewers viewing the same pull request should see new comments and status changes appear without a manual refresh, delivered over a lightweight push channel (WebSocket or server-sent events). Unlike Google Docs, comment threads don't need operational-transform-style merging: each comment is an independent, append-only entry in a thread, keyed by `file_path` plus `line_number` or a `thread_id`, so two reviewers commenting at the same time simply both succeed with nothing to reconcile. The only real requirement is timely delivery, not merging.

> **Remember:** not every real-time feature needs a merge algorithm. Comments are independent append-only events; only truly shared, mutable content (like Google Docs text) needs OT or CRDTs.

```knowledge-check
{ "questions": [
    { "id": "system-design-codereview-comments-q1", "type": "mcq", "prompt": "Why don't pull request comments need the same operational-transform merge logic that Google Docs requires?", "options": [
        {"id": "a", "text": "Comments are too unimportant to bother merging correctly"},
        {"id": "b", "text": "Each comment is an independent, append-only entry, so two simultaneous comments never actually conflict with each other"},
        {"id": "c", "text": "Comments are never shown in real time"},
        {"id": "d", "text": "WebSockets automatically handle merging for any data type"}
    ], "correct": "b", "explanation": "Merge algorithms exist to resolve conflicting edits to the same shared content. Comments don't have that problem: each one is its own independent row, so there's nothing to reconcile." }
] }
```

### How does the CI/CD gate actually work, and what happens when approvals go stale?

The review system never runs builds itself. It triggers an external CI system on new commits and later receives an asynchronous status update through `POST /webhooks/ci-status`, updating the `ci_checks` table. This is a fire-and-forget trigger with a callback arriving later, since CI runs can take anywhere from seconds to tens of minutes. `mergeable` is computed by checking every check the repo actually requires against `ci_checks`; a pending required check correctly blocks merge rather than being silently ignored.

Approval staleness is a policy question the design has to answer explicitly, not something to leave ambiguous: if a reviewer approves at commit A and the author then pushes commit B, is that approval still valid? Common answers are auto-dismissing the approval on any new commit (safest, but adds friction for a trivial typo fix), or letting it persist unless the repo's rules specifically require re-approval on push. Either way, `commit_sha_reviewed` is what makes the policy enforceable at all.

### How do you stop a merge that's actually not ready from slipping through?

The `mergeable` value shown on a pull request's page is a read, and it can go stale the moment before someone clicks merge, another commit landed, or a check just flipped to failing. The merge endpoint must re-check `mergeable` atomically at the moment of merging, never trusting whatever the client last displayed. This is the same principle as re-checking inventory at checkout instead of trusting a stale "in stock" label: recompute at the point of the state-changing action, not at the point of display. If the target branch has also moved because someone else merged a conflicting change first, the merge attempt has to detect that and reject cleanly rather than producing a broken merge commit.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Compute and cache diffs, never store them | No duplicated storage of git data; cache invalidates cleanly on sha change | A cache miss pays a real computation cost, worse for very large diffs |
| Async CI trigger plus webhook callback | Correctly models CI runs that take minutes without blocking the author | The API and UI must honestly represent a "pending" state |
| Comment threads as independent entries, no merge logic | Simple, nothing to reconcile | Doesn't generalize to true collaborative text editing, which is fine since comments aren't that |
| Re-validate mergeable atomically at merge time | Prevents merging something that's actually missing approvals or checks | A bit more work on the merge endpoint than trusting a cached flag |
| Shard by repo_id | Isolates a busy repository from a quiet one | A cross-repo query, like "all my open PRs everywhere," needs a fan-out or a separate index |

**Q: A reviewer clicks approve at the exact moment the author force-pushes a new commit. What happens?**
A: The approval is tied to the commit sha the reviewer was actually looking at, captured client-side when they loaded the review, not assumed to be "whatever the current head is" on the server. The system records the approval against the sha it was actually given for, then applies the repo's staleness policy when computing current mergeability, so an approval never silently applies to code the reviewer never saw.

**Q: How do you keep diff computation fast for a pull request touching a 50,000-line generated file?**
A: Apply practical limits instead of trying to diff arbitrary sizes fast: detect oversized files and collapse them by default ("this file has X changes, click to expand"), skip expensive line-level diffing for files a repo marks as generated (lockfiles, minified bundles), and compute large diffs asynchronously with a pending state rather than blocking the page.

**Q: Two pull requests touching the same file merge in quick succession. How do you stop the second merge from silently discarding the first one's changes?**
A: This is git's own merge-conflict detection, not something the review system reinvents. At merge time, the second merge attempts a real merge against the current target branch, which now includes the first pull request's changes, and either succeeds cleanly or reports a conflict a human has to resolve before merging can continue.

```knowledge-check
{ "questions": [
    { "id": "system-design-codereview-tradeoffs-q1", "type": "mcq", "prompt": "Why must the merge endpoint re-check mergeable status atomically at merge time, instead of trusting the status shown on the PR page?", "options": [
        {"id": "a", "text": "Because the PR page's status is always wrong"},
        {"id": "b", "text": "Because that displayed status can go stale in the moments between when it was computed and when the user clicks merge"},
        {"id": "c", "text": "Because git does not support checking mergeability at all"},
        {"id": "d", "text": "Because re-checking is required by law for code review tools"}
    ], "correct": "b", "explanation": "A new commit, a flipped check, or a competing merge can all happen after the status was last displayed. Only re-checking at the moment of the actual merge action guarantees correctness." }
] }
```

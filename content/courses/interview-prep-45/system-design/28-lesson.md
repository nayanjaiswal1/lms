---
kind: lesson
type: system_design
id_key: interview-prep-45/day-28-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Code Review System"
position: 28
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today's system is a GitHub/GitLab-style code review platform — asked because it combines several distinct problems in one product: efficient diff storage for large repositories, a multi-actor review/approval workflow, real-time collaborative commenting, and integration with an external CI/CD system whose results feed back into the merge decision. It's a good test of whether you can decompose a "big product" prompt into clean service boundaries instead of one monolithic design.

## Requirements

**Functional**
- Submit a change (pull/merge request) with a diff against a base branch.
- Reviewers comment on specific lines, approve or request changes.
- Track review status and merge readiness (approvals, CI status, conflicts).
- Integrate with CI/CD: trigger builds/tests on new commits, surface results, gate merge on passing checks.

**Non-functional**
- Diff computation/display must stay fast even for large files and large repositories.
- Review comments and status updates should feel real-time to collaborators viewing the same PR.
- Merge decisions must be consistent — a PR shouldn't be mergeable if it's simultaneously missing required approvals or has failing CI, even under concurrent updates.
- Must scale to a large number of concurrent PRs across many repositories without one large/busy repo starving others.

## Capacity estimates

Assume a large engineering org/platform: 500K active repositories, 2M open PRs at any time, 5M PR events/day (commits pushed, comments added, reviews submitted, CI status updates).
- Event rate: 5M / 86,400 ≈ 58/sec average — modest compared to consumer-scale systems earlier in this course; this system's hard problem is workflow correctness and diff computation cost, not raw throughput.
- Diff size: most diffs are small (tens of lines), but the system must handle occasional large diffs (thousands of lines, or a large generated/binary file) without falling over — a long-tail-cost problem more than an average-cost one.
- CI trigger volume: assume every push triggers a CI run, and pushes happen ~3x per PR on average before merge → roughly 6M CI trigger events/day, each potentially spinning up a build/test job that's far more expensive (CPU-minutes) than the triggering event itself — CI compute cost, not request volume, is the real capacity concern here.
- Comment/collaboration traffic: PRs under active review can have bursts of near-simultaneous comments/reactions from multiple reviewers — a small-scale version of the real-time collaboration problem from Google Docs (Day 17-ish territory), but for structured comment threads rather than free-form text merging.

## API sketch

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

Reviews are tied to `commit_sha_reviewed`, not just to the PR — this matters: if a reviewer approves at one commit and the author pushes a new commit afterward, that approval's validity relative to the *current* head is a policy decision the system has to make explicit (see below), not something to leave implicit in the schema.

## High-level architecture

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

## Component deep dives

**Diff storage and computation — don't store diffs, compute and cache them.** The source of truth is the underlying git repository (commits, trees, blobs) — the system should not duplicate that storage in its own schema. A PR's diff is *derived*: computed on demand between `base_sha` and `head_sha` using standard diff algorithms (git's own diff machinery), then cached (keyed by the sha pair) since the same diff is requested repeatedly by every viewer of the PR until either side moves. This is the same "separate source of truth from fast serving structure" pattern from Day 14's review — git is the durable source, the diff cache is the fast-read derived structure. For large files, the diff computation itself (not just serving it) can be expensive — mitigate with size limits (truncate/collapse diffs beyond a threshold, e.g., "this file is too large to display inline") and by computing diffs asynchronously with a "diff pending" state shown to the user rather than blocking the PR page load on an expensive computation.

**Real-time collaborative comments.** Multiple reviewers viewing the same PR simultaneously should see new comments and status changes appear without a manual refresh — implemented via a lightweight push channel (WebSocket or server-sent events) that notifies connected clients of new comments/reviews/status changes on a PR, similar in shape to the "push channel is a wake-up signal, actual data still flows through a normal fetch" pattern from Day 12's file sync design. Unlike Google Docs, comment threads don't need operational-transform-style merge logic — each comment is an independent, append-only entry in a thread (keyed by `file_path` + `line_number` or a `thread_id`), so concurrent comments from different reviewers simply both get created without any conflict to resolve; the only real-time requirement is *delivery*, not *merging*.

**CI/CD integration and the merge gate.** The code review system doesn't run builds itself — it triggers an external CI/CD system (via webhook/API call on new commits) and receives asynchronous status updates back via `POST /webhooks/ci-status`, updating the `ci_checks` table. This is the same asynchronous-external-system pattern as Day 25's payment webhooks: the triggering call is fire-and-forget, and the final result arrives later via callback, because CI runs can take anywhere from seconds to tens of minutes. `mergeable` status is computed by aggregating `ci_checks` against the repo's `merge_rules.required_checks` — a PR isn't mergeable until every *required* check (not necessarily every check that ran) reports success, and a currently-`pending` required check correctly blocks merge rather than being silently ignored.

**Staleness of approvals after new commits.** If a reviewer approves at commit A, and the author then pushes commit B, is that approval still valid? This is a policy decision the design should surface explicitly, not hide: common approaches are (a) approvals are automatically dismissed/invalidated when the head commit changes, requiring re-review — safest, but adds review friction for trivial follow-up commits (like fixing a typo the reviewer themselves pointed out), or (b) approvals persist unless the repo's `merge_rules` specifically require re-approval on push, giving repo owners the choice. Either way, the schema tracking `commit_sha_reviewed` per review is what makes this policy enforceable — without it, you can't even ask "was this approval given against the current head."

**Preventing a merge that violates its own gate under concurrent updates.** The `mergeable` computation shown on the PR's status display is a read, and can be stale by the time a user clicks "merge" (someone else pushed a new commit, or a required check just flipped to failing, moments earlier). The merge endpoint must re-validate `mergeable` atomically at merge time — not trust the client's last-seen status — using the same "recompute and check at the point of the state-changing action, not at the point of display" principle as inventory checks at checkout (Day 23/24). If the target branch has also moved (someone else merged a conflicting PR first), the merge must additionally detect and reject on conflict rather than silently producing a broken merge commit.

**Scaling across many repositories.** Each repository's PR activity is largely independent of every other repository's — this is a natural sharding boundary (partition by `repo_id`) for both the PR/comment data and the diff-cache, and it means one exceptionally busy repository (a monorepo with thousands of daily commits) doesn't need to affect query latency or cache pressure for a quiet, low-traffic repository, provided the sharding/partitioning is actually enforced rather than everything landing in one shared table/cache without a partition key.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Compute + cache diffs rather than store them | No duplicated storage of git data, cache invalidates cleanly on sha change | Cache miss (new commit) pays a real computation cost, worse for very large diffs |
| Async CI trigger + webhook callback | Correctly models CI runs that take minutes, doesn't block the pushing author | PR status has a window where CI is "pending," requiring the UI/API to represent that state honestly |
| Comment threads as independent append-only entries (no merge logic) | Simple, no conflict resolution needed unlike free-text collaborative editing | Doesn't generalize to genuinely collaborative document editing — fine, since PR comments aren't that |
| Re-validate mergeable atomically at merge time | Prevents merging a PR that's actually missing approvals/checks due to stale display state | Slightly more work on the merge endpoint than trusting a cached status flag |
| Shard by repo_id | Isolates busy repos from quiet ones | Cross-repo queries (e.g., "all my open PRs across every repo") need a fan-out or a separate per-user index |

## Likely follow-up questions — with answers

**Q: A reviewer clicks "approve" at the exact moment the author force-pushes a new commit. What happens?**
A: The review submission should be tied to the commit sha the reviewer was actually looking at (`commit_sha_reviewed`), captured client-side when they loaded the review view, not assumed to be "whatever the current head is" server-side. If the head has already moved by the time the approval is submitted, the system records the approval as valid for the sha it was actually given against, and applies the repo's staleness policy (auto-dismiss on new commits, or persist) when computing current mergeability — this avoids the ambiguous outcome of an approval silently applying to code the reviewer never actually saw.

**Q: How do you keep diff computation fast for a PR that touches a huge generated file (e.g., a 50,000-line lockfile)?**
A: Apply practical limits rather than trying to make arbitrary-size diffing universally fast: detect oversized files (by line count or byte size) and collapse them in the default view ("this file has X changes, click to expand" or "diff too large to display, view raw"), skip expensive line-level diffing for files matching known-generated patterns (lockfiles, minified bundles) when a repo config marks them as such, and compute diffs asynchronously with a pending state rather than blocking page load on a worst-case file in the changeset.

**Q: Two PRs from different branches both modify the same file and are merged in quick succession. How do you prevent the second merge from silently discarding the first PR's changes?**
A: This is fundamentally git's own merge-conflict detection, not something the review system reinvents — at merge time, the second PR's merge operation attempts a real merge (or rebase, per repo policy) against the *current* target branch state (which now includes the first PR's changes), and git's merge machinery will either succeed cleanly (non-overlapping changes) or report a conflict that must be resolved by a human before merge can proceed. The review system's job is to re-check mergeability (including conflict-free status against current target branch head) atomically at merge time, exactly as described above for approval/CI staleness, and clearly surface conflicts to the author rather than allowing a stale "no conflicts" status to let a bad merge through.

## Key takeaways

- Diffs are derived and cached from git's own commit/tree data, never duplicated into the review system's own storage — the diff cache is a fast-serving structure over an authoritative git source, the same pattern from Day 14's review applied to code instead of documents/media.
- CI/CD integration follows the async-trigger-plus-webhook-callback pattern (same shape as Day 25's payment provider integration) because build/test runs take real time and can't block the triggering push.
- PR comment threads need real-time *delivery*, not conflict *merging* — each comment is an independent append-only entry, a meaningfully simpler problem than Google Docs' concurrent-text-editing merge.
- Approval staleness after new commits is an explicit policy decision the schema must support (`commit_sha_reviewed` tracked per review), not something to leave implicit.
- Mergeability must be re-validated atomically at the moment of merge, not trusted from a possibly-stale display-time computation — the same "check at the point of the state-changing action" principle as inventory/checkout systems.
- Sharding by repo_id isolates busy repositories from quiet ones and is the natural partition boundary for this domain, since most access patterns are scoped to a single repository.

---
kind: lesson
id_key: git/workflows/branching-strategies
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Branching Strategies: GitHub Flow, Trunk-Based, Git Flow"
position: 0
estimated_minutes: 9
source:
  - Pro Git book, ch. 3.4 "Branching Workflows" and ch. 5 "Distributed Git"
  - trunkbaseddevelopment.com; "A successful Git branching model" (V. Driessen, with its 2020 note)
---

## Why this matters

Git gives you branches; it does not tell a team how to use them. Every team
picks a **branching strategy**: which long-lived branches exist, where features
start, how code reaches production. Interviewers ask about it, and joining a
team means learning theirs on day one.

## Mental model: roads into the city

- **Trunk-based**: one main road (`main`); everyone joins it often through very
  short side streets.
- **GitHub flow**: one main road; each feature is a side street (branch) that
  merges back through a checkpoint (pull request with review and CI).
- **Git flow**: several parallel roads (`main`, `develop`, `release/*`,
  `hotfix/*`) with rules about which road feeds which.

## The three strategies

### GitHub flow (most common default)

```
 main  ----*----------*-----------*-----   always deployable
            \        /             \
 feature     A---B--'   (PR: review + CI, then merge)
```

1. Branch from `main`: `git switch -c feature/login`.
2. Commit, push, open a **pull request** (PR; GitLab says merge request).
3. CI runs, teammates review, you push fixes.
4. Merge into `main` (merge, squash or rebase button), delete the branch.
5. Deploy `main`.

A pull request is not a Git feature: it is a branch on the server plus a
request to merge it, with review and CI built around it by the host.

### Trunk-based development

```
 main  --*--*--*--*--*--*--*--   many small merges per day
          \/ \/    \/
       (branches live hours, not weeks)
```

Branches live less than a day or two. Unfinished features hide behind **feature
flags** (config switches) so half-done code can be merged safely. Used by teams
that deploy many times per day; it minimises merge conflicts because nothing
drifts far from main.

### Git flow

```
 main     ----*---------------------*------   tagged releases only
               \                   /
 release/1.2    \           *----*            stabilise, then merge to main + develop
                 \         /
 develop    ------*---*---*---*----            integration branch
                       \ /
 feature/x              *
 hotfix/1.1.1  branch from main, merge to main + develop
```

Suits software shipped in versions with long support (desktop apps, libraries,
on-premise products). Its author noted in 2020 that for continuously deployed
web apps a simpler flow is usually better.

### Choosing

| If your team... | Prefer |
|---|---|
| Deploys a web service continuously | GitHub flow or trunk-based |
| Deploys many times a day, strong CI, feature flags | Trunk-based |
| Ships numbered versions and maintains old ones | Git flow or release branches |

### Rules that hold in every strategy

- `main` is protected: no force push, merges via reviewed PRs, CI must pass.
- Keep branches short-lived; rebase or merge `main` in often.
- Small PRs (a few hundred lines) get better reviews.
- Name branches by purpose: `feature/...`, `fix/...`, `chore/...`.
- Write release notes from good commit messages (Conventional Commits help
  tools generate them).

## Try it

A team deploys their website ten times a day but long feature branches keep
causing painful merges. What change would you suggest?

<details>
<summary>Show answer</summary>

Move toward trunk-based development: merge small changes into `main` at least
daily, hide unfinished features behind feature flags, and rely on CI to keep
`main` green. Short-lived branches cannot drift far, so conflicts stay small.

</details>

## Common mistakes

- **Adopting Git flow by default.** Its extra branches add ceremony a
  continuously deployed app does not need.
- **Long-lived feature branches.** The longer a branch lives, the bigger the
  final merge. Integrate often.
- **No branch protection.** One accidental force-push can rewrite `main` for
  everyone.

## Remember

- GitHub flow: branch -> PR (review + CI) -> merge -> deploy.
- Trunk-based: tiny branches, merge daily, feature flags.
- Git flow: `develop`, `release/*`, `hotfix/*`; for versioned products.
- Always: protected `main`, short branches, small PRs.

**Self-check:**

1. What is a pull request in Git terms?
2. What problem do feature flags solve in trunk-based development?
3. When does Git flow make sense?

---
kind: lesson
id_key: git/workflows/hooks
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Git Hooks: Automatic Checks Before Commit and Push"
position: 2
estimated_minutes: 8
source:
  - Pro Git book, ch. 8.3 "Git Hooks"
  - githooks(5) manual page; git-config(1) core.hooksPath
---

## Why this matters

Linting, formatting, secret scanning and commit-message rules are easy to
forget. **Hooks** are scripts Git runs automatically at key moments, so the
check happens every time without anyone remembering. They catch problems in
seconds on your laptop instead of minutes later in CI.

## Mental model: tripwires on the path

Each hook is a tripwire at a step of the commit/push path. If the script exits
non-zero, the step is cancelled.

```
 git commit:  pre-commit -> prepare-commit-msg -> commit-msg -> (commit) -> post-commit
 git push:    pre-push -> (upload) ---> SERVER: pre-receive -> update -> post-receive
```

| Hook | Runs | Typical use | Can block? |
|---|---|---|---|
| `pre-commit` | Before the commit is created | Lint/format staged files, secret scan | Yes |
| `commit-msg` | After the message is written; gets its file path as `$1` | Enforce message format | Yes |
| `pre-push` | Before uploading | Run fast tests | Yes |
| `post-merge`, `post-checkout` | After the action | Reinstall dependencies | No |
| `pre-receive` (server) | When the server receives a push | Enforce policy for everyone | Yes |

## See it work

### Where hooks live

By default: `.git/hooks/<name>`, an executable file with exactly the hook's
name (no extension). Git ships `*.sample` files there as examples.

`.git/hooks` is **not** versioned or cloned. To share hooks with the team, keep
them in the repo and point Git at the folder:

```bash
mkdir -p .githooks
git config core.hooksPath .githooks
```

Each teammate still runs that `git config` once (or a setup script does it).

### A commit-msg hook

Require messages like `SHOP-42: Add coupon support`:

```bash
cat > .githooks/commit-msg <<'EOF'
#!/bin/sh
# $1 = path to the file holding the proposed message
if ! head -1 "$1" | grep -qE '^[A-Z]+-[0-9]+: .+'; then
  echo "commit-msg: subject must look like 'SHOP-42: Describe change'" >&2
  exit 1
fi
EOF
chmod +x .githooks/commit-msg
```

What it does: reads the first line of the message; exits 1 (blocking the
commit) if it lacks a ticket key. Try it:

```bash
git commit --allow-empty -m "fix stuff"
```

Expected output:

```
commit-msg: subject must look like 'SHOP-42: Describe change'
```

and no commit is created. `git commit -m "SHOP-42: Add coupon support"` works.

### A pre-commit hook that checks staged content

```sh
#!/bin/sh
# block commits that add obvious secrets
if git diff --cached -U0 | grep -qE '^\+.*(AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH) PRIVATE KEY)'; then
  echo "pre-commit: possible secret in staged changes" >&2
  exit 1
fi
```

Check **staged** content (`git diff --cached`), not the working tree, because
the commit is built from the index.

### Frameworks and limits

- Tools such as **pre-commit** (pre-commit.com), Husky (JavaScript) or
  Lefthook manage hook installation and run linters on staged files only.
- Anyone can skip client hooks with `git commit --no-verify` (`-n`). Hooks are a
  convenience, not security. Enforce rules for real in **CI** and server-side
  (protected branches, required checks, `pre-receive`).

## Try it

Your `pre-push` hook runs the full test suite (8 minutes) and people now use
`--no-verify` all the time. What would you change?

<details>
<summary>Show answer</summary>

Keep hooks fast (seconds): lint and format only changed files in `pre-commit`,
maybe a quick unit subset in `pre-push`. Move the full suite to CI as a
required check on pull requests. Slow hooks train people to bypass them.

</details>

## Common mistakes

- **Forgetting `chmod +x`.** A non-executable hook is silently ignored (Git
  prints a hint).
- **Naming it `commit-msg.sh`.** The file must be named exactly `commit-msg`.
- **Expecting `.git/hooks` to be shared.** It is not cloned; use
  `core.hooksPath` or a hook manager.
- **Treating hooks as enforcement.** `--no-verify` skips them.

## Remember

- Hooks = executable scripts named after an event; non-zero exit blocks.
- `pre-commit` checks staged content, `commit-msg` checks the message (`$1`).
- Share hooks via a versioned folder + `core.hooksPath`.
- Real enforcement lives in CI and on the server.

**Self-check:**

1. Which argument does `commit-msg` receive?
2. Why are hooks in `.git/hooks` not shared with teammates?
3. How can a developer bypass client hooks?

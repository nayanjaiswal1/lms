---
kind: lesson
id_key: git/troubleshooting/secrets-history
course: git
section: troubleshooting
section_title: "Troubleshooting Playbook"
section_position: 13
title: "A Secret Was Committed: Rotate, Then Rewrite History"
position: 1
estimated_minutes: 8
source:
  - git-filter-repo documentation (github.com/newren/git-filter-repo)
  - GitHub Docs, "Removing sensitive data from a repository"
---

## Why this matters

An API key, a password, a private key in a commit. Bots scan public
repositories for leaked keys within minutes. Even in a private repo, everyone
with access, every fork and every clone has the secret. The fix has a strict
order, and most people get it backwards.

## Mental model: a leaked house key

If you lose a house key, you **change the lock first**. Searching the street for
the key afterwards is optional. A secret in Git history is a leaked key:
deleting it from the repo does not un-leak it.

```
 1. ROTATE   revoke the secret and issue a new one        (mandatory, immediately)
 2. CLEAN    remove it from history                        (reduces future exposure)
 3. PREVENT  .gitignore, secret scanning, pre-commit hook  (stops the next one)
```

## See it work

### Step 1: rotate

Revoke the key in the provider's console (cloud, payment, database), create a
new one, put it in your secret manager or environment, redeploy. Until this is
done, nothing else matters.

### If it is only in your last local commit (not pushed)

Easiest case; no history rewrite on the server needed:

```bash
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit --amend --no-edit
```

Check the result with `git show --stat HEAD`. Rotate anyway if there is any
chance it left your machine.

### If it is deeper in history or pushed: git filter-repo

`git filter-repo` is the tool the Git project recommends (it replaced the slow,
error-prone `git filter-branch`). It is a separate install
(`pip install git-filter-repo` or your package manager).

Work on a fresh clone:

```bash
git clone --mirror git@github.com:brightside/shop.git
cd shop.git
git filter-repo --invert-paths --path .env                    # remove a file from every commit
# or replace the secret text everywhere:
printf 'sk_live_51H...==>REDACTED\n' > ../replacements.txt
git filter-repo --replace-text ../replacements.txt
git push --force --mirror
```

What this does: rewrites every commit that contained the file or text. **Every
hash after the first affected commit changes**, so this is the biggest rewrite
there is.

Afterwards:

- Every teammate must re-clone (or carefully reset); old clones still contain
  the secret and will re-push it if merged.
- Open pull requests and forks keep the old commits. On GitHub/GitLab, contact
  support to purge cached views and PR refs if needed.
- Protected branches must be temporarily unprotected for the force push.

The BFG Repo-Cleaner is an older alternative with similar results.

### Step 3: prevent the next leak

- `.gitignore` for `.env`, key files and local config; commit only
  `.env.example` with placeholders.
- Enable the host's **secret scanning and push protection** (blocks pushes
  containing known key formats).
- Run a scanner such as gitleaks or trufflehog in a `pre-commit` hook and in CI.
- Load secrets from environment variables or a secret manager, never from
  tracked files.

## Try it

A teammate says: "I pushed our Stripe key an hour ago, but I already deleted
the file in a new commit, so we are fine." What do you tell them, in order?

<details>
<summary>Show answer</summary>

1. Not fine: the key is still in the earlier commit, visible to anyone with
   access (and to scanners if the repo is public).
2. Revoke the key in Stripe and issue a new one **now**.
3. Then decide whether to rewrite history with `git filter-repo` (and coordinate
   re-clones), and enable secret scanning / push protection.

</details>

## Common mistakes

- **Cleaning history but not rotating.** Any clone, fork, CI cache or scraper
  made before the rewrite still has the secret.
- **Using `git filter-branch`.** Slow and easy to get wrong; its own manual
  page recommends filter-repo.
- **Rewriting without telling the team.** Old clones re-introduce the secret on
  the next merge.

## Remember

- Order: **rotate**, then clean, then prevent.
- Last unpushed commit: `git rm --cached` + `--amend`.
- Deeper or pushed: `git filter-repo` on a mirror clone, force-push, everyone re-clones.
- Prevent with `.gitignore`, secret scanning, push protection and pre-commit scanners.

**Self-check:**

1. What must happen before any history rewrite?
2. Why must teammates re-clone after `filter-repo`?
3. Name two ways to stop the next secret before it is pushed.

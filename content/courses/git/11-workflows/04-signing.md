---
kind: lesson
id_key: git/workflows/signing
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Signing Commits and Tags (SSH and GPG)"
position: 3
estimated_minutes: 7
source:
  - Pro Git book, ch. 7.4 "Signing Your Work"
  - git-config(1) gpg.format, user.signingKey, gpg.ssh.allowedSignersFile; git-commit(1) -S
---

## Why this matters

Anyone can run `git config user.name "Maya Lead"` and commit as Maya. The
author field is just text. A **signature** proves a commit or tag was made by
someone holding a specific private key. Many companies and open-source projects
require signed commits on protected branches, and supply-chain security
standards build on it.

## Mental model: a wax seal

The author line is a name written on the envelope; anyone can write it. A
signature is a wax seal from a ring only you own. Others check the seal against
your public key.

```
 commit content --sign with PRIVATE key--> signature stored in the commit
 verifier       --check with PUBLIC key--> "Good signature from Ada" or "BAD"
```

Two key types work:

| | SSH signing (Git 2.34+) | GPG |
|---|---|---|
| Key you probably already have | Yes (`~/.ssh/id_ed25519`) | Needs `gpg` setup |
| Setup effort | Low | Higher (keyrings, expiry, subkeys) |
| Host support | GitHub, GitLab | GitHub, GitLab |

## See it work

### Set up SSH signing once

```bash
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519.pub
git config --global commit.gpgSign true     # sign every commit
git config --global tag.gpgSign true        # sign every annotated tag
```

Despite the `gpg` in the names, these keys control SSH signing too. Then upload
the same public key on the host as a **signing key** (a separate setting from
the authentication key list, even if the key is the same).

### Sign and verify

```bash
git commit -S -m "Add coupon support"   # -S signs this commit (automatic if commit.gpgSign=true)
git tag -s v1.2.0 -m "Release 1.2.0"    # signed annotated tag
```

To verify SSH signatures locally, Git needs a list of trusted keys:

```bash
echo "ada@example.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
git log --show-signature -1
git verify-commit HEAD
git verify-tag v1.2.0
```

Expected `verify-commit` output for a valid signature:

```
Good "git" signature for ada@example.com with ED25519 key SHA256:...
```

On GitHub/GitLab, signed commits from a registered key show a **Verified**
badge. Branch protection can require it.

### GPG in two lines

```bash
gpg --full-generate-key                          # create a key
git config --global user.signingKey <KEY-ID>     # gpg.format stays the default (openpgp)
```

Export the public key with `gpg --armor --export <KEY-ID>` for the host.

### What signing does not do

- It does not encrypt anything; content stays readable.
- It proves who signed, not that the code is good.
- Rebasing or amending creates new commits that must be signed again
  (automatic with `commit.gpgSign true`). Commits made by the host's merge
  button are signed by the host's key.

## Try it

Your company requires signed commits on `main`. You rebased your PR branch and
the host now shows your commits as "Unverified". Why, and how do you fix it?

<details>
<summary>Show answer</summary>

Rebase created **new** commits, and they were not signed (signing was not
enabled for every commit). Enable `commit.gpgSign true`, then re-sign the
branch's commits, for example:

```bash
git rebase --exec 'git commit --amend --no-edit -S' origin/main
git push --force-with-lease
```

</details>

## Common mistakes

- **Uploading the key only as an authentication key.** Hosts need it listed as
  a signing key to show "Verified".
- **Signing with an email the host does not know.** The commit email must
  match a verified email on your account.
- **Thinking `user.name` proves identity.** Only signatures do.

## Remember

- Author fields are just text; signatures prove key ownership.
- SSH signing: `gpg.format ssh` + `user.signingKey` + `commit.gpgSign true`.
- Verify with `git log --show-signature`, `git verify-commit`, `git verify-tag`.
- Rewritten commits need re-signing.

**Self-check:**

1. Why can't the author field be trusted on its own?
2. Which setting makes Git use SSH keys for signing?
3. Why do rebased commits lose their signatures?

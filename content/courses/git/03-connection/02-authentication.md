---
kind: lesson
id_key: git/connection/authentication
course: git
section: connection
section_title: Connecting to the Team
section_position: 3
title: "Proving Who You Are: SSH Keys and Tokens"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 4 "Git on the Server"
  - ssh-keygen(1), git-credential(1), gitcredentials(7) manual pages
---

## Why this matters

On a real host (GitHub, GitLab, Bitbucket) this is where most beginners get
stuck. Hosts stopped accepting account passwords for Git operations, so you
need either an **SSH key** or a **personal access token**. Pick one, set it up
once, and learn the three error messages that tell you what is wrong.

## Mental model: a key or a badge

```
 SSH    git@host:you/project.git     a key pair: the PRIVATE key stays on your
                                     machine; the PUBLIC key is given to the host
                                     (like giving the host a lock only your key opens)

 HTTPS  https://host/you/project.git  username + personal access token
                                      (a revocable badge with chosen permissions)
```

- **Public key** (`id_ed25519.pub`): safe to share. Paste it into the host.
- **Private key** (`id_ed25519`): never share, never commit, never email.
- **Personal access token (PAT)**: a long random string you create on the host
  and use instead of your password. Give it an expiry date and the smallest
  permissions needed.

## See it work

### SSH in four commands

```bash
ssh-keygen -t ed25519 -C "you@example.com"     # 1. create the key pair
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519   # 2. load it into the agent
cat ~/.ssh/id_ed25519.pub                      # 3. copy this into the host's SSH keys page
ssh -T git@github.com                          # 4. test
```

What step 1 does: creates `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`,
asking for an optional passphrase (use one; the agent remembers it). Step 4's
expected output on GitHub:

```
Hi ada-student! You've successfully authenticated, but GitHub does not provide shell access.
```

Then use the SSH URL: `git remote set-url origin git@github.com:brightside/shop.git`.

### HTTPS with a token

1. On the host: Settings -> Developer settings / Access tokens -> create a token
   with repository read/write scope and an expiry.
2. `git push`; when asked for a password, paste the **token**.
3. Let a credential helper remember it:

```bash
git config --global credential.helper cache     # in memory, 15 minutes by default
# or a secure OS store: manager (Git Credential Manager), osxkeychain, libsecret
```

`credential.helper store` also works, but it saves the token in **plain text**
in `~/.git-credentials`. Avoid it on shared machines.

### When it fails, read the error

```
 Permission denied (publickey)   public key not added to the host, or key not loaded in ssh-agent
 Authentication failed           expired/wrong token, or the account password was used
 Repository not found            URL typo, or no access to a private repo
```

Debug SSH with `ssh -vT git@github.com`; it prints which key files it tried.

```knowledge-check
{ "questions": [
  { "id": "git-connection-q1", "type": "mcq",
    "prompt": "You get 'Permission denied (publickey)' when pushing over SSH. What do you check first?",
    "options": [
      {"id":"a","text":"That the public key is uploaded to the host and the key is loaded in ssh-agent"},
      {"id":"b","text":"That the branch is called main"},
      {"id":"c","text":"That the commit message is short"},
      {"id":"d","text":"That the repository has a README"}],
    "correct": "a",
    "explanation": "The host must know your public key, and your machine must offer the matching private key. Branch names, messages and READMEs have nothing to do with authentication." },
  { "id": "git-connection-q2", "type": "mcq",
    "prompt": "git push over HTTPS says 'Authentication failed' although your account password is correct. Most likely cause?",
    "options": [
      {"id":"a","text":"Hosts require a personal access token, not the account password"},
      {"id":"b","text":"The branch is named main"},
      {"id":"c","text":"Your commits are too large"},
      {"id":"d","text":"SSH is also enabled"}],
    "correct": "a",
    "explanation": "GitHub and GitLab no longer accept account passwords for Git over HTTPS. Branch names and commit size do not cause authentication errors, and having SSH set up does not block HTTPS." }
] }
```

## Try it

A new teammate committed their `~/.ssh/id_ed25519` file into the repo by
mistake. What must happen, in order?

<details>
<summary>Show answer</summary>

1. Remove that public key from their host account immediately (the private key
   is compromised).
2. Generate a new key pair and register the new public key.
3. Remove the file from the repo (and ideally from history, Section 13).

Deleting the file alone is not enough: it remains in history.

</details>

## Common mistakes

- **Pasting the private key into the host.** Always paste the `.pub` file.
- **Tokens with no expiry and full scopes.** If leaked, they open everything.
  Use fine-grained, expiring tokens.
- **Mixing URL types.** A repo cloned over HTTPS keeps asking for a token even
  after you set up SSH. Switch the remote URL to the SSH form.
- **Typing your password at the HTTPS prompt.** It must be the token.

## Remember

- SSH: private key stays home, public key goes to the host. Test with `ssh -T`.
- HTTPS: use a personal access token as the password; store it with a credential helper.
- `publickey` = key problem. `Authentication failed` = token problem. `not found` = URL or access.
- A leaked key or token must be revoked, not just deleted.

**Self-check:**

1. Which of the two key files do you upload to GitHub?
2. Why is `credential.helper store` risky?
3. What does "Repository not found" usually mean on a private repo?

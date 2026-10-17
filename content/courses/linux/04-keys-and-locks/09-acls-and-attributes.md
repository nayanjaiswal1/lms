---
kind: lesson
id_key: linux/keys-and-locks/acls-and-attributes
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Beyond rwx: ACLs and File Attributes"
position: 8
estimated_minutes: 7
source:
  - acl(5), setfacl(1), getfacl(1), chattr(1), lsattr(1) manual pages
---

## Why this matters

Sam, from accounting, needs to read one report in `/srv/roastery`. He is not the
owner, and adding him to the `baristas` group would give him every team file.
Owner/group/others has only three slots. **ACLs** add more slots, one per person
or group.

## Mental model: extra named keys

- Classic permissions: three locks (owner, group, others).
- An **ACL** (access control list) adds named locks: "user sam: read",
  "group auditors: read".
- A `+` at the end of the mode in `ls -l` says "this file has extra locks; look
  closer".

```
 -rw-r-----+ 1 rhea baristas 812 Oct 14 report.csv
           ^ ACL present
```

## See it work

ACL tools come from the `acl` package (`sudo apt install acl`). They are not
installed in the lab image, so try these on your own machine.

```bash
setfacl -m u:sam:r report.csv       # -m modify: give user sam read
getfacl report.csv
```

Expected output:

```
# file: report.csv
# owner: rhea
# group: baristas
user::rw-
user:sam:r--
group::r--
mask::r--
other::---
```

Read it top to bottom: owner `rw-`, named user sam `r--`, owning group `r--`,
others nothing.

### The mask

`mask::` is a ceiling for every named entry and the group. If the mask is `r--`,
even `u:sam:rw` only gets read. `chmod g=...` on a file with an ACL actually
changes the **mask**, which surprises people. Check with `getfacl` after a
`chmod`.

### Default ACLs: inherit on new files

```bash
setfacl -d -m g:auditors:r /srv/roastery/reports   # -d: default for new files
setfacl -x u:sam report.csv                        # remove one entry
setfacl -b report.csv                              # remove all ACLs
```

A **default ACL** on a directory is copied to every new file created inside,
which is how you keep a shared folder readable by a second group.

Copying with `cp` drops ACLs unless you use `cp -a` (or `--preserve=all`), and
`tar` needs `--acls`.

### File attributes: locks even root respects

Attributes are a separate, filesystem-level set of flags (ext4, xfs).

```bash
lsattr notes.txt                    # list attributes
sudo chattr +i /etc/resolv.conf     # immutable: nobody, not even root, can change or delete it
sudo chattr -i /etc/resolv.conf     # remove the flag
sudo chattr +a /var/log/audit.log   # append-only: can add, never rewrite
```

```
--------------e------- notes.txt
```

(`e` just means the file uses extents, normal on ext4.) Setting `+i` or `+a`
needs root. If root gets "Operation not permitted" deleting a file, check
`lsattr` before anything else.

## Try it

Sam must read `report.csv` (owner rhea, group baristas, mode 640) and nobody
else outside the team may. What do you run, and how will `ls -l` look after?

<details>
<summary>Show answer</summary>

```bash
setfacl -m u:sam:r report.csv
getfacl report.csv            # confirm user:sam:r--
```

`ls -l` shows `-rw-r-----+`: the same base mode with a `+` for the ACL.

</details>

## Common mistakes

- **Missing the `+` in `ls -l`.** The visible mode is no longer the full story;
  run `getfacl`.
- **A `chmod` that silently shrinks the mask.** Named users lose access.
- **ACLs where a group would do.** If five people need the same access, make a
  group. ACLs are for exceptions.
- **Forgetting immutable files.** `chattr +i` makes upgrades and edits fail with
  confusing errors.

## Remember

- ACLs add named users/groups: `setfacl -m u:NAME:r file`, read with `getfacl`.
- `+` after the mode = ACL present; `mask` caps named entries.
- `setfacl -d` sets defaults for new files in a directory.
- `chattr +i` (immutable) and `+a` (append-only); check with `lsattr`.

**Self-check:**

1. What does the `+` in `-rw-r-----+` mean?
2. What is the ACL mask for?
3. Root cannot delete a file. Which command do you run first?

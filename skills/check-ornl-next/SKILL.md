---
name: check-ornl-next
license: MIT
description: Find and cherry-pick build, CI, and configuration commits from upstream/main onto an ornl-next branch of the Mantid repository. Optionally takes commit shas as arguments to carry over as well, whatever they touch. Use when asked to check for ornl-next commits, sync ornl-next with main, reconcile ORNL branch build configuration, or verify that an ornl-next branch still merges cleanly into main.
---

# Check for ornl-next commits

Identify changes on `upstream/main` that touch build and configuration files, and
carry them onto an `ornl-next` branch.

## Scope

In scope: the build, CI, packaging, linting and repo-level configuration surface,
enumerated in `scripts/check-paths.sh`. That script is the single source of truth
for the path list -- do not retype the list into a command.

Run every command below from the root of the Mantid checkout. `$SKILL` is this
skill's own directory, normally `.claude/skills/check-ornl-next`:

```sh
SKILL=.claude/skills/check-ornl-next
```

## Choosing the git remote

Remote naming is a local convention, so nothing here assumes `upstream`. The
scripts resolve the remote in this order:

1. `--remote NAME`, if given.
2. `$ORNL_REMOTE`, if set.
3. The remote whose fetch URL is `mantidproject/mantid`. Contributor forks are
   not matched, so a checkout full of collaborator remotes still resolves.
4. `upstream`, if it exists.

If none apply the scripts stop and list the available remotes rather than
guessing. To see what would be chosen:

```sh
"$SKILL"/scripts/check-paths.sh --remotes
```

If the user names a remote, pass it through with `--remote`. If detection fails,
ask which remote tracks `mantidproject/mantid` rather than picking one.

`--main` and `--ornl` take complete refs and override the remote for that branch,
which is how you check a local or contributor branch:

```sh
"$SKILL"/scripts/check-paths.sh --ornl my-reconciliation-branch
```

Out of scope: ordinary science-code divergence. `main` is routinely ahead of
`ornl-next` by dozens of source files; that is expected and is not this skill's
concern.

## Explicitly requested commits

Any shas given as arguments to this skill are commits the user wants carried
over whatever they touch -- typically a fix that lands outside the configuration
surface. They are additional to the path diff, never a replacement for it.

Pass each one through with `--include`, which is repeatable and also takes a
comma-separated list. Both scripts accept it:

```sh
"$SKILL"/scripts/check-paths.sh --include 1a2b3c4 --include 5d6e7f8
```

Requested commits:

- make step 2 report work to do even when the configuration paths are in sync,
  so exit status 0 no longer means "nothing to do".
- come back from `--log` merged into the topological order of the path commits,
  so the listed order remains the order to cherry-pick in. One that predates the
  baseline release, or is not in the range at all, is listed first.
- are listed whether or not `ornl-next` already has their content. That question
  belongs to the cherry-pick itself: if one applies empty, `git cherry-pick
  --skip` it and say so in the report.

A requested commit that is not an ancestor of `main` puts something on the
branch that `main` does not have, which is exactly what verification 2 rejects.
The scripts warn when they see one. Report that to the user rather than dropping
the commit or skipping the check.

## Hard rules

- Apply missing upstream changes with `git cherry-pick` **only**. Never recreate
  an upstream change as a fresh local commit, a partial `git checkout` of a file,
  or a manual edit.
- Cherry-pick in topological history order, never commit-date order. Use
  `git log --topo-order --reverse`.
- A merge commit needs an explicit mainline parent: `git cherry-pick -m 1 <sha>`,
  or `-m 2` when the upstream change arrived through the second parent.
- Leave untracked local files alone. This repo commonly has scratch files at its
  root; they are not yours to clean up.

## Procedure

1. Fetch first. Every check below is meaningless against stale refs. Use the
   remote resolved above -- `git remote` if you are unsure which it is.

   ```sh
   git fetch <remote>
   ```

2. Ask what differs.

   ```sh
   "$SKILL"/scripts/check-paths.sh
   ```

   Exit status 0 means in sync and **you are done** -- report that and stop.
   Exit status 1 lists the configuration files that `main` has and `ornl-next`
   does not.

   Add `--remote NAME` if the mantidproject remote is not auto-detected, and
   `--include SHA` for each sha the user named. With requested shas the status
   is never 0, because those commits are work to do on their own.

3. Only if step 2 reported differences, find the commits responsible.

   ```sh
   "$SKILL"/scripts/check-paths.sh --log
   ```

   This lists commits on `main` touching the configuration paths since the last
   full release, oldest first, already in topological order. Repeat the same
   `--include` arguments here so the requested commits land in that order too.

4. Cherry-pick them in the order listed, resolving conflicts as below.

5. Verify (next section). Then regenerate the reference table:

   ```sh
   "$SKILL"/scripts/regenerate-outstanding.sh
   ```

   Again with the same `--include` arguments, so the generated table records
   what was actually carried over.

## Do not use ancestry to decide what is missing

`git merge-base --is-ancestor <sha> <remote>/ornl-next` is **not** a reliable
test of whether an upstream change has been applied.

`ornl-next` receives configuration through squashed roll-up pull requests
(`Configuration changes into ornl-next (#42129)`), which reproduce upstream
content without preserving upstream ancestry. Measured on 2026-08-31: of 119
configuration-path commits on `main` since `v6.16.0`, ancestry reported all 119
as missing, while the file-level diff was empty. Every one of those cherry-picks
would have been redundant.

The content diff in step 2 is authoritative. Commit logs only explain a
non-empty diff; they never establish one.

## Resolving conflicts

Conflicts here are usually *equivalent* changes -- the same fix having reached
both branches by different routes. Resolve every conflict to the exact upstream
post-merge content. When in doubt:

```sh
git show <upstream-sha>:<path>
```

Do not blend the two sides into something that exists on neither branch.

## Verification

The resulting branch must satisfy both of these.

1. It merges into `ornl-next` cleanly.
2. It merges into `main` cleanly and introduces nothing that is not already in
   `main`.

Check the second in a throwaway worktree so the working checkout is untouched:

```sh
git worktree add ../verify-ornl HEAD
cd ../verify-ornl
git merge <remote>/main
git diff --name-only <remote>/main   # must print nothing
cd -
git worktree remove ../verify-ornl
```

An empty `git diff --name-only upstream/main` is the pass condition. Always
remove the worktree, including after a failure.

## Reference

`reference/outstanding-commits.md` records the last computed state: baseline
release, both branch tips, and any outstanding commits. It is generated output --
read it for context, regenerate it rather than editing it, and distrust it if
its date is old.

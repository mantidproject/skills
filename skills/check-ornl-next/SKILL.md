---
name: check-ornl-next
description: Find and cherry-pick build, CI, and configuration commits from upstream/main onto an ornl-next branch of the Mantid repository. Use when asked to check for ornl-next commits, sync ornl-next with main, reconcile ORNL branch build configuration, or verify that an ornl-next branch still merges cleanly into main.
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

Out of scope: ordinary science-code divergence. `main` is routinely ahead of
`ornl-next` by dozens of source files; that is expected and is not this skill's
concern.

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

1. Fetch first. Every check below is meaningless against stale refs.

   ```sh
   git fetch upstream
   ```

2. Ask what differs.

   ```sh
   "$SKILL"/scripts/check-paths.sh
   ```

   Exit status 0 means in sync and **you are done** -- report that and stop.
   Exit status 1 lists the configuration files that `main` has and `ornl-next`
   does not.

   Both refs are overridable: `--main`, `--ornl`.

3. Only if step 2 reported differences, find the commits responsible.

   ```sh
   "$SKILL"/scripts/check-paths.sh --log
   ```

   This lists commits on `main` touching the configuration paths since the last
   full release, oldest first, already in topological order.

4. Cherry-pick them in the order listed, resolving conflicts as below.

5. Verify (next section). Then regenerate the reference table:

   ```sh
   "$SKILL"/scripts/regenerate-outstanding.sh
   ```

## Do not use ancestry to decide what is missing

`git merge-base --is-ancestor <sha> upstream/ornl-next` is **not** a reliable
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
git merge upstream/main
git diff --name-only upstream/main   # must print nothing
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

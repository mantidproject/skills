# Choosing the git remote

Remote naming is a local convention, so nothing in this skill assumes
`upstream`. `$SKILL` below is the skill directory, as set in `SKILL.md`.

## Resolution order

The scripts resolve the remote in this order:

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

## Checking a branch other than the default pair

`--main` and `--ornl` take complete refs and override the remote for that
branch, which is how you check a local or contributor branch:

```sh
"$SKILL"/scripts/check-paths.sh --ornl my-reconciliation-branch
```

All three options are accepted by both `scripts/check-paths.sh` and
`scripts/regenerate-outstanding.sh`.

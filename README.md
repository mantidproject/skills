# mantid-skills

Claude Code skills for working on the [Mantid](https://github.com/mantidproject/mantid)
repository.

## Skills

| skill | what it does |
|-------|--------------|
| [`check-ornl-next`](skills/check-ornl-next/) | Find and cherry-pick build/CI/configuration commits from `upstream/main` onto an `ornl-next` branch, then verify the branch still merges cleanly into `main`. |

## Installing

Skills are installed per checkout, into that checkout's `.claude/skills/`.

```sh
gh repo clone peterfpeterson/mantid-skills ~/code/mantid-skills
~/code/mantid-skills/install.sh ~/code/mantid
```

`install.sh` symlinks every skill by default, so a `git pull` in this repo
updates every checkout at once. Use `--copy` for a standalone copy instead, and
name skills explicitly to install only some of them:

```sh
~/code/mantid-skills/install.sh --copy ~/code/mantid check-ornl-next
```

Add `.claude/skills/` to your global gitignore, or leave the symlinks untracked --
Mantid does not gitignore `.claude/`, so take care not to commit them upstream.

Verify with `/skills` inside Claude Code in the target checkout.

## Adding a skill

One directory per skill under `skills/`, each containing a `SKILL.md` with
`name` and `description` frontmatter. Keep skills self-contained: reference
files with paths relative to the skill directory, and never hardcode a
particular checkout's location. `install.sh` picks up new directories with no
changes.

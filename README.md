# mantid-skills

Agent skills for working on the [Mantid](https://github.com/mantidproject/mantid)
repository. They follow the [Agent Skills](https://agentskills.io) convention, so
`gh skill` installs them into Claude Code and any other supported agent.

## Skills

| skill | what it does |
|-------|--------------|
| [`check-ornl-next`](skills/check-ornl-next/) | Find and cherry-pick build/CI/configuration commits from main onto an `ornl-next` branch, then verify the branch still merges cleanly into main. |

## Installing

From inside the checkout you want the skill available in:

```sh
cd ~/code/mantid
gh skill install peterfpeterson/mantid-skills check-ornl-next --agent claude-code
```

Omit the skill name to install everything in the repository. `gh skill` defaults
to project scope, placing the skill in the current repository's
`.claude/skills/`; pass `--scope user` to install into your home directory so it
is available in every checkout.

Mantid does not gitignore `.claude/`, so at project scope take care not to commit
the installed skill upstream.

Other useful commands:

```sh
gh skill list                                        # what is installed
gh skill preview peterfpeterson/mantid-skills check-ornl-next
gh skill update --all                                # pull newer versions
```

## Publishing

`gh skill install` resolves the latest release, so changes reach users when a
release is cut:

```sh
gh skill publish --dry-run     # validate against the spec
gh skill publish --tag v1.1.0
```

## Adding a skill

One directory per skill under `skills/`, each containing a `SKILL.md` whose
frontmatter carries `name` and `description`, with `name` matching the directory
name. Keep skills self-contained: resolve helper files relative to the skill
directory, and never hardcode a particular checkout's location or git remote
name. Validate with `gh skill publish --dry-run` before tagging.

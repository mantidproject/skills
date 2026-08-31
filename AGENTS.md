# Agent instructions for this repository

This repository publishes agent skills. Every skill here MUST conform to the
Agent Skills specification at <https://agentskills.io/specification>. Read it
before adding a skill or changing the shape of an existing one.

## Validate before you finish

```sh
gh skill publish --dry-run
```

This must exit 0. It checks the frontmatter and naming rules only, so it is a
floor, not proof the skill is correct -- test the scripts a skill ships as well.

## What the specification requires

A skill is a directory containing at minimum a `SKILL.md`, whose YAML
frontmatter is followed by Markdown instructions.

| field | required | constraint |
|-------|----------|------------|
| `name` | yes | 1-64 chars, lowercase `a-z0-9` and hyphens, no leading/trailing/consecutive hyphens, and it must equal the directory name |
| `description` | yes | 1-1024 chars, says both what the skill does and when to use it |
| `license` | no | a license name, or the name of a bundled license file |
| `compatibility` | no | max 500 chars; environment requirements. Most skills do not need it |
| `metadata` | no | string-to-string map for anything outside the spec |
| `allowed-tools` | no | space-separated string, not a list. Experimental |

No other top-level frontmatter fields. Install metadata (`metadata.github-*`)
belongs to the installer and must not be committed; `gh skill publish --fix`
strips it.

## Layout conventions

```
skills/<skill-name>/
├── SKILL.md          # required
├── scripts/          # executable code the agent runs
├── references/       # docs the agent reads on demand -- note the plural
└── assets/           # templates, images, data files
```

Reference bundled files by paths relative to the skill root (`scripts/foo.sh`,
`references/bar.md`), one level deep. Do not hardcode an install path such as
`.claude/skills/<name>`: the same skill is installed under several agents and at
either user or project scope.

## Write for progressive disclosure

An agent loads a skill in three stages: `name` and `description` at startup, the
whole `SKILL.md` body on activation, and files under `scripts/`, `references/`
and `assets/` only when something calls for them.

So keep `SKILL.md` under 500 lines and push detail into `references/`, leaving
behind enough for the common case plus a pointer saying when to read further.
Anything a script can own -- a path list, a resolution order -- belongs in the
script, with `SKILL.md` naming it as the single source of truth rather than
repeating it.

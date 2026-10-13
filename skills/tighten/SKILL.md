---
name: tighten
description: Comb through a diff and refactor it to cut unnecessary line count, comment/doc noise, and test bloat, without changing behaviour or coverage. Use when asked to tighten, trim, condense, or de-verbose changed code, to cut comments down to what matters, or to trim an overly verbose test suite. Distinct from /simplify, which hunts for reuse and efficiency in the logic itself; this is about economy of expression in code that already works.
license: MIT
---

# Tighten

Reduce a diff to what earns its place. Two axes: **lines** and **words**. Behaviour must not change.

## Scope

Default to the uncommitted working tree plus any commits on this branch that aren't on the main branch — the same target `/simplify` uses. If the user names a path, PR, or commit range, use that instead. Only touch lines the diff introduced or moved; surrounding code is out of scope unless the user says otherwise.

Read the whole of each changed file before cutting. Density judgements need the context the diff hunk doesn't show, and the file's existing comment style is the standard to match — a repo whose CI scripts carry heavy rationale comments should keep them.

## Cutting lines

Look for, in rough order of payoff:

- **Two mechanisms doing one job.** The highest-value find. When a belt-and-braces second guard exists, work out whether the first one alone actually holds — then delete the other. Do the arithmetic or run the case; don't assume. A near-dead guard is worse than none, because it usually degrades *silently* where the live one degrades loudly.
- **Helpers with one caller** that don't name a concept worth naming. Merge them.
- **Constants used once** whose name adds nothing the use site doesn't already say.
- **Ceremony the house style doesn't require here** — a split-out arg parser for a single positional, a wrapper that only forwards, a tuple unpacked and immediately repacked.
- **Structure sized for a problem you don't have** — a dataclass for a two-field return, an abstraction with one implementation.

Do not collapse something that carries real meaning: a named constant documenting an external limit, a helper that makes a subtle condition readable, an early return that flattens nesting. Fewer lines is not the goal; fewer *unnecessary* lines is.

## Cutting comments and docs

Keep a comment when it says something the code cannot:

- Quirks of an external system — an API's undocumented behaviour, a tool's odd output shape, a platform difference.
- Hard limits and where they come from.
- Why this way and not the obvious other way, especially where the obvious way looks better.
- Why something is deliberately absent, or must not be added.

Cut a comment when:

- It restates the line below it.
- It re-explains what the module docstring, the function name, or the type already says.
- It narrates obvious flags or standard idioms.
- It is a rationale that has migrated into the code's shape and no longer adds anything.

Docstrings: one line unless there is a genuine caveat. Module docstrings say what the thing is and the one or two facts a reader needs before touching it — not a rehearsal of every design decision. Resist repeating the same rationale in the module docstring, the function docstring, and an inline comment; pick the one place a reader will be when they need it.

## Cutting tests

Changed tests are in scope too, and a bloated suite costs more than bloated code — it is read on every failure and slows every run. Aim for a suite where each test earns its place:

- **Cases that differ only in data.** Fold them into one parametrised test; don't fold cases that assert genuinely different behaviour just because their bodies look alike.
- **Tests of the same path at two levels** — a unit test and an integration test asserting the identical thing. Keep the one that would catch the regression more directly.
- **Assertions on incidentals** — call counts, argument shapes, and mock internals that no caller depends on. They pin the implementation, not the contract, and break on every refactor.
- **Setup ceremony** — fixtures used once, elaborate builders for a two-field object, mocks for collaborators the test never exercises.
- **Tests of the framework or the language** rather than of this change.

Never cut a case that is the only one covering a branch, an error path, or a boundary — those are the tests that pay. Reducing the count is not the goal; a shorter suite that still fails when the behaviour breaks is. Check the coverage of what remains rather than assuming, and if a cut leaves a gap, say so instead of quietly narrowing what's tested.

## Verify

Behaviour preservation is the whole contract, so prove it:

1. Run whatever the project already has — tests, linters, formatters, pre-commit. Match the project's runner (`pixi run`, `npm`, a venv) rather than a bare global one.
2. Re-run any ad-hoc checks used when the code was written, especially edge and pathological cases. If a guard was deleted, construct the worst case it was meant to catch and show the remaining guard holds.
3. Never report a lint or test as passing without having run it.

## Report

Lead with what actually changed in substance, not the trimming:

- Any **behavioural or structural** change, and why it's safe — most importantly any guard removed, with the evidence it was redundant.
- What was merged or collapsed, in a line or two.
- Any **test case removed or merged**, and what still covers the behaviour it asserted. Flag any coverage the cut genuinely loses.
- What was **kept** and why, where a reader might expect it to have gone. This is what shows the cut was considered rather than mechanical.
- Net line delta.
- Any judgement call worth a second opinion, stated as such.

Keep the report as tight as the code. A skill about economy that files a verbose report has failed its own test.

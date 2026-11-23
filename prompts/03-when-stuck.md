# Prompt 03 — When something goes wrong

## A check keeps failing after 3 fix rounds

```
Stop fixing. Explain in plain words: what fails, the exact error, what you tried,
and the 2 most likely root causes. Do not change files until I answer.
```

## The step went in a bad direction

```bash
git reset --hard        # back to the last commit
git clean -fd           # remove new untracked files (careful)
```
Then in Claude Code: `/clear`, then `/next-step SNN` again. Add a line to
`docs/PROGRESS.md` notes describing what to avoid.

## Claude wants to change the plan or the stack

```
Write an ADR proposal in docs/adr/ (use 000-template.md) with the problem, options,
and your recommendation. Do not implement it. I will decide.
```

## A business rule is missing

Add it to `docs/04-business-logic.md` or answer it in `docs/11-open-decisions.md`
yourself, then tell Claude: "Docs updated: <what changed>. Continue SNN."

## Context feels confused (repeats work, forgets rules)

`/clear`, then:
```
Read CLAUDE.md and docs/PROGRESS.md. Tell me the current step and its status. Do nothing else.
```

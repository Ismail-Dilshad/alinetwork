---
description: Fix a problem in the current or a finished AliNetwork step
argument-hint: "<what is wrong>"
---

The human reports a problem: **$ARGUMENTS**

1. Read `docs/PROGRESS.md` and find the step this problem belongs to (ask if unclear).
2. Read that step in `docs/09-build-plan.md` and its report in `docs/reports/`.
3. Reproduce the problem first (failing test or command). Show me the reproduction.
4. Delegate the fix to the agent that owns the affected files (see `.claude/agents/`). Tell it: add a test that fails before the fix and passes after; stay in its folders.
5. Verify: `pnpm turbo run lint typecheck test build` + the step's done-when checks. If 🔒, run `security-reviewer`.
6. Append a "Fixes" section to the step report, and one line to PROGRESS.md notes.
7. Show the summary and suggested commit message `fix(<STEP>): …`, then STOP.

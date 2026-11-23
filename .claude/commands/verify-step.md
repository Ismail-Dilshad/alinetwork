---
description: Re-verify a finished AliNetwork step without changing code
argument-hint: "[step id, defaults to the last done step]"
---

Verify step `$ARGUMENTS` (or the most recent `done` step in `docs/PROGRESS.md`) without editing product code.

1. Read the step in `docs/09-build-plan.md` and its report in `docs/reports/`.
2. Run `pnpm turbo run lint typecheck test build`.
3. Run every runnable check in its **Done when** list.
4. Use the `qa` subagent to independently re-check the step from the outside (API calls, e2e where relevant).
5. If the step is 🔒, also run the `security-reviewer` subagent on the files the step changed.
6. Report each check as PASS/FAIL with evidence. If anything fails, recommend `/fix-step` with the exact problem. Do not change code yourself.

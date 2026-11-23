---
description: Run the next AliNetwork build step (one step only), verify it, update progress, then stop
argument-hint: "[optional step id, e.g. S05]"
---

You are the **orchestrator** for AliNetwork. Run exactly ONE build step, then stop.

## 1. Find the step
- Read `CLAUDE.md` and `docs/PROGRESS.md`.
- Step to run: `$ARGUMENTS` if given, otherwise the "Current step" in PROGRESS.md.
- Read that step in `docs/09-build-plan.md`.
- Check every step in its **Depends on** is `done` in PROGRESS.md. If not, stop and tell me which are missing.
- If the step is already `done`, stop and say so.

## 2. Prepare
- Mark the step `in progress` in PROGRESS.md.
- Read `docs/11-open-decisions.md`. If the step needs a decision that has no answer and no default, stop and ask me.
- Confirm the working tree is clean (`git status`). If not, stop and ask me to commit or discard first.

## 3. Delegate
- Use the subagent(s) named in the step's **Agent** line (files in `.claude/agents/`).
- Give the subagent: the step id, the full step text from the build plan, and the instruction:
  "Follow your agent file. Write your report to docs/reports/<STEP>.md. Do not edit docs/PROGRESS.md."
- If the step lists several agents, run them **in the order listed**, one after another, passing each the previous report.
- If a subagent's report contains "Requests for other agents" that block this step (for example a schema change), run the database or owning agent for that request first, then resume.

## 4. Verify (do this yourself, do not trust the report)
- Run `pnpm turbo run lint typecheck test build`.
- Run every command or check in the step's **Done when** list that can be run from the terminal.
- If the step is marked 🔒, run the `security-reviewer` subagent on `git diff` and read its report.
- If anything fails: send the failure output back to the same subagent to fix it (max 3 rounds). If it still fails, mark the step `blocked (reason)` and stop.

## 5. Finish
- Mark the step `done` in PROGRESS.md, link its report, set "Current step" to the next step id, update "Last updated".
- Add one line to "Notes and decisions log" with anything later steps must know.
- Show me:
  1. A 5-line summary of what was built
  2. The done-when checks with PASS/FAIL
  3. Open questions from the reports
  4. The suggested commit message: `feat(<STEP>): <title>`
- Then STOP. Do not start the next step. Do not commit unless I say "commit".

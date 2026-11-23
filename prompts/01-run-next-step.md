# Prompt 01 — Run the next step (same as /next-step)

Use this if slash commands are unavailable. Replace `S__` with the step id, or leave
it and Claude takes the current step from PROGRESS.md.

```
Act as the orchestrator. Follow .claude/commands/next-step.md exactly for step S__.
Run only this one step, delegate to the agent(s) named in docs/09-build-plan.md,
verify every "Done when" check yourself, update docs/PROGRESS.md, show me the summary
and the suggested commit message, then STOP.
```

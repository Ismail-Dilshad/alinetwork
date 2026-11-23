# Prompt 00 — First session (paste into Claude Code once)

```
You are the orchestrator for the AliNetwork project in this folder.

1. Read CLAUDE.md, START-HERE.md and every file in docs/ (00 to 11, PROGRESS.md, adr/).
2. Read every agent in .claude/agents/ and every command in .claude/commands/.
3. Do NOT write any code yet.
4. Reply with:
   a) a 10-line summary of what AliNetwork is and how we will build it,
   b) any contradictions or gaps you found between the docs (file + line),
   c) the open decisions in docs/11-open-decisions.md that steps S01–S10 depend on,
   d) the exact plan for S01: files you expect the architect agent to create.
5. Then stop and wait. I will fix any gaps, then run /next-step.
```

After this, use `/next-step` for every step (or paste `01-run-next-step.md` if slash
commands are not available).

# AliNetwork: start here

This kit gives Claude Code everything it needs to build AliNetwork step by step:
the specification (`docs/`), the rules (`CLAUDE.md`), 17 specialist agents
(`.claude/agents/`), slash commands that run one step at a time (`.claude/commands/`),
and the server setup (`infra/`).

## What's in the kit

```
START-HERE.md            ← you are here (for you, the human)
CLAUDE.md                ← rules Claude Code reads automatically every session
AGENTS.md                ← same rules, for other AI tools
docs/
  00-overview.md         what AliNetwork is, users, surfaces, scope
  01-structure.md        the full folder and file structure
  02-architecture.md     modules, events, offline POS, how it scales
  03-data-model.md       every table and column
  04-business-logic.md   prices, tax, discounts, stock, orders, payments, shifts, permissions
  05-api.md              API conventions and every endpoint
  06-design-system.md    brand, colours, type, components, RTL, per-app UX rules
  07-security.md         auth, permissions, payments, privacy
  08-infrastructure.md   domains, hosting, deploys, backups
  09-build-plan.md       36 ordered steps, each with agent, tasks and "done when"
  10-testing.md          test strategy and the definition of done
  11-open-decisions.md   business choices YOU must confirm (rounding, tax, loyalty…)
  PROGRESS.md            the tracker: which step is next (agents update it)
  adr/                   why each big decision was made
.claude/
  agents/                17 agents (architect, database, api-contract, …)
  commands/              /next-step  /verify-step  /fix-step  /status
prompts/                 the same flow as copy-paste prompts, plus a review checklist
infra/                   Docker, Caddy, PM2, deploy, backup, server setup
.github/workflows/       CI + deploy to staging/production
```

## Before you start (once)

1. Install: **Node 22 LTS**, **pnpm** (`corepack enable`), **Docker Desktop**, **Git**, **Claude Code**.
2. Read `docs/11-open-decisions.md` and answer what you can (edit the file).
   Anything unanswered uses the default listed there.
3. Create the project:
   ```bash
   mkdir alinetwork && cd alinetwork
   # unzip this kit here
   git init && git add -A && git commit -m "chore: AliNetwork starter kit"
   ```
4. Create an empty private GitHub repo and push.

## How to build (repeat for every step)

```bash
claude            # open Claude Code in the project folder
```

1. Type **`/next-step`**. Claude reads `docs/PROGRESS.md`, finds the next step in
   `docs/09-build-plan.md`, hands it to the right agent, then verifies it.
2. It **stops** after one step and shows you a summary.
3. You check it with `prompts/02-review-checklist.md` (5 minutes).
4. If good: `git add -A && git commit -m "feat(S01): …"` (Claude can do this when you say "commit").
5. If something is wrong: type **`/fix-step`** and describe the problem.
6. Type **`/status`** any time to see where you are.
7. Repeat `/next-step`.

## Rules that keep it mistake-free

- **One step at a time.** Never ask for "build everything". The plan is ordered so
  each step stands on finished, tested work.
- **Never skip verification.** A step is done only when its "done when" checks pass.
- **Commit after every step.** If a step goes wrong, `git reset --hard` to the last
  commit and run it again.
- **Start a fresh Claude Code session** (`/clear`) every few steps to keep context clean.
  Everything it needs is in the files, not in chat memory.
- **Answer questions in `docs/11-open-decisions.md`** when an agent asks; don't guess.
- **Payments, permissions, migrations and infra** always get your review before merge.

## Where the full blueprint lives

The original planning document (AliNetwork — Product & Architecture Blueprint) is the
source for everything here. These files are the build-ready version of it.

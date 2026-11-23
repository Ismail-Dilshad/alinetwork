# Prompt 02 — Your 5-minute review after each step

Do this before typing "commit". If any answer is "no", run `/fix-step <problem>`.

## Always

- [ ] The summary says every **Done when** check is PASS (not "should pass")
- [ ] `docs/reports/SNN.md` exists and has no unanswered "Open questions" you care about
- [ ] `git status` shows changes only in folders this step's agent owns (+ docs/PROGRESS.md, docs/reports/)
- [ ] No files like `.env`, keys, or passwords in the changes (`git diff --stat`, look for `.env`)
- [ ] "Dependencies added" in the report all make sense

## If the step has a UI

- [ ] Run it (`pnpm dev`), open the screen, switch Arabic ↔ English: layout mirrors correctly
- [ ] Try one thing a lower role should not be able to do

## If the step is 🔒 (auth, payments, migrations, infra)

- [ ] `docs/reports/security-SNN.md` has no open critical/high findings
- [ ] Migrations: read the SQL file briefly; nothing drops or renames existing data

## Then

```bash
git add -A
git commit -m "feat(SNN): <title from the summary>"
git push
```

Every 3–4 steps: type `/clear` (fresh session) before the next `/next-step`.

# tvs-sqlscript — Agent notes (ZelosHR)

When changing **`human_resource`** / **`zeloshr`** schema for [ZelosHR.Api](../ZelosHR):

## Branch policy

**Work on `dev` only** — checkout, commit, and open PRs against **`dev`**. Same rule for **ZelosHR.Api** (`../ZelosHR`).

```bash
git checkout dev && git pull
cd ../ZelosHR && git checkout dev && git pull
```

| Branch | Use |
|--------|-----|
| **`dev`** | Default for ZelosHR sprints; auto-deploys to **`saas-dev`** Postgres |
| **`main`** / **`master`** | Production release path — **not** for sprint DDL or agent work |

### Never apply migrations from `master` / `main` during sprint work

- **All EF migrations** for ZelosHR: commit on **`dev`**, merge to **`dev`**, let **Database deploy (branch push)** apply to **`saas-dev`**.
- **Do not** push migration commits to `master`/`main` to fix dev schema.
- **Do not** run manual **Database (EF Core dispatch)** `deploy` against **`saas-dev`** expecting `master` checkout — the dispatch workflow **checks out `dev`** when `scope=saas` + `environment=dev`.
- Agents: never `git checkout master` / `main` in either repo unless the user explicitly requests a production release.

Pair with **ZelosHR.Api** on its **`dev`** branch. Merge **tvs-sqlscript `dev` first**, wait for schema deploy, then merge ZelosHR **`dev`**.

Full workflow (migrations, seeds, compose verify): see [ZelosHR/AGENTS.md](../ZelosHR/AGENTS.md).

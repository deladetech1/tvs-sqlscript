# tvs-sqlscript — Agent notes (ZelosHR)

When changing **`human_resource`** / **`zeloshr`** schema for [ZelosHR.Api](../ZelosHR):

## Branch policy

**Work on `dev` only** — checkout, commit, and open PRs against **`dev`**.

```bash
git checkout dev && git pull
```

| Branch | Use |
|--------|-----|
| **`dev`** | Default for ZelosHR sprints; auto-deploys to **`saas-dev`** |
| **`main`** | Production deploy — not the default sprint branch |

Pair with **ZelosHR.Api** on its **`dev`** branch. Merge **tvs-sqlscript `dev` first**, wait for schema deploy, then merge ZelosHR.

Full workflow (migrations, seeds, compose verify): see [ZelosHR/AGENTS.md](../ZelosHR/AGENTS.md).

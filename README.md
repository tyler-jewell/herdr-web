# herdr-web

Static **HTML / CSS / JS** control surface for [Herdr](https://herdr.dev).  
**Integrations** is the real implementation; other nav items are UX skeleton.

Public product: **`github.com/tyler-jewell/herdr-web`**.  
Works with **any** Herdr install on your PATH. Integration targets come from **live** CLI discovery — never a frozen list in this repo.

## Prerequisites (outside the two steps)

- [Herdr](https://herdr.dev) installed so `herdr` is on your `PATH`
- Python 3 (stdlib only — used as a tiny local process bridge)

**If you maintain or publish this repo (maintainers only):** run **`gh auth login` first** (manual browser OAuth), ideally before any day-0 or publish automation. End users only need `git clone` + `./scripts/serve.sh` for a local instance.

## Stand up in **2 steps**

```bash
# 1) Get the code
git clone https://github.com/tyler-jewell/herdr-web.git && cd herdr-web

# 2) Serve (bridge + static UI)
./scripts/serve.sh
```

Open **http://127.0.0.1:8765/** and click **Refresh status**.  
That runs real `herdr integration status` via the local bridge.

Optional: `HERDR_WEB_PORT=9000 ./scripts/serve.sh`

## What it does

| Action | Pure Herdr primitive |
|--------|----------------------|
| Refresh | `herdr integration status` |
| Outdated only | `herdr integration status --outdated-only` |
| Install / Update | `herdr integration install <target>` |
| Uninstall | `herdr integration uninstall <target>` |

`<target>` names are discovered live from status / `install --help`.  
The bridge only subprocesses validated `herdr integration …` argv — no install reimplementation.

## Layout

```
herdr-web/
  index.html
  css/  js/
  scripts/serve.sh      # step 2
  scripts/bridge.py     # POST /api/herdr → herdr only
  test/run.sh
  hosts/.gitkeep        # hosts registry is NOT this product
```

## Hosts / multi-machine setup

**Out of scope** for this repo. See the [tyler-jewell](https://github.com/tyler-jewell/tyler-jewell) methodology umbrella (`hosts/` registry, agent-kit). This repo ships only `hosts/.gitkeep` as a placeholder.

## Tests

```bash
./test/run.sh
```

## Offline

Without the bridge, use **Copy cmd** on a row — it copies the exact `herdr integration …` string for your terminal.

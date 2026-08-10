# herdr-web

**Isolatable Herdr plugin product** — Integrations UI + compliance evals.  
Runs against a normal Herdr install **without** the tyler-jewell umbrella or home admin tree.

Public: **https://github.com/tyler-jewell/herdr-web**  
Methodology (consume/contribute): **https://github.com/tyler-jewell/tyler-jewell**

## Prerequisites

- [Herdr](https://herdr.dev) on `PATH` (`herdr` ≥ 0.8)
- Python 3 (stdlib bridge)
- **Maintainers:** `gh auth login` before publish

## Stand up in 2 steps (isolation)

```bash
git clone https://github.com/tyler-jewell/herdr-web.git && cd herdr-web
./scripts/serve.sh
```

Open **http://127.0.0.1:8765/** — Integrations via pure `herdr integration …`.  
**Hot-reload is on by default:** edit `css/`, `js/`, or `index.html` and the browser picks up changes without a manual refresh (polls `/__hmr`). Disable with `HERDR_WEB_HOT_RELOAD=0`.

## Herdr plugin (side-by-side + real browser)

```bash
cd /path/to/herdr-web
herdr plugin link .
herdr plugin list
herdr plugin action list --plugin tyler-jewell.herdr-web
herdr plugin action invoke tyler-jewell.herdr-web.evals-list
# Side-by-side pane (inside a Herdr session) — opens a *real browser*:
herdr plugin pane open --plugin tyler-jewell.herdr-web --entrypoint integrations
```

The `integrations` pane starts the bridge, then opens the UI in an **actual browser**:

1. **Preferred:** in-pane Chromium via [`official.browser`](https://github.com/ogulcancelik/herdr-browser)  
   (`herdr plugin install ogulcancelik/herdr-browser --yes`, plus Bun, Chrome/Chromium, and `[experimental] kitty_graphics = true` in Herdr config)
2. **Fallback:** system browser (`open` on macOS / `xdg-open` on Linux) at `http://127.0.0.1:8765/`

Manifest: `herdr-plugin.toml` (id, name, version, min_herdr_version, actions, panes).

| Action | Purpose |
|--------|---------|
| `serve` | Long-lived UI + bridge (hot-reload) only |
| `evals-list` | List compliance evals (≤10) |
| `evals-run` | Run compliance evals |
| pane `integrations` | Bridge + open real browser to the UI |

## What agents may do

| Agent role | May | Must not |
|------------|-----|----------|
| **herdr-web agents** | Edit UI/plugin scripts, evals, run serve/link | Commit secrets; hardcode integration target lists; reimplement herdr install |
| **Methodology agents** (tyler-jewell) | Point kit/docs at this product; layer evals | Own a second parallel UI product |

See [AGENTS.md](AGENTS.md).

## Evals (compliance, ≤10)

```bash
./scripts/evals.sh list
./scripts/evals.sh run
```

Optional multi-layer (methodology checkout present):

```bash
export HERDR_EVALS_LAYERS="$HOME/github-repos/tyler-jewell/evals:$HOME/github-repos/tyler-jewell/agent-kit/evals"
./scripts/evals.sh run
```

## Tests

```bash
./test/run.sh
python3 ./test/test_hmr.py
```

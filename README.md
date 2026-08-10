# herdr-web

**Isolatable Herdr plugin product** — Integrations UI + compliance evals.  
Runs against a normal Herdr install **without** the tyler-jewell umbrella or home admin tree.

Public: **https://github.com/tyler-jewell/herdr-web**  
Methodology (consume/contribute): **https://github.com/tyler-jewell/tyler-jewell**

## Prerequisites

- [Herdr](https://herdr.dev) on `PATH` (`herdr` ≥ 0.8)
- [Go](https://go.dev) on `PATH` (bridge is Go — no Python). Prefer host home-manager packages: `go` + `gopls`.
- **Maintainers:** `gh auth login` before publish; public deploys use **Vercel** (`vercel login` once on the host).

## Stand up in 2 steps (isolation)

```bash
git clone https://github.com/tyler-jewell/herdr-web.git && cd herdr-web
./scripts/serve.sh
```

Serve prints the live **`url:`** (from **`ports.toml`** claim, overridable via `HERDR_WEB_PORT` / `HERDR_WEB_HOST` — do **not** hardcode ports in docs). Integrations use pure `herdr integration …`.  
**Hot-reload is on by default:** edit `css/`, `js/`, or `index.html` and the browser picks up changes without a manual refresh (polls `/__hmr`). Disable with `HERDR_WEB_HOT_RELOAD=0`.

## Herdr plugin (side-by-side)

```bash
cd /path/to/herdr-web
herdr plugin link .
herdr plugin list
herdr plugin action list --plugin tyler-jewell.herdr-web
herdr plugin action invoke tyler-jewell.herdr-web.evals-list
# Side-by-side pane (inside a Herdr session) — serves the UI bridge:
herdr plugin pane open --plugin tyler-jewell.herdr-web --entrypoint integrations
```

Use the **`url:`** line from `serve` / pane output (claimed in [`ports.toml`](ports.toml)).

Manifest: `herdr-plugin.toml` (id, name, version, min_herdr_version, actions, panes).

| Action | Purpose |
|--------|---------|
| `serve` | Long-lived UI + bridge (hot-reload) |
| `evals-list` | List compliance evals (≤10) |
| `evals-run` | Run compliance evals |
| pane `integrations` | Split pane running serve |

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
go test ./cmd/bridge/
```

## Stack (umbrella sacred rules)

| Layer | Choice |
|-------|--------|
| Backend / bridge | **Go** only (`cmd/bridge`) |
| Frontend | Vanilla **HTML / CSS / JS** |
| UI package | **shadcn** only (when a package is needed) |
| PWA bar | Score against https://web.dev/learn/pwa (Lighthouse PWA) |
| Auth | **WebAuthn passkeys** when auth is added |
| Public host | **Vercel** |

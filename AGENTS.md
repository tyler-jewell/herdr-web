# herdr-web — agent notes (isolatable Herdr plugin)

## Scope

This is the **only** stack product meant to be setup and run **in isolation**.  
Core methodology/system **consumes and contributes** here (docs, evals pointers, agent workflows) — do not fork a second Integrations UI.

## Access controls

| Who | Write | Read/run |
|-----|-------|----------|
| Agents working in this repo | UI, plugin manifest, serve/bridge, `evals/` | All |
| Agents in tyler-jewell only | Must not force-push this repo without human ask; may open PRs / document consumption | Clone + plugin link |
| Humans | Link/install plugins, `gh` publish after `gh auth login` | All |

**Never:** secrets, auth dumps, private absolute home paths as install requirements.

## Rules

0. **AXI** — https://axi.md (tyler-jewell sacred rule 11). Content-first CLIs, exit 2 on unknown flags, non-interactive.
1. Pure Herdr primitives only for integrations: `status|install|uninstall`.
2. Never hardcode integration target inventories — live discovery only.
3. **Hot-reload default** for isolatable serve (`HERDR_WEB_HOT_RELOAD=1`).
4. Valid `herdr-plugin.toml`; use `HERDR_BIN_PATH` when under Herdr.
5. Compliance evals in `evals/` (≤10) — do/don't policy, not challenges.
6. Dual-write AGENTS/README when layout/commands change.
7. **LSP (tyler-jewell rule 13)** — Languages in active use and public LSPs:
   | Language | Public LSP (standalone — **no VS Code IDE required**) | Project setup |
   |----------|--------------------------------------------------------|---------------|
   | JavaScript | [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server) | `jsconfig.json` (`checkJs`, strict) |
   | Python | [Pyright](https://github.com/microsoft/pyright) | `pyrightconfig.json` (strict) |
   | Bash | [bash-language-server](https://github.com/bash-lsp/bash-language-server) | declare here; no `.shellcheckrc` that disables all rules |
   | HTML | [vscode-langservers-extracted](https://github.com/hrsh7th/vscode-langservers-extracted) → `vscode-html-language-server` (npm package; **not** the VS Code app) | `index.html` |
   | CSS | [vscode-langservers-extracted](https://github.com/hrsh7th/vscode-langservers-extracted) → `vscode-css-language-server` (npm package; **not** the VS Code app) | `css/**/*.css` |

   Install HTML/CSS servers without VS Code, e.g. `npm i -g vscode-langservers-extracted` (or project/devDependency + `npx`). Do **not** require downloading Visual Studio Code.

   Agents **MUST** use LSP tools when coding; **must not** add `eslint-disable` / `# noqa` / `@ts-ignore` / blanket shellcheck disables as the fix; resolve root cause.

## Browser pane

`scripts/plugin-pane.sh` (manifest entrypoint `integrations`) must open a **real browser**, not only print serve logs:

1. Prefer `official.browser` pane with `HERDR_BROWSER_INITIAL_URL` (page to open — not host config)
2. Else system browser (`open` / `xdg-open`) to `http://$HOST:$PORT/`

**Config-first:** Chrome/Bun/PATH and Herdr graphics live in **version-controlled host config** (`~/system` home-manager, `~/.config/herdr/config.toml`). Do **not** teach or inject ad-hoc `export HERDR_BROWSER_CHROME=…` workarounds in this product.

Do not regress to terminal-only serve for the integrations pane.

## Verify

```bash
herdr plugin link .
herdr plugin list --json
./scripts/evals.sh run
./scripts/serve.sh
python3 ./test/test_hmr.py
# Inside Herdr: must open a real browser surface
herdr plugin pane open --plugin tyler-jewell.herdr-web --entrypoint integrations
```

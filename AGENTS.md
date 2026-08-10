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
   | Language | Public LSP | Project setup |
   |----------|------------|---------------|
   | JavaScript | typescript-language-server | `jsconfig.json` (`checkJs`, strict) |
   | Python | Pyright | `pyrightconfig.json` (strict) |
   | Bash | bash-language-server | declare here; no `.shellcheckrc` that disables all rules |
   Agents **MUST** use LSP tools when coding; **must not** add `eslint-disable` / `# noqa` / `@ts-ignore` / blanket shellcheck disables as the fix; resolve root cause.

## Verify

```bash
herdr plugin link .
herdr plugin list --json
./scripts/evals.sh run
./scripts/serve.sh
python3 ./test/test_hmr.py
```

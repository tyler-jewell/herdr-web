# herdr-web — agent notes

Standalone public product for a local Herdr Integrations UI.

## Scope

- Static HTML/CSS/JS + thin bridge that only runs pure `herdr integration …` commands.
- **Integrations** surface is real; stream/workspaces/agents/panes are stubs.
- **Not** a hosts registry or machine bootstrap kit (`hosts/` is empty on purpose).

## Rules

1. Prefer pure Herdr CLI primitives only:
   - `herdr integration status [--outdated-only]`
   - `herdr integration install <target>`
   - `herdr integration uninstall <target>`
2. Never hardcode integration target inventories — live discovery only (status / install --help).
3. Never reimplement Herdr hook install paths or vendor curl installers.
4. Bridge may only subprocess validated `herdr integration …` argv.
5. Dual-write `AGENTS.md` + `README.md` when layout/commands change.
6. No secrets in git. Paths in docs stay portable (`./scripts/…`, relative clone root).

## Verify

```bash
./test/run.sh
./scripts/serve.sh
herdr integration status
```

# herdr-web evals

Compliance evals for the isolatable Herdr Web plugin (≤10).

## Rules

1. Evals assert **do / don't** policy from AGENTS — not adversarial challenges.
2. Max **10** scripts matching `NN-name.sh`.
3. Run via `scripts/evals.sh list|run` or `herdr plugin action invoke tyler-jewell.herdr-web.evals-run`.
4. Dual-write README when adding evals.
5. **LSP (rule 13):** Bash for eval scripts; parent tree owns JS/Python LSP (`jsconfig.json`, `pyrightconfig.json`).

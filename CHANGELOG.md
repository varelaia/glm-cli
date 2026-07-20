# Changelog

## 2026-07-20

### Fixed
- **Silent misrouting via `settings.json`:** a literal `"model"` id in the host's
  `~/.claude/settings.json` (written by `/model` in your regular `claude`) bypassed
  the `ANTHROPIC_DEFAULT_*_MODEL` aliases, and the glm session silently sent that
  non-GLM id to Z.ai — which may serve a *different model with no error* (verified
  live 2026-07-20; the failure used to be a loud HTTP 400, it no longer is).
  `bin/glm` and `bin/glmf` now pin `ANTHROPIC_MODEL` explicitly, which wins over
  `settings.json`, closing the hole at runtime instead of relying on the
  install-time warning.
- **Stale warning text in `install.sh`:** the settings.json check claimed glm
  "will fail with 'Unknown Model' (HTTP 400)" — no longer true; the warning is now
  informational and describes the actual (silent) behavior.

### Added
- **`GLM_MODEL` override:** pick a different GLM model for one run without
  editing anything: `GLM_MODEL=glm-4.7 glm`. A dedicated variable (instead of
  respecting an inherited `ANTHROPIC_MODEL`) so that env pollution from other
  tooling can never misroute a glm session.

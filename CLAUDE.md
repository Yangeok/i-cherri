# CLAUDE.md

## Build & Workflow

Always report which components changed and the required `make` command:
- If Go code changes: `make go` (or `make run` to restart)
- If `.cherri` changes: `make shortcut`
- If both change: `make all`

All commits must follow Commitizen style (English).
Every commit automatically triggers full builds via pre-commit hook.

# CLAUDE.md

## Build & Workflow

Always report which components changed and the required `make` command:
- If Go code changes: `make go` (or `make run` to restart)
- If `.cherri` changes: `make shortcut`
- If both change: `make all`

All commits must follow Commitizen style (English).
Every commit automatically triggers full builds via pre-commit hook.

## GitHub Release

- Bump patch version only unless user explicitly says major/minor. (`v0.1.0` → `v0.1.1`)
- Title: version tag only. (`v0.1.1`)
- Notes: 주요 기능 + 릴리즈 파일 표 only. No intro sentence, no install instructions.
- Assets: `iPhone Daily Backup.shortcut`, `cherri-sync-darwin-arm64`, `cherri-sync-darwin-x86_64`, `organize-by-month-darwin-arm64`, `organize-by-month-darwin-x86_64`

# Contributing to i-cherri

## Prerequisites

- Go 1.20+
- [Cherri CLI](https://cherrilang.org/language/)
- Make

## Development Setup

```bash
git clone https://github.com/Yangeok/i-cherri.git
cd i-cherri
make all
```

## Project Structure

| Path | Description |
| --- | --- |
| `main.go` | Go HTTP server + SQLite indexing engine |
| `cmd/init/` | One-time photo organizer CLI (`./dist/init`) |
| `iphone_daily_backup.cherri` | iOS Shortcut source (Cherri DSL) |
| `Makefile` | Build automation |

## Build Commands

| Command | Description |
| --- | --- |
| `make go` | Build Go server binary |
| `make init` | Build init CLI |
| `make shortcut` | Compile and sign iOS Shortcut |
| `make all` | Build everything |
| `make run` | Rebuild and restart server |
| `make reindex` | Re-index backup directory |

## Commit Style

All commits must follow [Commitizen](https://commitizen-tools.github.io/commitizen/) conventional commit format in **English**.

```
feat: add batch check API
fix: correct SHA-256 deduplication for HEIC files
docs: update README with new server flags
chore: bump Go version in go.mod
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`

## Pull Requests

1. Fork the repository and create a branch from `main`
2. Make your changes with appropriate tests
3. Ensure `make all` succeeds without errors
4. Open a PR with a clear description of the change and motivation

## Reporting Issues

Use GitHub Issues. For security vulnerabilities, see [SECURITY.md](SECURITY.md).

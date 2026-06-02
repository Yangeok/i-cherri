# Contributing to i-cherri

## Prerequisites

- Xcode 16+
- Make
- A connected iPhone if you want to test device deployment

## Development Setup

```bash
git clone https://github.com/Yangeok/i-cherri.git
cd i-cherri
make mac-app
make ios-app
```

## Project Structure

| Path | Description |
| --- | --- |
| `apps/ios/` | iPhone backup client |
| `apps/mac/` | macOS receiver app |
| `packages/ICherriProtocol/` | Shared protocol and DTO package |
| `packages/ICherriCore/` | Core backup logic |
| `packages/ICherriDesignSystem/` | Shared UI package |
| `Makefile` | Build and run commands |

## Build Commands

| Command | Description |
| --- | --- |
| `make mac-app` | Build the macOS receiver app |
| `make mac-run` | Build and launch the macOS receiver app |
| `make mac-dev` | Build, launch, and stream macOS logs |
| `make ios-app` | Build the iPhone app |
| `make ios-run` | Build, install, and launch on a connected iPhone |
| `make ios-dev` | Build, launch, and attach iPhone console output |

## Commit Style

All commits must follow [Commitizen](https://commitizen-tools.github.io/commitizen/) conventional commit format in English.

## Pull Requests

1. Create a branch from `main`
2. Make the change with tests or build verification
3. Ensure the relevant app builds succeed
4. Open a PR with a clear description of the change and motivation

## Reporting Issues

Use GitHub Issues. For security vulnerabilities, see [SECURITY.md](SECURITY.md).

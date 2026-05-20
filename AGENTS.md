# AGENTS.md

## Cherri Shortcut Rules

- Cherri/CLI는 로컬에 설치되어 있다고 가정한다.
- Cherri 구문, 액션, CLI 옵션은 작업 전 공식 문서를 확인한다: [cherrilang docs](https://cherrilang.org/language/)
- `.cherri` 수정 시 소스 상단 주석과 단축어 내부 상단 `Comment` 액션의 수정일시를 현재 시각으로 갱신한다.
- 수정 후 `--skip-sign`으로 컴파일 확인은 가능하나, **최종 산출물은 반드시 signed `.shortcut`으로 빌드해야 하며 unsigned 파일은 절대로 생성하거나 커밋하지 않는다.**
- 사용자에게 전달하거나 저장소에 포함하는 파일은 오직 signed `.shortcut`만 허용한다.

## Git & Workflow Rules

- **Pre-commit Hook**: 모든 커밋 전 Go 빌드와 Cherri 컴파일 성공 여부를 자동으로 검증한다.
- **Commit Convention**: 커밋 메시지는 Commitizen (cz) 스타일의 영문을 사용한다. (예: `feat: add backup feature`, `fix: resolve crash in sync`)
- **Finalization**: 작업이 완료되면 반드시 커밋을 수행하여 상태를 보존한다.

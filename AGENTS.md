# AGENTS.md

## Cherri Shortcut Rules

- Cherri/CLI는 로컬에 설치되어 있다고 가정한다.
- Cherri 구문, 액션, CLI 옵션은 작업 전 공식 문서를 확인한다: [cherrilang docs](https://cherrilang.org/language/)
- `.cherri` 수정 시 소스 상단 주석과 단축어 내부 상단 `Comment` 액션의 수정일시를 현재 시각으로 갱신한다.
- 수정 후 `--skip-sign`으로 컴파일 확인하고, 최종 산출물은 signed `.shortcut`으로 빌드한다.
- 사용자에게 전달하는 파일은 unsigned가 아닌 signed `.shortcut`만 사용한다.
- **커밋 컨벤션**: 커밋 메시지는 Commitizen (cz) 스타일의 영문을 사용한다. (예: `feat: add backup feature`, `fix: resolve crash in sync`)
- **작업 완료 후**: 모든 작업이 완료되면 반드시 커밋을 수행한다.

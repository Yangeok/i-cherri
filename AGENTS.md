# AGENTS.md

## Runtime Rules
- **타겟**: Swift 네이티브 iOS 및 macOS 앱 기준 작업 (Go, Shortcut 등 과거 산출물은 제거 대상).

## Git & Workflow Rules
- **검증**: 커밋 전 macOS/iOS 빌드 검증 및 관련 유닛/통합 테스트 패스 필수.
- **커밋**: Commitizen 스타일 영문 메시지 사용 (예: `feat: ...`, `fix: ...`). 완료 후 커밋 보존.
- **안내**: 답변 마무리 시 변경 컴포넌트 요약 및 실행할 `make` 명령어 1개 안내.

## Release Rules
- **버전**: 특별 지시가 없는 한 패치 버전(`v0.1.0` -> `v0.1.1`)만 올리고 버전 태그로만 릴리즈.

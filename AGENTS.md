# AGENTS.md

## Runtime Rules

- iCherri는 현재 **Swift 네이티브 iPhone 앱 + Swift 네이티브 macOS 앱** 기준으로 작업한다.
- 과거 Go 서버, Cherri shortcut, 실험용 reverse-engineering 산출물은 deprecated로 간주한다.
- deprecated 잔재를 건드릴 때는 부분 수정 대신 삭제 또는 현재 아키텍처 기준 치환을 우선한다.

## Git & Workflow Rules

- **Pre-commit Hook**: 모든 커밋 전 macOS/iOS 앱 빌드 성공 여부를 자동으로 검증한다.
- **Test Discipline**: 백업/세션/진행률/스캔처럼 상태 전이가 있는 로직을 수정하면 관련 unit/integration test를 함께 추가하거나 갱신하고, 작업 중 해당 테스트를 직접 실행해 깨지지 않는지 확인한다.
- **Commit Convention**: 커밋 메시지는 Commitizen (cz) 스타일의 영문을 사용한다. (예: `feat: add backup feature`, `fix: resolve crash in sync`)
- **Finalization**: 작업이 완료되면 반드시 커밋을 수행하여 상태를 보존한다. 답변 시 변경된 컴포넌트(macOS 앱, iOS 앱, shared package 등)와 실행해야 할 `make` 명령어를 짧게 안내한다.

## Inject / Rebuild Answer Rules

- 사용자가 "재빌드가 필요한가", "`Inject`로 충분한가", "`Ctrl+C` 후 다시 실행해야 하나"를 물으면 **이번 변경이 어느 범주인지 먼저 단정적으로 답한다.**
- 다음 범주는 **Inject만으로 충분할 수 있는 변경**으로 답한다: SwiftUI 뷰 레이아웃, 색/폰트/텍스트, 단순 화면 구성, `body` 내부 표현 변경, 프리뷰/스타일 수준 수정.
- 다음 범주는 **재빌드/재실행이 필요하다고 답한다**: 앱 시작 로직, DB migration, actor/service 상태, 업로드/네트워크/서버 핸들러, Notification wiring, 파일 시스템/삭제/정리 로직, 모델/스토리지 계층, 권한/설정/entitlement 변경, 빌드 산출물 자체 변경.
- `run`과 `dev` 차이도 함께 물으면 `run`은 재빌드+실행, `dev`는 재빌드+실행 후 로그/콘솔 연결이라고 짧게 답한다.
- 현재 작업이 어느 범주에 속하는지 명시하고, 필요하면 마지막 줄에 실행할 `make` 명령어를 하나만 제시한다. (예: `make mac-dev`, `make ios-dev`)

## Release Rules

- **버저닝**: 사용자가 메이저/마이너 올리라고 명시하기 전까지는 패치 버전만 올린다. (예: `v0.1.0` → `v0.1.1`)
- **릴리즈 타이틀**: 버전 태그만 쓴다. (예: `v0.1.1`)
- 릴리즈 노트와 에셋 설명은 현재 Swift 앱 기준으로 작성한다. deprecated Go/Shortcut 산출물은 포함하지 않는다.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan: [plan.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/plan.md)
<!-- SPECKIT END -->

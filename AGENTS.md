# AGENTS.md

## Cherri Shortcut Rules

- Cherri/CLI는 로컬에 설치되어 있다고 가정한다.
- Cherri 구문, 액션, CLI 옵션은 작업 전 공식 문서를 확인한다: [cherrilang docs](https://cherrilang.org/language/)
- `.cherri` 수정 시 소스 상단 주석과 단축어 내부 상단 `Comment` 액션의 수정일시를 **반드시 `date` 명령어로 확인한 현재 시스템 시각**으로 갱신한다. (임의의 시간을 입력하지 말 것)
- 수정 후 `--skip-sign`으로 컴파일 확인은 가능하나, **최종 산출물은 반드시 signed `.shortcut`으로 빌드해야 하며 unsigned 파일은 절대로 생성하거나 커밋하지 않는다.**
- 사용자에게 전달하거나 저장소에 포함하는 파일은 오직 signed `.shortcut`만 허용한다.

## Cherri rawAction: filter.photos with dynamic date (날짜 필터 + 출력 캡처)

iOS Shortcuts의 `is.workflow.actions.filter.photos` (Find Photos)를 Cherri `rawAction`으로 사용할 때 두 가지 제약이 있다.

**제약 1 — 출력 캡처 불가**

`@x = rawAction(...)` 할당은 식별자가 `is.workflow.actions.rawaction`으로 잘못 컴파일되어 iOS가 실행하지 않는다.  
`rawAction("is.workflow.actions.setvariable", {"WFVariableName": "x"})` 단독 사용도 WFInput이 없어 nil이 저장된다.

**해결**: filter.photos rawAction에 고정 UUID를 명시하고, setvariable rawAction에서 그 UUID를 WFInput으로 직접 참조한다.

```cherri
@allMedia: variable
rawAction("is.workflow.actions.filter.photos", {
    "UUID": "cafe0001-beef-dead-0000-123456789abc",
    "CustomOutputName": "FilteredMedia",
    "WFContentItemFilter": { ... },
    ...
})
rawAction("is.workflow.actions.setvariable", {
    "WFVariableName": "allMedia",
    "WFInput": {
        "Value": {
            "OutputName": "FilteredMedia",
            "OutputUUID": "cafe0001-beef-dead-0000-123456789abc",
            "Type": "ActionOutput"
        },
        "WFSerializationType": "WFTextTokenAttachment"
    }
})
```

**제약 2 — 중첩 dict 내 변수 참조**

rawAction 파라미터 최상위에서 `"${varName}"` → WFTextTokenAttachment 변환이 동작하지만, 중첩 dict 안에서는 동작하지 않는다.  
날짜 변수처럼 중첩 위치에 변수를 전달할 때는 WFTextTokenAttachment 구조를 직접 명시한다.

```cherri
// 잘못된 방법 (중첩 dict에서 미동작)
"Date": "${startDate}"

// 올바른 방법
"Date": {
    "Value": {"Type": "Variable", "VariableName": "startDate"},
    "WFSerializationType": "WFTextTokenAttachment"
}
```

---

## Git & Workflow Rules

- **Pre-commit Hook**: 모든 커밋 전 Go 빌드와 Cherri 컴파일 성공 여부를 자동으로 검증한다.
- **Commit Convention**: 커밋 메시지는 Commitizen (cz) 스타일의 영문을 사용한다. (예: `feat: add backup feature`, `fix: resolve crash in sync`)
- **Finalization**: 작업이 완료되면 반드시 커밋을 수행하여 상태를 보존한다. 답변 시 변경된 컴포넌트(Go 앱, 단축어 등)와 실행해야 할 `make` 명령어를 짧게 안내한다.

## Inject / Rebuild Answer Rules

- 사용자가 "재빌드가 필요한가", "`Inject`로 충분한가", "`Ctrl+C` 후 다시 실행해야 하나"를 물으면 **이번 변경이 어느 범주인지 먼저 단정적으로 답한다.**
- 다음 범주는 **Inject만으로 충분할 수 있는 변경**으로 답한다: SwiftUI 뷰 레이아웃, 색/폰트/텍스트, 단순 화면 구성, `body` 내부 표현 변경, 프리뷰/스타일 수준 수정.
- 다음 범주는 **재빌드/재실행이 필요하다고 답한다**: 앱 시작 로직, DB migration, actor/service 상태, 업로드/네트워크/서버 핸들러, Notification wiring, 파일 시스템/삭제/정리 로직, 모델/스토리지 계층, 권한/설정/entitlement 변경, 빌드 산출물 자체 변경.
- `run`과 `dev` 차이도 함께 물으면 `run`은 재빌드+실행, `dev`는 재빌드+실행 후 로그/콘솔 연결이라고 짧게 답한다.
- 현재 작업이 어느 범주에 속하는지 명시하고, 필요하면 마지막 줄에 실행할 `make` 명령어를 하나만 제시한다. (예: `make mac-dev`, `make ios-dev`, `make shortcut`)

## GitHub Release Rules

- **버저닝**: 사용자가 메이저/마이너 올리라고 명시하기 전까지는 패치 버전만 올린다. (예: `v0.1.0` → `v0.1.1`)
- **릴리즈 타이틀**: 버전 태그만 쓴다. (예: `v0.1.1`)
- **릴리즈 노트 템플릿** (주요 기능 + 릴리즈 파일 설명만):

```
## 주요 기능

- 기능 설명 1
- 기능 설명 2

## 릴리즈 파일

| 파일 | 설명 |
|---|---|
| `iPhone Daily Backup.shortcut` | 서명된 iOS 단축어 |
| `cherri-sync-darwin-arm64` | 백업 서버 (Apple Silicon) |
| `cherri-sync-darwin-x86_64` | 백업 서버 (Intel Mac) |
| `organize-by-month-darwin-arm64` | 연월 폴더 정리 CLI (Apple Silicon) |
| `organize-by-month-darwin-x86_64` | 연월 폴더 정리 CLI (Intel Mac) |
```

- **릴리즈 에셋**: `iPhone Daily Backup.shortcut`, `cherri-sync-darwin-arm64`, `cherri-sync-darwin-x86_64`, `organize-by-month-darwin-arm64`, `organize-by-month-darwin-x86_64`

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan: [plan.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/plan.md)
<!-- SPECKIT END -->

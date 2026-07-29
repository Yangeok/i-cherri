# Implementation Plan: iOS 화면 꺼짐 자동 백업

**Branch**: `002-background-auto-backup` | **Date**: 2026-06-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-background-auto-backup/spec.md`

## Summary

iOS 자동 백업을 `BGProcessingTask` 기반 백그라운드 실행, 영속 `run/job` 저장소, 기존 resumable 업로드 프로토콜 강화로 구현한다. iOS는 `이번 실행 대상 asset 집합`만 run으로 관리하고, macOS receiver는 idempotent session/commit/finalize 규약을 강화해 화면 꺼짐, 앱 재실행, receiver 일시 부재, receiver 변경 상황에서도 중복 저장 없이 재개 가능하게 만든다.

## Technical Context

**Language/Version**: Swift 5.9+ (`SWIFT_VERSION = 5.0` build setting), SwiftUI 앱 구조

**Primary Dependencies**: SwiftUI, Foundation, Photos.framework, BackgroundTasks.framework, URLSession, Network.framework/Bonjour, GRDB.swift(macOS), Inject(dev), `ICherriProtocol`, `ICherriCore`, `ICherriDesignSystem`

**Storage**: iOS `Application Support` JSON store + staged media temp files + `UserDefaults`/Keychain 참조, macOS GRDB(SQLite) + 로컬 파일 시스템 백업 루트

**Testing**: XCTest + Swift Testing, 상태 전이/재개/중복 방지 중심 단위 테스트, iOS/macOS 계약 회귀 테스트

**Target Platform**: iOS 16.0+, macOS 14.0+, 동일 LAN 환경의 Swift-native iPhone/macOS 앱

**Project Type**: 네이티브 iOS 앱 + 네이티브 macOS receiver 앱 + 공유 Swift 패키지

**Performance Goals**: 
- 자동 백업 run은 전체 라이브러리가 아닌 실제 처리 대상만 평가해 control-plane 부하를 줄인다
- 복구 대상 run의 95% 이상이 중복 업로드 없이 이어서 진행된다
- iOS staged temp 총량은 2GB 상한을 넘지 않는다

**Constraints**:
- Wi-Fi 켜짐 상태에서만 자동 백업 시작
- 배터리 20% 미만이면 자동 시작 금지
- 저전력 모드는 차단 조건 아님
- thermal state 과열 시 run 일시정지 후 재평가
- 같은 run 안 즉시 재시도 없음
- 실패 항목은 성공할 때까지 이후 run에서 재평가
- 미완료 run 기록은 7일 보존
- cross-Mac handoff 금지
- Photos 원본 수정/삭제 금지

**Scale/Scope**:
- 개인용 로컬 백업 제품
- 수만 개 라이브러리 자산, 단일 활성 receiver, 단일 활성 자동 백업 run 기준
- v1 범위는 로컬 Mac receiver 자동 백업만 포함

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md`는 아직 템플릿 placeholder 상태다. 따라서 현재 계획의 실질적 게이트는 저장소의 `AGENTS.md` 규칙을 기준으로 점검한다.

- `Swift-native 앱 기준 유지`: PASS  
  iOS/macOS 앱과 공유 패키지 경로만 확장한다. deprecated Go/Shortcut 경로는 범위 밖이다.
- `상태 전이 변경 시 테스트 동반`: PASS  
  자동 백업 run, asset, receiver session 상태 전이에 대해 iOS/macOS 테스트를 계획에 포함한다.
- `스토리지/업로드/세션 로직 변경은 재빌드 전제`: PASS  
  구현 범위가 오케스트레이션, 업로드, 영속 저장소, receiver contract를 포함하므로 재빌드 전제 설계와 맞다.
- `커밋/릴리즈 규칙`: PASS  
  본 단계는 설계 산출물 생성 단계이며, 구현 단계에서 Commitizen 스타일 커밋과 pre-commit 빌드 규칙을 따른다.

Phase 1 설계 후 재점검 결과도 동일하게 PASS다. 별도 정당화가 필요한 헌법 위반은 없다.

## Project Structure

### Documentation (this feature)

```text
specs/002-background-auto-backup/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── receiver-auto-backup.md
└── tasks.md              # /speckit-tasks 단계에서 생성
```

### Source Code (repository root)

```text
apps/
├── ios/
│   ├── Features/
│   │   └── Backup/
│   │       ├── BackupDashboardView.swift
│   │       └── (new) AutoBackupStatus surfaces
│   ├── Platform/
│   │   ├── Photos/
│   │   │   ├── PhotoLibraryScanIndexStore.swift
│   │   │   └── PhotoLibraryScanner.swift
│   │   ├── Upload/
│   │   │   ├── BackupClient.swift
│   │   │   ├── ChunkUploadSender.swift
│   │   │   └── ResumableUploadManager.swift
│   │   ├── Persistence/
│   │   │   └── (new) AutoBackupJobStore.swift
│   │   └── Background/
│   │       ├── (new) AutoBackupScheduler.swift
│   │       ├── (new) AutoBackupEngine.swift
│   │       └── (new) AutoBackupPolicyEvaluator.swift
│   └── iCherri-iosTests/
├── mac/
│   ├── Platform/
│   │   ├── ReceiverServer/
│   │   │   ├── Handlers/
│   │   │   │   ├── CheckBatchHandler.swift
│   │   │   │   ├── UploadHandler.swift
│   │   │   │   └── UploadStatusHandler.swift
│   │   └── Storage/
│   │       ├── DatabaseManager.swift
│   │       └── SessionManager.swift
│   └── iCherri-MacTests/
└── packages/
    ├── ICherriProtocol/
    │   └── Sources/ICherriProtocol/DTO/
    └── ICherriCore/
        └── Sources/ICherriCore/
```

**Structure Decision**: 기존 `apps/ios`, `apps/mac`, `packages/*` 분리를 유지한다. 자동 백업 전용 background orchestration은 iOS `Platform/Background`와 `Platform/Persistence`에 추가하고, receiver protocol 변경은 `ICherriProtocol`과 mac receiver/storage 계층에 국한한다.

## Complexity Tracking

정당화가 필요한 추가 복잡성 위반 없음.

# Tasks: iOS 화면 꺼짐 자동 백업

**Input**: Design documents from `/specs/002-background-auto-backup/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/receiver-auto-backup.md`, `quickstart.md`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 실행 가능 (서로 다른 파일, 선행 미완료 작업 의존 없음)
- **[Story]**: 해당 사용자 스토리 (`[US1]`, `[US2]`, `[US3]`)
- 모든 작업은 정확한 파일 경로를 포함한다

## Path Conventions

- iOS 앱: `apps/ios/`
- macOS receiver 앱: `apps/mac/`
- 공유 프로토콜/도메인 패키지: `packages/`
- 스펙 문서: `specs/002-background-auto-backup/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 자동 백업 구현을 위한 프로젝트 엔트리와 파일 골격 준비

- [x] T001 백그라운드 자동 백업 task identifier와 실행 진입점을 `apps/ios/Info.plist` 및 `apps/ios/iCherri-ios/iCherri_iosApp.swift`에 추가
- [x] T002 [P] 자동 백업 골격 파일을 `apps/ios/Platform/Background/AutoBackupScheduler.swift`, `apps/ios/Platform/Background/AutoBackupEngine.swift`, `apps/ios/Platform/Background/AutoBackupPolicyEvaluator.swift`, `apps/ios/Platform/Persistence/AutoBackupJobStore.swift`에 생성
- [x] T003 [P] 자동 백업 테스트 골격을 `apps/ios/iCherri-iosTests/AutoBackupSchedulerTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupPolicyEvaluatorTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupEngineTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupJobStoreTests.swift`, `apps/mac/iCherri-MacTests/AutoBackupReceiverContractTests.swift`에 생성

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 사용자 스토리의 공통 기반이 되는 상태 모델, 영속 저장소, 프로토콜 확장

- [x] T004 자동 백업 run/session 문맥 DTO를 `packages/ICherriProtocol/Sources/ICherriProtocol/DTO/API.swift` 및 `packages/ICherriProtocol/Sources/ICherriProtocol/DTO/Models.swift`에 추가
- [x] T005 [P] 자동 백업 상태 전이 도메인 로직을 `packages/ICherriCore/Sources/ICherriCore/AutoBackup/AutoBackupStateMachine.swift` 및 `packages/ICherriCore/Tests/ICherriCoreTests/AutoBackupStateMachineTests.swift`에 구현
- [x] T006 JSON 기반 run/job 영속 저장소를 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift` 및 `apps/ios/iCherri-iosTests/AutoBackupJobStoreTests.swift`에 구현
- [x] T007 mac receiver의 run-scoped idempotency 저장 계층을 `apps/mac/Platform/Storage/SessionManager.swift` 및 `apps/mac/Platform/Storage/DatabaseManager.swift`에 확장
- [x] T008 [P] receiver 계약 회귀 테스트를 `apps/mac/iCherri-MacTests/AutoBackupReceiverContractTests.swift` 및 `apps/mac/iCherri-MacTests/DatabaseManagerBackupRunTests.swift`에 추가
- [x] T009 iOS 업로드 계층이 run/session 문맥을 전달하도록 `apps/ios/Platform/Upload/BackupClient.swift` 및 `apps/ios/Platform/Upload/ResumableUploadManager.swift`를 확장

**Checkpoint**: 여기까지 끝나면 자동 백업용 상태 모델, 영속 저장소, 업로드 계약 기반이 준비되어야 한다.

---

## Phase 3: User Story 1 - 조건 충족 시 자동 백업 시작 (Priority: P1) 🎯 MVP

**Goal**: 사용자가 앱을 열어두지 않아도 배터리/Wi-Fi/정책 조건이 맞으면 자동 백업 run이 생성되고 시작된다.

**Independent Test**: 자동 백업 활성화 + 배터리 20% 이상 + Wi-Fi 켜짐 조건에서 새 자산이 있을 때, 앱 재조작 없이 run이 생성되고 업로드 준비 상태로 진입하면 통과

### Tests for User Story 1

- [x] T010 [P] [US1] 시작 조건과 스케줄 평가 테스트를 `apps/ios/iCherri-iosTests/AutoBackupPolicyEvaluatorTests.swift` 및 `apps/ios/iCherri-iosTests/AutoBackupSchedulerTests.swift`에 작성

### Implementation for User Story 1

- [x] T011 [US1] 자동 시작 정책 평가기를 `apps/ios/Platform/Background/AutoBackupPolicyEvaluator.swift`에 구현
- [x] T012 [US1] `BGProcessingTask` 등록과 자동 실행 진입을 `apps/ios/Platform/Background/AutoBackupScheduler.swift` 및 `apps/ios/iCherri-ios/iCherri_iosApp.swift`에 구현
- [x] T013 [US1] 실제 처리 대상 asset만으로 run을 생성하는 로직을 `apps/ios/Platform/Background/AutoBackupEngine.swift` 및 `apps/ios/Platform/Photos/PhotoLibraryScanIndexStore.swift`에 구현
- [x] T014 [US1] 자동 백업 설정, receiver 참조, trust token 참조 저장을 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift` 및 `apps/ios/Features/Backup/BackupDashboardView.swift`에 구현
- [x] T015 [US1] 자동 백업 토글과 eligibility blocked 요약 UI를 `apps/ios/Features/Backup/BackupDashboardView.swift` 및 `apps/ios/Features/Backup/BackupProgressView.swift`에 구현

**Checkpoint**: 자동 시작과 run 생성이 독립적으로 동작해야 한다.

---

## Phase 4: User Story 2 - 화면이 꺼지거나 앱이 중단되어도 이어서 백업 (Priority: P2)

**Goal**: 백업 도중 화면이 꺼지거나 앱이 재실행되어도 미완료 항목만 복구해서 이어서 처리하고, receiver 부재/변경/thermal pause를 안전하게 다룬다.

**Independent Test**: 업로드 도중 앱 중단, receiver 부재, thermal pause, receiver 변경 시나리오 후 재개 시 이미 완료된 항목은 다시 올리지 않고 미완료 항목만 이어지면 통과

### Tests for User Story 2

- [x] T016 [P] [US2] 재개/일시정지/실패 유지 테스트를 `apps/ios/iCherri-iosTests/AutoBackupEngineTests.swift` 및 `apps/mac/iCherri-MacTests/AutoBackupReceiverContractTests.swift`에 작성
- [x] T017 [P] [US2] failedRetained asset이 이후 automatic run에서 다시 평가 대상으로 복귀하는 회귀 테스트를 `apps/ios/iCherri-iosTests/AutoBackupEngineTests.swift` 및 `apps/ios/iCherri-iosTests/AutoBackupJobStoreTests.swift`에 추가

### Implementation for User Story 2

- [x] T018 [US2] staged file 생성·재사용·2GB 상한 enforcement를 `apps/ios/Platform/Background/AutoBackupEngine.swift` 및 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift`에 구현
- [x] T019 [US2] 재개 가능한 chunk 업로드 복구를 `apps/ios/Platform/Upload/BackupClient.swift`, `apps/ios/Platform/Upload/ChunkUploadSender.swift`, `apps/ios/Platform/Upload/ResumableUploadManager.swift`에 구현
- [x] T020 [US2] mac receiver의 init/status/chunk 재개와 idempotent session 처리를 `apps/mac/Platform/ReceiverServer/Handlers/UploadHandler.swift`, `apps/mac/Platform/ReceiverServer/Handlers/UploadStatusHandler.swift`, `apps/mac/Platform/Storage/SessionManager.swift`에 구현
- [x] T021 [US2] run 범위 기준 partial/finalize 정산을 `apps/mac/Platform/ReceiverServer/Handlers/CheckBatchHandler.swift` 및 `apps/mac/Platform/Storage/DatabaseManager.swift`에 구현
- [x] T022 [US2] thermal pause와 receiver unavailable pause/resume 전이를 `apps/ios/Platform/Background/AutoBackupPolicyEvaluator.swift` 및 `apps/ios/Platform/Background/AutoBackupEngine.swift`에 구현
- [x] T023 [US2] failedRetained asset을 다음 automatic run 후보 집합에 재편입하는 로직을 `apps/ios/Platform/Background/AutoBackupEngine.swift` 및 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift`에 구현
- [x] T024 [US2] cross-Mac handoff 금지와 7일 run expiry 처리를 `apps/ios/Platform/Background/AutoBackupEngine.swift` 및 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift`에 구현

**Checkpoint**: 자동 백업이 화면 꺼짐/앱 재실행/receiver 부재/receiver 변경 후에도 중복 없이 이어져야 한다.

---

## Phase 5: User Story 3 - 자동 백업 상태와 예외를 이해 가능하게 확인 (Priority: P3)

**Goal**: 사용자가 자동 백업이 왜 시작되지 않았는지, 왜 멈췄는지, 무엇이 완료되었는지를 로그 뷰어 없이도 이해할 수 있어야 한다.

**Independent Test**: 예약됨/준비 중/업로드 중/일시정지/receiver 대기/완료/일부 실패 상태와 사유가 UI에 일관되게 보이면 통과

### Tests for User Story 3

- [x] T025 [P] [US3] 상태 요약과 사유 메시지 테스트를 `apps/ios/iCherri-iosTests/AutoBackupStatusViewModelTests.swift` 및 `apps/ios/iCherri-iosTests/BackupProgressViewModelTests.swift`에 작성

### Implementation for User Story 3

- [x] T026 [US3] 자동 백업 상태 요약 모델과 UI 바인딩을 `apps/ios/Features/Backup/BackupDashboardView.swift` 및 `apps/ios/Features/Backup/BackupProgressView.swift`에 구현
- [x] T027 [US3] 최근 결과, 마지막 성공 시각, 다음 재평가/재개 대기를 `apps/ios/Features/Backup/BackupDashboardView.swift` 및 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift`에 구현
- [x] T028 [US3] 진단용 이벤트 기록과 UI용 요약 매핑을 `apps/ios/Platform/Persistence/AutoBackupJobStore.swift` 및 `apps/ios/Platform/Background/AutoBackupEngine.swift`에 구현
- [x] T029 [US3] receiver 변경/미도달/thermal/staged limit 메시지를 `apps/ios/Features/Backup/BackupDashboardView.swift` 및 `apps/ios/Features/Backup/BackupProgressView.swift`에 일관되게 노출

**Checkpoint**: 사용자가 로그 없이도 자동 백업 상태와 예외를 이해할 수 있어야 한다.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 전 스토리에 걸친 검증, 문서, 정리

- [x] T030 [P] 자동 백업 운영 가이드를 `specs/002-background-auto-backup/quickstart.md` 및 `README.md`에 반영
- [x] T031 iOS 자동 백업 테스트 묶음을 `apps/ios/iCherri-iosTests/AutoBackupSchedulerTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupPolicyEvaluatorTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupEngineTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupJobStoreTests.swift`, `apps/ios/iCherri-iosTests/AutoBackupStatusViewModelTests.swift` 기준으로 실행
- [x] T032 mac receiver 계약/회귀 테스트 묶음을 `apps/mac/iCherri-MacTests/AutoBackupReceiverContractTests.swift` 및 `apps/mac/iCherri-MacTests/DatabaseManagerBackupRunTests.swift` 기준으로 실행
- [ ] T033 end-to-end quickstart 검증과 dead code 정리를 `apps/ios/Features/Backup/BackupDashboardView.swift`, `apps/ios/Platform/Background/AutoBackupEngine.swift`, `apps/mac/Platform/ReceiverServer/Handlers/UploadHandler.swift`에 반영

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1** → 바로 시작 가능
- **Phase 2** → Phase 1 완료 후 시작
- **Phase 3 (US1)** → Phase 2 완료 후 시작
- **Phase 4 (US2)** → Phase 2 완료 후 시작, US1 결과물 일부 재사용
- **Phase 5 (US3)** → Phase 3, 4의 상태 모델/이벤트 결과물에 의존
- **Phase 6** → 모든 사용자 스토리 완료 후 시작

### User Story Dependencies

- **US1 (P1)**: 독립 MVP
- **US2 (P2)**: US1의 scheduler/run creation과 Phase 2의 protocol/job store에 의존
- **US3 (P3)**: US1/US2가 만든 상태와 이벤트 기록에 의존

### Within Each User Story

- 테스트 작성 → 상태/모델 구현 → 서비스/엔진 구현 → UI/통합 구현 순서
- `Upload`와 `Receiver` 양쪽을 바꾸는 작업은 protocol/storage 선행 후 진행

### Parallel Opportunities

- T002와 T003은 병렬 가능
- T005, T006, T008은 병렬 가능
- T010은 T011~T015와 병렬로 시작 가능
- T016은 T017~T024보다 먼저 쓰되, T018/T019 및 T020/T021은 서로 다른 파일 축이라 일부 병렬 가능
- T025는 T026~T029보다 먼저 쓰되, T026과 T028은 부분 병렬 가능
- T030과 T031/T032는 병렬 가능

## Parallel Example: User Story 1

```text
# 테스트와 정책/스케줄러 구현 분리
T010 AutoBackupPolicyEvaluatorTests / AutoBackupSchedulerTests
T011 AutoBackupPolicyEvaluator
T012 AutoBackupScheduler + iCherri_iosApp

# UI와 저장소 연결 분리
T014 AutoBackupJobStore + BackupDashboardView settings
T015 BackupDashboardView + BackupProgressView UI
```

## Parallel Example: User Story 2

```text
# iOS / mac 분리 축
T018 staged file lifecycle
T019 iOS resumable upload recovery
T020 mac upload/session idempotency
T021 mac finalize reconciliation
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1~2 완료
2. US1 완료
3. 자동 시작 + run 생성 + eligibility UI만으로 1차 검증

### Incremental Delivery

1. US1로 자동 시작
2. US2로 재개/중복 방지/receiver pause 복구
3. US3로 상태 가시성 강화

### Parallel Team Strategy

1. 한 축은 iOS orchestration/job store
2. 다른 축은 mac receiver idempotency/contract
3. 마지막 축은 iOS status UI와 테스트 정리

## Notes

- 모든 작업은 체크박스 포맷, Task ID, 파일 경로를 포함한다.
- 상태 전이 로직을 바꾸는 작업은 반드시 해당 테스트를 같이 갱신해야 한다.
- 구현 완료 후에는 `make ios-dev` 또는 `make mac-dev`가 아니라, 변경 범위에 맞는 테스트와 pre-commit 빌드를 우선 통과시켜야 한다.

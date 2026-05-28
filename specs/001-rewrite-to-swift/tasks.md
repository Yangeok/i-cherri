# Tasks: iCherri Swift Redirection

**Input**: Design documents from `/specs/001-rewrite-to-swift/`

**Prerequisites**: [plan.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/plan.md), [spec.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/spec.md), [research.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/research.md), [data-model.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/data-model.md), [api-endpoints.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/contracts/api-endpoints.md)

---

## Format: `[ID] [P?] [Story] Description`
- **[P]**: 병렬 개발 가능 여부 (의존성 없는 독립 파일/모듈 작업)
- **[Story]**: 해당 테스크가 속한 User Story 라벨 (US1, US2, US3, US4)

---

## Phase 1: Setup (공유 인프라 설정)

**Purpose**: 프로젝트 모노레포 폴더 레이아웃 구성 및 Swift Package SPM 모듈 세팅

- [X] T001 모노레포 워크스페이스 디렉토리 구조 생성 (`apps/ios/`, `apps/mac/`, `packages/`)
- [X] T002 [P] `packages/ICherriProtocol` SPM 패키지 템플릿 생성 및 초기화
- [X] T003 [P] `packages/ICherriCore` SPM 패키지 템플릿 생성 및 초기화
- [X] T004 [P] `packages/ICherriDesignSystem` SPM 패키지 템플릿 생성 및 초기화
- [X] T005 [P] `packages/ICherriPreviewSupport` SPM 패키지 템플릿 생성 및 초기화
- [X] T006 Xcode 워크스페이스 `iCherri.xcworkspace` 파일 생성 및 전체 패키지/앱 프로젝트 바인딩

---

## Phase 2: Foundational (공통 코어 및 로컬 네트워크 기초 구현)

**Purpose**: 본격적인 백업 시나리오 실행 전, 공통 DTO 모델 및 DB 인덱스, 네트워크 광고/수신 기초 모듈을 구현함

**⚠️ CRITICAL**: 이 단계가 완료되기 전까지는 개별 User Story 개발을 시작할 수 없습니다.

- [X] T007 [P] 공통 기기 정보 및 자산 데이터 모델 클래스 구현 in `packages/ICherriProtocol/Sources/ICherriProtocol/DTO/Models.swift`
- [X] T008 [P] API 요청/응답 계약 DTO(Codable) 구현 in `packages/ICherriProtocol/Sources/ICherriProtocol/DTO/API.swift`
- [X] T009 SQLite 데이터베이스 파일 관리 및 GRDB 마이그레이션 스키마 구현 in `apps/mac/iCherri-Mac/Platform/Storage/DatabaseManager.swift`
- [X] T010 [P] Bonjour 로컬 네트워크 광고용 수신 포트 리스너 구현 in `apps/mac/iCherri-Mac/Platform/LocalNetwork/BonjourAdvertiser.swift`
- [X] T011 [P] Bonjour 네트워크 탐색용 브라우저 구현 in `apps/ios/iCherri-iOS/Platform/LocalNetwork/BonjourBrowser.swift`

---

## Phase 3: User Story 1 - 최초 백업 및 증분 백업 (Initial & Incremental Backup) 🎯 MVP

**Goal**: iOS 사진첩 자산을 스캔하고, Bonjour 페어링 후 check-batch를 거쳐 필요한 미디어 파일만 안정적으로 업로드하여 Mac에 atomic 저장 처리함.

**Independent Test**: iOS 시뮬레이터 또는 기기에서 5개의 가상 사진첩 자산을 스캔 후 Mac 리시버로 페어링 연동하여 백업을 전송하고, 최종 폴더에 5개의 파일이 저장되고 DB 인덱스 상태가 `completed`가 되었는지 테스트함.

- [X] T012 [US1] PHAsset 기반 사진첩 접근 권한 처리 및 메타 데이터 스캔 어댑터 구현 in `apps/ios/iCherri-iOS/Platform/Photos/PhotoLibraryScanner.swift`
- [X] T013 [US1] Mac 리시버의 기본 로컬 HTTP 라우터 및 요청 핸들러 세팅 in `apps/mac/iCherri-Mac/Platform/ReceiverServer/ReceiverHTTPServer.swift`
- [X] T014 [US1] SQLite DB 인덱스 조회를 이용한 check-batch 판단 서비스 구현 in `packages/ICherriCore/Sources/ICherriCore/Deduplication/CheckBatchProcessor.swift`
- [X] T015 [US1] `/backup/check-batch` API 엔드포인트 핸들러 연동 in `apps/mac/iCherri-Mac/Platform/ReceiverServer/Handlers/CheckBatchHandler.swift`
- [X] T016 [US1] iOS 스캔 목록과 check-batch API 요청을 쏘는 백업 클라이언트 엔진 구현 in `apps/ios/iCherri-iOS/Platform/Upload/BackupClient.swift`
- [X] T017 [US1] `/uploads/init` 및 파일 청크 바이너리 스트림 수신 핸들러 연동 in `apps/mac/iCherri-Mac/Platform/ReceiverServer/Handlers/UploadHandler.swift`
- [X] T018 [US1] 로컬 HTTP 청크 전송 루프 엔진 구현 in `apps/ios/iCherri-iOS/Platform/Upload/ChunkUploadSender.swift`
- [X] T019 [US1] 검증 성공 시 `incoming/` 임시 파일을 최종 폴더로 이동(Atomic Move) 및 DB 인덱스 등록 로직 구현 in `apps/mac/iCherri-Mac/Platform/Storage/FileCommitProcessor.swift`

**Checkpoint**: 본 단계가 완료되면 iCherri의 가장 단순하고 핵심적인 증분 백업 플로우(MVP)가 정상 작동해야 합니다.

---

## Phase 4: User Story 2 - 단계별 중복 방지 (Deduplication Policy)

**Goal**: 동일한 미디어가 반복 백업되어 디스크 공간이 낭비되는 것을 방지하기 위해 1차(자산 ID), 2차(메타데이터), 3차(해시) 중복 제거 정책을 판단하고 처리함.

**Independent Test**: 내용이 완전 일치하는 사진 2장을 서로 다른 파일명으로 전송했을 때, 첫 번째 파일만 물리 저장되고 두 번째 파일은 물리 복사 없이 데이터베이스 매핑 데이터에 `duplicate`로 기록되는지 검증함.

- [X] T020 [P] [US2] 자산 정보 기반 메타데이터 핑거프린트 문자열 생성 규칙 구현 in `packages/ICherriCore/Sources/ICherriCore/Fingerprint/FingerprintGenerator.swift`
- [X] T021 [P] [US2] 중복 제거 조건 비교 및 결과 판정 비즈니스 룰 구현 in `packages/ICherriCore/Sources/ICherriCore/Deduplication/DeduplicationPolicy.swift`
- [X] T022 [US2] `CheckBatchProcessor.swift`에 중복 제거 판정 필터 로직 적용 in `packages/ICherriCore/Sources/ICherriCore/Deduplication/CheckBatchProcessor.swift`
- [X] T023 [US2] 중복 파일 발생 시 물리 저장을 생략하고 논리 관계 매핑(`duplicate_of_backup_id`) 기록 로직 추가 in `apps/mac/iCherri-Mac/Platform/Storage/DatabaseManager.swift`

**Checkpoint**: 중복 파일 전송 테스트 시 디스크 공간이 이중으로 소모되지 않고 논리 백업 기록으로 인덱싱되는지 확인합니다.

---

## Phase 5: User Story 3 - 대용량 파일 안정성 및 Resumable Chunk Upload

**Goal**: 대용량 비디오 업로드 시 메모리 크래시(OOM)를 차단하기 위한 스트리밍 해시 연산 적용 및 업로드 중단 시 세션을 기억해 이어서 업로드하는 로직 구현.

**Independent Test**: 500MB 크기의 대용량 비디오를 전송하다가 강제 단절시킨 후, 업로드 세션 상태 API를 조회하여 최종 전송 성공 지점 이후의 오프셋부터 재개해 최종 커밋 완료되는지 검증함.

- [X] T024 [P] [US3] 업로드 임시 세션 데이터베이스 상태 보존 및 관리 모듈 구현 in `apps/mac/iCherri-Mac/Platform/Storage/SessionManager.swift`
- [X] T025 [P] [US3] 전체 파일을 메모리에 로드하지 않는 스트리밍 SHA-256 해시 생성기 구현 in `packages/ICherriCore/Sources/ICherriCore/Integrity/StreamingHasher.swift`
- [X] T026 [US3] `/uploads/{id}/status` 세션 재개 오프셋 조회 API 라우터 구현 in `apps/mac/iCherri-Mac/Platform/ReceiverServer/Handlers/UploadStatusHandler.swift`
- [X] T027 [US3] iOS 전송 중단 핸들링 및 status 조회를 통한 재개 전송 로직 구현 in `apps/ios/iCherri-iOS/Platform/Upload/ResumableUploadManager.swift`

**Checkpoint**: 대용량 파일 전송 중단 후 재연결 시 처음부터 다시 전송하지 않고 남은 청크 조각만 순차 업로드 완료되는지 확인합니다.

---

## Phase 6: User Story 4 - 상세 백업 요약 표시 및 GUI 구성 (UI/UX)

**Goal**: iOS 26 및 macOS Tahoe(Liquid Glass) 비주얼 디자인에 최적화된 SwiftUI 대시보드 화면 및 업로드 프로그레스 바(pbar) 컨트롤을 완성함.

**Independent Test**: 백업을 수행하는 동안 게이지 애니메이션이 프레임 드랍 없이 부드럽게 렌더링되며, 완료 화면에서 성공/중복/실패 상세 수치가 디자인 가이드라인에 맞추어 출력되는지 확인함.

- [X] T028 [P] [US4] 공유 SwiftUI 디자인 컴포넌트(리퀴드 프로그레스 바, 다이내믹 그라데이션 광택 등) 구현 in `packages/ICherriDesignSystem/Sources/ICherriDesignSystem/Components/`
- [X] T029 [US4] iOS 권한 상태별 및 페어링 연결 가이드라인 온보딩 UI 구현 in `apps/ios/iCherri-iOS/Features/Backup/BackupDashboardView.swift`
- [X] T030 [US4] 백업 중인 상세 속도, 진행 상태 메시지 애니메이션 화면 구현 in `apps/ios/iCherri-iOS/Features/Backup/BackupProgressView.swift`
- [X] T031 [US4] macOS 메뉴바 상태 모니터링 아이콘 및 퀵 링크 구현 in `apps/mac/iCherri-Mac/Features/MenuBar/MenuBarExtraItem.swift`
- [X] T032 [US4] macOS 리시버 페어링 기기 목록 및 세션 현황 대시보드 뷰 구현 in `apps/mac/iCherri-Mac/Features/ReceiverDashboard/DashboardView.swift`

---

## Phase 7: Polish & Cross-Cutting Concerns (폴리시 및 유효성 검증)

**Purpose**: 보안 자격 증명 저장 및 주기적 임시 세션 만료 리소스 정리, 아키텍처 단위 테스트 보강

- [X] T033 iOS 및 macOS의 Keychain 연동을 통한 페어링 신뢰 토큰 안전 저장 로직 구현 in `apps/ios/iCherri-iOS/Platform/Keychain/KeychainStore.swift` 및 `apps/mac/iCherri-Mac/Platform/Keychain/MacKeychainStore.swift`
- [X] T034 만료된 임시 업로드 세션 파일(`.tmp/incoming/` 내 파편) 정리 스케줄러 구현 in `apps/mac/iCherri-Mac/Platform/Storage/CleanupScheduler.swift`
- [X] T035 [P] `packages/ICherriCore` 내 백업 상태 머신 전이 동작 단위 테스트 작성 in `packages/ICherriCore/Tests/ICherriCoreTests/BackupStateMachineTests.swift`
- [X] T036 [P] 대용량 스트리밍 SHA-256 해시 알고리즘 성능 및 OOM 예방 모니터링 단위 테스트 작성 in `packages/ICherriCore/Tests/ICherriCoreTests/StreamingHasherTests.swift`

---

## Dependencies & Execution Order (의존성 및 실행 순서)

### Phase Dependencies
1. **Phase 1: Setup**: 의존성 없음 (가장 먼저 시작 및 완수)
2. **Phase 2: Foundational**: Phase 1 완료 후 시작 가능 (핵심 코어 모델 및 데이터베이스가 완료되어야 개별 User Story 개발 가능)
3. **Phase 3: US1 (MVP)**: Phase 2 완료 후 즉시 시작. (가장 최우선 가치 핵심 경로)
4. **Phase 4 ~ 6 (US2, US3, US4)**: Phase 3 (US1) 완료 후 개별적으로 착수 가능.
5. **Phase 7: Polish**: 모든 핵심 시나리오(US1 ~ US4)가 완수된 뒤 적용.

### Parallel Opportunities (병렬 개발 기회)
- Phase 1의 패키지 템플릿 생성 태스크들(`T002` ~ `T005`)은 각 패키지 단위로 완전히 병렬 개발이 가능합니다.
- Phase 2의 DTO 구현(`T007`, `T008`)과 Bonjour 네트워크 기본 세팅(`T010`, `T011`)은 서로 영향 없이 병렬로 진행될 수 있습니다.
- Phase 3 완료 이후, 중복 제거 기능 개발(Phase 4)과 대용량 세션 이어받기 개발(Phase 5)은 파일 충돌 영역이 다르므로 다른 개발자가 동시에 개발할 수 있습니다.

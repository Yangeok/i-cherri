# Data Model: iOS 화면 꺼짐 자동 백업

## 1. AutoBackupPolicy

| Field | Type | Description | Validation |
|------|------|-------------|------------|
| `isEnabled` | `Bool` | 사용자가 자동 백업을 켰는지 | 필수 |
| `minimumBatteryPercent` | `Int` | 자동 시작 최소 배터리 | `20` 고정 |
| `requiresWiFiEnabled` | `Bool` | Wi-Fi 켜짐 필수 여부 | `true` |
| `blocksOnLowPowerMode` | `Bool` | 저전력 모드 차단 여부 | `false` |
| `pauseThermalThreshold` | `ThermalThreshold` | thermal pause 기준 | `.serious` |
| `stagedStorageLimitBytes` | `Int64` | staged temp 상한 | `2_147_483_648` |

## 2. AutoBackupRun

| Field | Type | Description | Validation |
|------|------|-------------|------------|
| `runID` | `UUID/String` | 자동 백업 실행 식별자 | 필수, 고유 |
| `receiverID` | `String` | run이 귀속된 Mac receiver | 필수 |
| `receiverURL` | `URL` | 당시 업로드 base URL | 필수 |
| `receiverName` | `String` | 표시용 receiver 이름 | 선택 |
| `trustTokenReference` | `String` | 저장된 신뢰 토큰 참조 | 필수 |
| `state` | `AutoBackupRunState` | run 상태 | 필수 |
| `pauseReason` | `RunPauseReason?` | 일시정지 이유 | 상태가 paused일 때 필수 |
| `createdAt` | `Date` | run 생성 시각 | 필수 |
| `lastEvaluatedAt` | `Date` | 정책/재개 조건 마지막 평가 시각 | 필수 |
| `expiresAt` | `Date` | run 기록 보존 만료 시각 | 생성 + 7일 |
| `librarySnapshotCount` | `Int` | 전체 라이브러리 개수 | `>= 0` |
| `librarySnapshotBytes` | `Int64` | 전체 라이브러리 바이트 | `>= 0` |
| `runAssetCount` | `Int` | 이번 run 대상 개수 | `>= 0` |
| `runAssetBytes` | `Int64` | 이번 run 대상 바이트 | `>= 0` |

### AutoBackupRunState

- `scheduled`
- `eligibilityBlocked`
- `preparing`
- `uploading`
- `paused`
- `partial`
- `completed`
- `expired`

### RunPauseReason

- `receiverUnavailable`
- `receiverChanged`
- `thermal`
- `batteryTooLow`
- `wifiDisabled`
- `stagedStorageLimit`
- `manualDisable`

### Run State Transitions

| From | Event | To |
|------|-------|----|
| `scheduled` | 정책 충족 | `preparing` |
| `scheduled` | 정책 미충족 | `eligibilityBlocked` |
| `eligibilityBlocked` | 재평가 후 정책 충족 | `preparing` |
| `preparing` | staged file 준비 완료 | `uploading` |
| `uploading` | thermal/receiver 문제 | `paused` |
| `paused` | 동일 receiver + 정책 재충족 | `uploading` |
| `uploading` | 전부 완료 | `completed` |
| `uploading` | 일부 실패 남음 | `partial` |
| `partial` | 후속 run 생성 및 실패 항목 재평가 | `completed` 또는 새 run으로 이관 |
| `scheduled/preparing/uploading/paused/partial` | 7일 만료 | `expired` |

## 3. AutoBackupAssetRecord

| Field | Type | Description | Validation |
|------|------|-------------|------------|
| `runID` | `String` | 소속 run | 필수 |
| `deviceID` | `String` | iPhone 식별자 | 필수 |
| `assetLocalID` | `String` | Photos asset 식별자 | 필수 |
| `metadataSnapshot` | `AssetMetadata` | 평가 당시 메타데이터 | 필수 |
| `state` | `AutoBackupAssetState` | 개별 항목 상태 | 필수 |
| `lastFailureReason` | `String?` | 마지막 실패 원인 | 실패 상태일 때 선택 |
| `lastFailureAt` | `Date?` | 마지막 실패 시각 | 실패 상태일 때 선택 |
| `completedAt` | `Date?` | 완료 시각 | 완료 상태일 때 선택 |
| `stagedFileID` | `String?` | 연결된 staged file | staging 이후 선택 |
| `receiverUploadID` | `String?` | mac receiver session 식별자 | 업로드 이후 선택 |

### AutoBackupAssetState

- `queued`
- `skippedDuplicate`
- `staging`
- `staged`
- `uploading`
- `paused`
- `completed`
- `failedRetained`

### Asset State Transitions

| From | Event | To |
|------|-------|----|
| `queued` | check-batch duplicate | `skippedDuplicate` |
| `queued` | 업로드 필요 | `staging` |
| `staging` | 파일 준비 완료 | `staged` |
| `staged` | upload init 성공 | `uploading` |
| `uploading` | receiver/thermal pause | `paused` |
| `paused` | 같은 receiver에서 재개 | `uploading` |
| `uploading` | commit 성공 | `completed` |
| `uploading/paused` | 실패 | `failedRetained` |
| `failedRetained` | 이후 run에서 재평가 | 새 run의 `queued` |

## 4. StagedAssetFile

| Field | Type | Description | Validation |
|------|------|-------------|------------|
| `stagedFileID` | `UUID/String` | staged file 식별자 | 필수 |
| `assetLocalID` | `String` | 원본 asset 식별자 | 필수 |
| `localURL` | `URL` | Application Support/temp 파일 위치 | 필수 |
| `byteSize` | `Int64` | 파일 크기 | `> 0` |
| `createdAt` | `Date` | 생성 시각 | 필수 |
| `cleanupEligibleAt` | `Date` | 정리 가능 시각 | 필수 |
| `usageState` | `StagedFileUsageState` | 사용 중 여부 | 필수 |

### StagedFileUsageState

- `reserved`
- `uploading`
- `completedPendingCleanup`
- `failedPendingReuse`
- `deleted`

## 5. ReceiverUploadSessionRef

| Field | Type | Description | Validation |
|------|------|-------------|------------|
| `receiverID` | `String` | session이 속한 receiver | 필수 |
| `uploadID` | `String` | mac receiver upload session ID | 필수 |
| `deviceID` | `String` | iPhone 식별자 | 필수 |
| `assetLocalID` | `String` | asset 식별자 | 필수 |
| `receivedBytes` | `Int64` | 서버가 받은 누적 바이트 | `>= 0` |
| `chunkSize` | `Int` | 서버가 승인한 chunk 크기 | `> 0` |
| `expiresAt` | `Date` | session 만료 시각 | 필수 |
| `status` | `ReceiverUploadSessionState` | receiver reported state | 필수 |

### ReceiverUploadSessionState

- `initialized`
- `receiving`
- `paused`
- `committed`
- `expired`

## 6. FailureRetentionRule

| Field | Type | Description |
|------|------|-------------|
| `assetLocalID` | `String` | 재평가 대상 asset |
| `lastFailedRunID` | `String` | 마지막 실패 run |
| `retainUntilSuccess` | `Bool` | 성공할 때까지 유지 여부 |
| `lastFailedAt` | `Date` | 마지막 실패 시각 |

## 7. BackupEventRecord

| Field | Type | Description |
|------|------|-------------|
| `eventID` | `UUID/String` | 이벤트 식별자 |
| `runID` | `String` | 관련 run |
| `assetLocalID` | `String?` | 관련 asset |
| `eventType` | `String` | started / paused / resumed / committed / failed 등 |
| `reason` | `String?` | 상세 원인 |
| `recordedAt` | `Date` | 기록 시각 |

## Relationships

- `AutoBackupRun 1 : N AutoBackupAssetRecord`
- `AutoBackupAssetRecord 0..1 : 1 StagedAssetFile`
- `AutoBackupAssetRecord 0..1 : 1 ReceiverUploadSessionRef`
- `AutoBackupRun 1 : N BackupEventRecord`

## Global Rules

- 한 시점에 활성 `AutoBackupRun`은 receiver 선택 기준 최대 1개다.
- `receiverID`가 바뀌면 기존 run은 `paused(receiverChanged)`로 남고 새 receiver 기준 새 run을 만든다.
- staged file 총량은 항상 2GB 이하를 유지해야 한다.
- `failedRetained` 항목은 원본이 존재하는 한 이후 run의 후보 집합에 다시 포함된다.
- `expired` run은 7일 보존 기간 이후 정리 대상이다.

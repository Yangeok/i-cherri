# Receiver Contract: Auto Backup Resume Semantics

## 목적

기존 iOS ↔ macOS HTTP 업로드 프로토콜을 유지하면서, 자동 백업에서 필요한 `run-scoped semantics`, `idempotency`, `resume`, `cross-Mac handoff 금지` 규칙을 명확히 한다.

## 계약 원칙

1. `check-batch`는 전체 라이브러리가 아니라 이번 run 대상 asset 집합만 받는다.
2. 같은 receiver 안에서는 동일 asset의 재개/중복 요청이 idempotent 해야 한다.
3. 다른 receiver로는 미완료 session을 handoff 하지 않는다.
4. `finalize-run`은 run-scoped 집합만 기준으로 partial/completed 판정을 내린다.

## Endpoint Semantics

### `POST /backup/check-batch`

**Request semantics**
- `backupRunID`는 자동 백업 run 식별자다.
- `candidates`는 이번 실행의 실제 평가/처리 대상 asset만 포함한다.
- `librarySnapshot.totalAssetCount/Bytes`는 전체 라이브러리 수치다.

**Response semantics**
- `requiredUploads`: 실제 업로드가 필요한 asset만 반환
- `alreadyBackedUp`: 같은 receiver에서 이미 완료된 asset
- `duplicates`: 다른 asset identity지만 동일 파일로 판정된 asset
- `unsupported`: 현재 receiver 정책상 처리 불가 asset

### `POST /uploads/init`

**Required behavior**
- 동일 receiver 안에서 같은 `deviceID + assetLocalID` 조합의 미완료 session이 있으면 기존 `uploadID`, `receivedBytes`, `chunkSize`, `expiresAt`를 재사용해 반환한다.
- 동일 asset이 이미 commit 완료되어 이후 `check-batch`에서 걸러졌어야 하는 경우, 서버는 중복 session을 만들지 않아야 한다.
- 자동 백업 구현 시 `UploadInitRequest`는 `backupRunID`와 안정적인 asset-level idempotency 문맥을 함께 전달할 수 있어야 한다. DTO 확장은 `ICherriProtocol`에서 정의한다.

### `GET /uploads/{uploadID}/status`

**Required behavior**
- session이 살아 있는 동안 항상 현재 `receivedBytes`, `status`, `expiresAt`를 반환해야 한다.
- iOS는 앱 재실행/다음 background wake에서 이 값을 기준으로 재개 offset을 계산한다.

### `PUT /uploads/{uploadID}/chunks/{index}`

**Required behavior**
- 이미 수신 완료된 동일 chunk를 다시 받더라도 서버 상태가 깨지지 않아야 한다.
- 수신 progress는 단조 증가해야 한다.
- partial write 이후 재요청이 와도 status 조회와 후속 chunk 수신이 가능해야 한다.

### `POST /uploads/{uploadID}/commit`

**Required behavior**
- commit은 idempotent 해야 한다.
- 같은 `uploadID` 또는 같은 asset-level idempotency 문맥으로 중복 commit이 와도 동일 `backupID/displayPath`를 반환해야 한다.
- commit 성공 후 temp upload file은 정리 가능 상태가 되어야 한다.

### `POST /backup/finalize-run`

**Required behavior**
- run 범위는 `check-batch`에 전달된 candidate 집합 기준이다.
- `missingAssetIDs`는 그 run 안에서 아직 완료되지 않은 asset만 포함한다.
- 일부 성공/일부 실패는 partial outcome으로 남겨 이후 run 재평가에 사용 가능해야 한다.

## Receiver Change Rule

- 자동 백업 run은 `receiverID`에 귀속된다.
- `receiverID`가 달라지면 새 receiver는 이전 receiver의 `uploadID`, `receivedBytes`, temp file, session TTL을 이어받지 않는다.
- iOS는 새 receiver 선택 후 새 run을 시작해야 한다.

## Session Lifetime Rule

- macOS receiver upload session TTL은 iOS run 보존 기간보다 짧을 수 있다.
- session TTL이 만료되어도 iOS는 다음 run에서 `check-batch`와 idempotent init 흐름을 통해 복구할 수 있어야 한다.
- session 만료는 run 기록 만료와 동일 의미가 아니다.

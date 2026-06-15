# Research: iOS 화면 꺼짐 자동 백업

## 결정 1: iOS 백그라운드 실행 모델은 `BGProcessingTask` + 영속 run 재개로 간다

- **Decision**: 자동 백업 v1은 `BGProcessingTask`가 백그라운드 실행 창을 열고, 그 창 안에서 기존 resumable 업로드 프로토콜을 재사용하는 방향으로 설계한다.
- **Rationale**: 현재 프로토콜은 `init → chunk → status → commit` 구조이고 macOS receiver도 이 전제를 갖고 있다. 이 구조는 앱이 다음 백그라운드 실행 창을 얻었을 때 `receivedBytes` 기준으로 재개하기 좋다.
- **Alternatives considered**:
  - `background URLSession` 전면 전환: OS 레벨 네트워크 지속성은 좋지만, 현재 chunk 프로토콜과 섞으면 range/file staging 복제가 커지고 설계가 급격히 복잡해진다.
  - foreground 전용 유지: 화면 꺼짐/앱 재실행 요구를 만족하지 못한다.

## 결정 2: iOS job persistence는 새 JSON actor store를 사용한다

- **Decision**: iOS 자동 백업 run/job 상태는 `Application Support` 아래 새 `AutoBackupJobStore` JSON 파일로 저장하고, staged file 메타데이터도 같은 저장소에서 관리한다.
- **Rationale**: 현재 `PhotoLibraryScanIndexStore`가 이미 actor + JSON + atomic write 패턴을 사용한다. v1은 단일 활성 receiver/단일 활성 run 범위이므로 새 DB 의존성을 추가하지 않고도 요구사항을 만족한다.
- **Alternatives considered**:
  - iOS에 GRDB 도입: 질의 유연성은 좋지만, 지금 범위에서는 의존성/마이그레이션 비용이 더 크다.
  - `UserDefaults` 확장: run/asset/session 상태와 staged file 수명주기를 저장하기에는 모델이 너무 크고 취약하다.

## 결정 3: receiver contract는 새 전송 계열을 만들지 않고 기존 HTTP 계약을 강화한다

- **Decision**: `check-batch`, `uploads/init`, `uploads/{id}/status`, `uploads/{id}/chunks/{index}`, `uploads/{id}/commit`, `finalize-run` 흐름은 유지하고, idempotency와 run-scoped semantics를 강화한다.
- **Rationale**: 이미 공유 DTO와 mac 핸들러가 존재한다. 새로운 업로드 API 패밀리를 추가하는 것보다, 기존 계약을 자동 백업 요구에 맞게 명확히 하는 편이 회귀 위험이 낮다.
- **Alternatives considered**:
  - whole-file single request 업로드: background-friendly 할 수는 있지만, 부분 업로드 복구와 기존 session 저장소를 대부분 버려야 한다.
  - receiver-side disk scan만으로 복구: 이미 dedup truth는 DB + disk fallback 조합으로 정리 중이고, 전송 세션 정확성을 대신해 주지 못한다.

## 결정 4: thermal pause는 `ProcessInfo.ThermalState.serious` 이상에서 발생시킨다

- **Decision**: iOS는 thermal state가 `.serious` 이상이면 현재 run을 `paused(thermal)`로 저장하고, 다음 평가 시점에 `.fair` 또는 `.nominal`이면 재개를 시도한다.
- **Rationale**: 사용자가 요구한 “과열이면 중단”을 iOS API 레벨에 맵핑하려면 `.serious`가 가장 현실적인 컷오프다. `.critical`은 이미 너무 늦다.
- **Alternatives considered**:
  - `.critical`에서만 중단: 배터리/발열 보호가 늦다.
  - thermal 상태 무시: 스펙 위반이다.

## 결정 5: run 범위와 library coverage는 분리한다

- **Decision**: 자동 백업 run은 `이번 실행에서 실제로 평가/처리할 asset 집합`만 포함하고, 전체 라이브러리 count/bytes는 별도 snapshot으로 유지한다.
- **Rationale**: 이미 수동/incremental 경로도 이 방향으로 수정되었다. check-batch payload와 mac `backup_run_assets` snapshot 부하를 줄이고, 진행률 의미를 명확히 한다.
- **Alternatives considered**:
  - run = 전체 라이브러리 snapshot: 진행률이 왜곡되고 control-plane 부하가 크다.

## 결정 6: receiver 변경 시 cross-Mac handoff는 금지한다

- **Decision**: 미완료 run은 원래 receiver에 귀속된 상태로만 보존하고, 새로운 Mac이 선택되면 새 run을 시작한다.
- **Rationale**: temp file, `receivedBytes`, upload session TTL, dedup context가 모두 원래 receiver에 묶여 있다. cross-Mac handoff는 이득보다 복잡성이 훨씬 크다.
- **Alternatives considered**:
  - cross-Mac handoff 허용: 복구/정합성/중복 방지 비용이 과도하다.
  - receiver 변경 즉시 기존 run 실패 처리: 상태 복구 정보가 사라져 운영성이 나빠진다.

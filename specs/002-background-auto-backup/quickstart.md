# Quickstart: iOS 화면 꺼짐 자동 백업

## 목표

이 기능은 `자동 시작`, `화면 꺼짐/앱 재실행 후 재개`, `receiver 부재/변경 처리`, `중복 업로드 방지`를 동시에 만족해야 한다.

## 현재 구현 상태

- `AutoBackupScheduler`, `AutoBackupPolicyEvaluator`, `AutoBackupEngine`, `AutoBackupJobStore`가 연결되어 있다.
- 자동 백업 토글, eligibility 차단 사유, 최근 결과, 마지막 성공, 다음 자동 체크 시간이 iPhone UI에 노출된다.
- staged upload 파일은 `2 GB` 상한을 넘기면 run이 멈추고 사유가 기록된다.
- mac receiver는 동일 chunk 재전송을 idempotent 하게 처리하고, gap chunk는 `409`로 거절한다.
- iOS resumable upload는 세션 상태를 다시 조회해 같은 offset 재시도, 더 앞선 offset 재개, 만료 세션 중단을 구분한다.
- 남은 실기기 검증 포인트는 `백그라운드 wake 타이밍`, `화면 꺼짐 중 실제 OS 스케줄`, `실제 Mac sleep/wake 조합`이다.

## 구현 순서

1. `ICherriProtocol`
   - 자동 백업 run 문맥과 idempotency를 표현할 DTO 확장 설계
   - 기존 `check-batch/init/status/commit/finalize` 계약과 호환 유지

2. `iOS orchestration`
   - `AutoBackupScheduler`
   - `AutoBackupPolicyEvaluator`
   - `AutoBackupEngine`
   - `AutoBackupJobStore`
   - 기존 `BackupDashboardViewModel`에서 orchestration 분리

3. `iOS upload/resume`
   - `ResumableUploadManager`, `BackupClient`, `ChunkUploadSender`를 자동 백업 run 복구 흐름에 연결
   - staged file 2GB 상한과 정리 규칙 구현

4. `mac receiver hardening`
   - `UploadHandler`, `UploadStatusHandler`, `CheckBatchHandler`
   - `SessionManager`, `DatabaseManager`
   - init/status/chunk/commit/finalize idempotency 강화

5. `UI status`
   - 자동 백업 켜짐/꺼짐
   - 현재 상태
   - 최근 결과
   - 보류/일시정지 이유
   - 마지막 성공 시각

## 테스트 우선순위

1. iOS run/job 상태 전이
2. staged file 2GB 상한 및 정리
3. 앱 재실행 후 run 복구
4. receiver 미도달 후 pause/resume
5. receiver 변경 후 cross-Mac handoff 금지
6. 동일 asset 중복 제출 시 최종 저장 1회만 반영

## 수동 검증 시나리오

1. 자동 백업 활성화 + 배터리 20% 이상 + Wi-Fi 켜짐
2. 새 사진/영상 추가 후 background 실행 기회 부여
3. 업로드 도중 화면 잠금
4. 앱 재실행 후 미완료 run 복구 확인
5. mac receiver sleep 또는 앱 종료 후 paused 상태 확인
6. mac receiver 복귀 후 resume 확인
7. 다른 Mac 선택 후 기존 run이 handoff되지 않고 새 run이 시작되는지 확인

## 권장 실행 명령

```bash
make ios-dev
make mac-dev
```

## 권장 테스트 명령

```bash
xcodebuild test -project apps/ios/iCherri-ios.xcodeproj -scheme iCherri-ios -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''

xcodebuild test -project apps/mac/iCherri-Mac.xcodeproj -scheme iCherri-Mac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''
```

## 운영 메모

- 자동 백업은 `충전 중`이 필수는 아니다.
- `Low Power Mode`는 현재 차단 조건이 아니다.
- paired receiver가 바뀌면 기존 run을 handoff 하지 않고 새 Mac에서 새 run을 만든다.
- 실패한 asset은 이후 automatic run에서 다시 평가 대상으로 돌아간다.
- run 기록은 `7일` 후 만료된다.

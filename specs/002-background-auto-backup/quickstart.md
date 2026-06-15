# Quickstart: iOS 화면 꺼짐 자동 백업

## 목표

이 기능은 `자동 시작`, `화면 꺼짐/앱 재실행 후 재개`, `receiver 부재/변경 처리`, `중복 업로드 방지`를 동시에 만족해야 한다.

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

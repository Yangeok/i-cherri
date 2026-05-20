# iPhone Backup Server

macOS 로컬 LAN 전용 iPhone 사진/영상 백업 서버입니다.  
초기 전체 백업은 iPhone 을 Mac 에 유선 연결해서 직접 복사하고, 그 뒤 `--reindex` 로 SQLite 인덱스를 만듭니다.  
그 이후부터만 iPhone Shortcuts 의 daily 증분 백업을 사용합니다.

## 보안 전제

- 이 서버는 **LAN 내부 전용**입니다.
- **public internet** 에 직접 노출하지 마세요.
- **cloudflared** 에 연결하지 마세요.
- **포트포워딩** 하지 마세요.
- **공용 Wi-Fi, 회사, 학교 네트워크** 에서 사용하지 마세요.
- 같은 네트워크에 있는 다른 기기도 업로드 요청을 보낼 수 있습니다.
- 인증이 없는 설계이므로 **신뢰 가능한 네트워크에서만 실행**해야 합니다.

## 구성 파일

- `main.go`: Go HTTP 서버
- `go.mod`: Go 모듈 파일
- `com.local.cherri-sync.plist`: macOS launchd 샘플
- `iphone_daily_backup.cherri`: iPhone Daily 증분 백업용 Cherri 소스

## 동작 구조

### 1. 초기 전체 백업

1. iPhone 을 Mac 에 유선 연결합니다.
2. 사진/영상을 Mac 의 `backup_dir` 로 직접 복사합니다.
3. 파일은 `YYYY-MM` 폴더 구조로 정리합니다.
4. `cherri-sync --reindex` 로 SQLite 인덱스를 생성합니다.

예시 구조:

```text
~/Photos/
├── 2026-04/
├── 2026-05/
└── .iphone-backup-index.sqlite3
```

반드시 `YYYY-MM` 단일 폴더를 사용합니다.

- 올바른 예: `~/Photos/2026-05/IMG_1234.HEIC`
- 틀린 예: `~/Photos/2026/05/IMG_1234.HEIC`

### 2. Daily 증분 백업

1. iPhone Shortcut 이 최근 3일 사진/영상을 찾습니다.
2. 각 항목을 순차 처리합니다.
3. 먼저 `/check` 로 메타데이터 중복 여부를 확인합니다.
4. 이미 있으면 업로드하지 않고 다음 항목으로 넘어갑니다.
5. 없으면 `/upload` 로 실제 파일을 업로드합니다.
6. 서버는 SHA-256 UNIQUE 로 최종 중복을 다시 막습니다.

## 코드 상수 설정

지금 버전은 환경변수나 설정 파일을 읽지 않습니다.

다음 값은 [main.go](/Users/yangeok/Dev/Test/shortcut/main.go) 상수로 고정돼 있습니다.

- `defaultAddr = ":8787"`
- `defaultBackupDir = "~/Photos"`
- `defaultMaxBytes = 2147483648`

다른 경로를 쓰고 싶으면 `main.go` 의 상수를 바꾼 뒤 다시 빌드하면 됩니다.

## 서버 API

### `GET /health`

- `200 OK`
- plain text `ok`

### `POST /check`

중복 확인용 메타데이터 API 입니다.

Request:

```json
{
  "original_name": "IMG_1234.HEIC",
  "created_at": "2026-05-19T12:00:00+09:00",
  "file_size": 3829184
}
```

중복 기준:

- `original_name`
- `created_at`
- `file_size`

세 값이 모두 같은 row 가 있으면 `exists=true` 를 반환합니다.

### `POST /upload`

실제 파일 업로드 API 입니다.

Form fields:

- `file`: 필수
- `original_name`: 선택
- `created_at`: 선택
- `file_size`: 선택

처리 규칙:

- 업로드 스트림은 한 번만 읽습니다.
- `backup_dir/.tmp/` 아래 임시 파일로 저장합니다.
- 저장하면서 동시에 SHA-256 을 계산합니다.
- 중복 SHA-256 이면 temp 파일을 삭제하고 `duplicate=true` 를 반환합니다.
- 중복이 아니면 `YYYY-MM` 폴더로 rename 합니다.
- 같은 파일명이 이미 있으면 `__1`, `__2` suffix 를 붙입니다.

## SQLite

DB 위치:

```text
<backup_dir>/.iphone-backup-index.sqlite3
```

예:

```text
~/Photos/.iphone-backup-index.sqlite3
```

다음 PRAGMA 를 사용합니다.

```sql
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;
```

스키마:

```sql
CREATE TABLE IF NOT EXISTS files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sha256 TEXT NOT NULL UNIQUE,
  original_name TEXT,
  saved_path TEXT NOT NULL,
  created_at TEXT,
  file_size INTEGER NOT NULL,
  uploaded_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_files_metadata
ON files(original_name, created_at, file_size);

CREATE INDEX IF NOT EXISTS idx_files_created_at
ON files(created_at);

CREATE INDEX IF NOT EXISTS idx_files_original_name
ON files(original_name);
```

## 빌드와 설치

### Makefile 사용 (권장)

이 프로젝트는 편의를 위해 `Makefile`을 제공합니다.

- **전체 빌드 (바이너리 + 단축어)**: `make all`
- **Go 서버 빌드**: `make go`
- **단축어 빌드 (Signed)**: `make shortcut`
- **서버 재빌드 및 재시작**: `make run`
- **결과물 삭제**: `make clean`

### 수동 빌드

#### Go 모듈 정리

```bash
go mod tidy
```

### 빌드

```bash
go build -o dist/cherri-sync .
```

### `~/bin` 에 설치

```bash
mkdir -p ~/bin
install -m 755 dist/cherri-sync ~/bin/cherri-sync
```

## 초기 백업 후 reindex

```bash
~/bin/cherri-sync --reindex
```

동작:

- `backup_dir` 아래 `YYYY-MM` 폴더를 스캔합니다.
- `.tmp`, `.DS_Store`, `.iphone-backup-index.sqlite3`, 숨김 파일은 제외합니다.
- 각 파일의 SHA-256 을 계산합니다.
- SQLite 인덱스를 생성하거나 갱신합니다.

주의:

- `reindex` 는 파일 시스템 메타데이터로 `created_at` 을 채웁니다.
- 초기 유선 복사 시 파일 시간 보존 방식에 따라 `/check` 메타데이터 매칭률이 달라질 수 있습니다.
- 그래도 `/upload` 의 SHA-256 최종 중복 방지는 그대로 동작합니다.

## launchd

1. 바이너리를 먼저 설치합니다.
2. `com.local.cherri-sync.plist` 의 경로를 사용자 환경에 맞게 수정합니다.
3. 다음 명령으로 LaunchAgents 위치에 복사합니다.

```bash
mkdir -p ~/Library/LaunchAgents
cp com.local.cherri-sync.plist ~/Library/LaunchAgents/com.local.cherri-sync.plist
```

### 서비스 로드

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.cherri-sync.plist
```

이미 로드돼 있으면:

```bash
launchctl kickstart -k gui/$(id -u)/com.local.cherri-sync
```

### 서비스 언로드

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.local.cherri-sync.plist
```

### 로그 확인

```bash
tail -f ~/Library/Logs/cherri-sync.out.log
```

```bash
tail -f ~/Library/Logs/cherri-sync.err.log
```

## 직접 실행

```bash
~/bin/cherri-sync
```

기본 주소:

```text
http://localhost:8787
```

## curl 테스트

Health check:

```bash
curl -v http://localhost:8787/health
```

Check API:

```bash
curl -v \
  -H "Content-Type: application/json" \
  -d '{"original_name":"test.HEIC","created_at":"2026-05-19T12:00:00+09:00","file_size":12345}' \
  http://localhost:8787/check
```

Upload API:

```bash
curl -v \
  -F "file=@/path/to/test.HEIC" \
  -F "original_name=test.HEIC" \
  -F "created_at=2026-05-19T12:00:00+09:00" \
  -F "file_size=12345" \
  http://localhost:8787/upload
```

## Cherri 단축어

파일:

```text
iphone_daily_backup.cherri
```

이 단축어는:

- 최근 3일 사진/영상을 찾고
- 순차 처리하고
- `/check` 먼저 호출하고
- `exists=false` 일 때만 `/upload` 를 호출합니다

주의:

- Cherri 의 `Find Photos` 표현은 버전별로 차이가 있어서, 이 프로젝트의 Cherri 는 **가장 가까운 유효한 코드**로 작성했습니다.
- 구현은 `getLatestPhotos()` 와 `getLatestVideos()` 를 넉넉히 가져온 뒤, 내부에서 최근 3일 필터를 적용합니다.
- 사진과 영상은 각각 오래된 순으로 처리합니다.
- Photos 와 Videos 를 완전히 하나의 전역 생성일 기준으로 merge sort 하지는 않습니다.
- 이 차이가 문제면 아래 **수동 Shortcuts fallback** 구성을 사용하세요.

## 수동 Shortcuts fallback

1. `Find Photos`
   - 최근 3일
   - 사진 + 영상 포함
   - 생성일 오래된 순 정렬
2. `Repeat with Each`
3. `Get Details of Repeat Item`
   - Name
   - Creation Date
   - File Size 가능하면
4. `Get Contents of URL`
   - URL: `http://<MAC_LAN_IP>:8787/check`
   - Method: `POST`
   - Request Body: `JSON`
   - JSON:
     - `original_name = Name`
     - `created_at = Creation Date`
     - `file_size = File Size`
   - Headers: 없음
5. `If exists is false`
6. `Get Contents of URL`
   - URL: `http://<MAC_LAN_IP>:8787/upload`
   - Method: `POST`
   - Request Body: `Form`
   - Form fields:
     - `file = Repeat Item`
     - `original_name = Name`
     - `created_at = Creation Date`
     - `file_size = File Size`
   - Headers: 없음
7. `End If`
8. `End Repeat`

## macOS 에서 실제 실행 순서

1. Mac 에서 서버 바이너리를 빌드합니다.
2. 필요하면 [main.go](/Users/yangeok/Dev/Test/shortcut/main.go) 의 `defaultBackupDir` 상수를 수정하고 다시 빌드합니다.
3. 초기 전체 백업은 iPhone 을 Mac 에 유선 연결해서 직접 복사합니다.
4. 복사가 끝나면 `--reindex` 를 실행합니다.
5. 서버를 실행하거나 launchd 로 올립니다.
6. `iphone_daily_backup.cherri` 를 컴파일해 iPhone Shortcuts 에 가져옵니다.
7. Cherri 파일 안의 `<MAC_LAN_IP>` 를 실제 Mac LAN IP 로 바꿉니다.
8. Daily 단축어를 하루 1회 정도 실행합니다.

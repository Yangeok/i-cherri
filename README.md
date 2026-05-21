<p align="center">
  <img src="assets/logo.png" width="300" />
</p>

# i-cherri

**i-cherri**는 macOS 로컬 LAN 환경에서 iPhone의 사진과 영상을 가장 안전하고 빠르고 스마트하게 백업하기 위한 솔루션입니다.  
초기 대량 백업은 유선 연결로 빠르게, 이후 일상적인 데이터는 [Cherri](https://cherrilang.org/) 기반의 iOS 단축어(Shortcuts)를 통해 증분 방식으로 자동 동기화합니다.

---

## 🍒 핵심 특징

- **초고속 초기 백업**: iPhone을 Mac에 유선 연결하여 직접 복사한 뒤 SQLite 인덱싱(`--reindex`)을 통해 즉시 동기화 상태를 맞춥니다.
- **스마트 증분 동기화**: Cherri로 작성된 iOS 단축어가 최근 3일간의 미디어를 분석, 서버와 통신하여 없는 파일만 골라 업로드합니다.
- **데이터 무결성**: SHA-256 해시 기반의 중복 체크를 통해 동일한 파일이 중복 저장되는 것을 원천 차단합니다.
- **경량 아키텍처**: Go로 작성된 단일 바이너리 서버와 SQLite를 사용하여 리소스를 최소화합니다.

---

## 🔒 보안 전제 (필독)

i-cherri는 단순함과 성능을 위해 별도의 인증 레이어를 포함하지 않습니다. 따라서 다음 보안 수칙을 반드시 준수해야 합니다.

- **로컬 LAN 전용**: 신뢰할 수 있는 집/사무실 Wi-Fi 내부에서만 사용하세요.
- **노출 금지**: 공용 인터넷, 포트 포워딩, Cloudflare Tunnel(cloudflared) 등을 통한 외부 노출은 절대 금지입니다.
- **신뢰 환경**: 공용 Wi-Fi, 학교, 카페 네트워크에서의 실행을 지양하세요.

---

## 🛠 구성 요소

- `main.go`: 고성능 Go HTTP 서버 및 인덱싱 엔진
- `iphone_daily_backup.cherri`: Cherri 기반 iOS 증분 백업 소스
- `com.local.cherri-sync.plist`: macOS 전용 launchd 자동 실행 템플릿
- `Makefile`: 빌드 및 관리를 위한 워크플로우 자동화

---

## 🚀 시작하기

### 1. 초기 전체 백업 및 인덱싱

1. iPhone을 Mac에 유선으로 연결합니다.
2. 사진/영상을 Mac의 `backup_dir` (기본값: `~/Photos`)로 직접 복사합니다.
3. 파일은 반드시 `YYYY-MM` 폴더 구조로 정리해야 합니다. (예: `~/Photos/2026-05/IMG_1234.HEIC`)
4. 인덱스를 생성합니다:
   ```bash
   make reindex
   ```

### 2. 서버 실행

`Makefile`을 사용하여 간편하게 빌드하고 실행할 수 있습니다.

```bash
# 전체 빌드 및 실행
make all
make run
```

기본 서버 주소: `http://localhost:8787`

---

## 📱 iOS 단축어 설정

1. `iPhone Daily Backup.shortcut` (signed) 파일을 iPhone으로 가져옵니다.
2. 단축어 내부의 서버 주소 설정을 Mac의 실제 로컬 IP로 변경합니다.
3. 필요시 자동화(Automation)를 통해 매일 특정 시간에 실행되도록 설정하세요.

---

## 📂 저장소 구조 및 DB

### 디렉토리 구조 예시
```text
~/Photos/
├── 2026-04/
├── 2026-05/
└── .iphone-backup-index.sqlite3
```

### SQLite 스키마
서버는 각 파일의 SHA-256, 원본 이름, 생성일, 크기 등을 인덱싱하여 관리합니다.

```sql
CREATE TABLE files (
  sha256 TEXT NOT NULL UNIQUE,
  original_name TEXT,
  saved_path TEXT NOT NULL,
  created_at TEXT,
  file_size INTEGER NOT NULL,
  uploaded_at TEXT NOT NULL
);
```

---

## 📋 관리 명령어 (Makefile)

- `make all`: Go 서버 및 단축어 전체 빌드
- `make go`: Go 서버 바이너리 빌드
- `make shortcut`: Signed 단축어 빌드
- `make reindex`: 사진 보관함 재인덱싱
- `make run`: 서버 재빌드 및 백그라운드 실행
- `make db-reset`: DB 초기화 및 전체 재인덱싱
- `make clean`: 빌드 결과물 삭제

---

## 💬 API Reference

- `GET /health`: 서버 상태 확인
- `POST /check`: 메타데이터 기반 중복 여부 확인
- `POST /upload`: 실제 미디어 파일 업로드 (SHA-256 중복 체크 포함)

---

**i-cherri**와 함께 소중한 추억을 가장 로컬하고 안전하게 보관하세요. 🍒

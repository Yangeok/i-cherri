# API Endpoint Contracts: iCherri HTTP API

본 문서는 iOS 백업 클라이언트와 macOS 백업 리시버 서버 간의 로컬 HTTP API 인터페이스 계약을 정의합니다. 
모든 데이터 구조는 `ICherriProtocol` 공유 패키지의 DTO 모델을 참조하며 JSON 형식을 기본으로 합니다.

---

## 1. 공통 HTTP 헤더 및 인증 규칙 (Common Rules)

페어링이 완료된 후의 모든 API 요청은 인증을 위해 아래 헤더를 전송해야 합니다:
- `Content-Type: application/json`
- `X-iCherri-Device-ID: {device_id}`
- `X-iCherri-Token: {pairing_trust_token}`

---

## 2. API 상세 명세

### 2.1 GET /receiver/info
- **설명**: 리시버 기기의 구동 상태와 프로토콜 지원 상태를 확인합니다. 페어링 전 탐색(Discovery) 직후 연결성을 확인할 때 사용합니다.
- **Request Headers**: (인증 헤더 불필요)
- **Response Payload (`ReceiverInfo`)**:
  ```json
  {
    "receiverID": "macbook-pro-m1-uuid",
    "receiverName": "My MacBook Pro",
    "platform": "macOS",
    "appVersion": "1.0.0",
    "protocolVersion": {
      "major": 1,
      "minor": 0
    },
    "status": "running",
    "availableFeatures": ["resumable_upload", "metadata_dedupe"]
  }
  ```

### 2.2 POST /pairing/start
- **설명**: iOS 기기가 리시버에 페어링 연결 요청을 게시합니다. Mac 화면에는 1회용 일시 코드(또는 QR 코드)가 팝업됩니다.
- **Request Payload**:
  ```json
  {
    "deviceID": "iphone-uuid",
    "deviceName": "길동의 iPhone",
    "platform": "iOS",
    "appVersion": "1.0.0",
    "protocolVersion": { "major": 1, "minor": 0 }
  }
  ```
- **Response Payload**:
  - HTTP 202 Accepted
  ```json
  {
    "status": "pending_user_confirmation",
    "expiresAt": "2026-05-26T13:15:00Z"
  }
  ```

### 2.3 POST /pairing/confirm
- **설명**: iOS 기기에서 입력된 인증 PIN 코드를 전송하여 최종 승인과 신뢰 토큰을 교환합니다.
- **Request Payload**:
  ```json
  {
    "deviceID": "iphone-uuid",
    "pinCode": "123456"
  }
  ```
- **Response Payload**:
  - HTTP 200 OK
  ```json
  {
    "status": "paired",
    "trustToken": "mac-generated-secure-token-value-here"
  }
  ```

### 2.4 POST /backup/check-batch
- **설명**: iOS 기기가 보유한 사진/동영상 자산 후보 목록을 전달하고, Mac 리시버의 인덱스 DB를 기준하여 백업 전송이 필요한 자산(required_uploads) 및 중복 건너뜀 대상 목록을 조회합니다.
- **Request Payload (`CheckBatchRequest`)**:
  ```json
  {
    "protocolVersion": { "major": 1, "minor": 0 },
    "device": {
      "deviceID": "iphone-uuid",
      "deviceName": "길동의 iPhone",
      "platform": "iOS",
      "appVersion": "1.0.0",
      "protocolVersion": { "major": 1, "minor": 0 }
    },
    "candidates": [
      {
        "deviceID": "iphone-uuid",
        "assetLocalID": "asset-10029",
        "originalFilename": "IMG_0293.HEIC",
        "mediaType": "photo",
        "creationDate": "2026-05-26T12:00:00Z",
        "modificationDate": "2026-05-26T12:01:00Z",
        "byteSize": 2459000,
        "pixelWidth": 4032,
        "pixelHeight": 3024,
        "quickFingerprint": "20260526120000_2459000_4032_3024"
      }
    ]
  }
  ```
- **Response Payload (`CheckBatchResponse`)**:
  ```json
  {
    "requiredUploads": [
      {
        "assetLocalID": "asset-10029",
        "uploadReason": "notFound",
        "uploadMode": "resumableHTTPChunked",
        "preferredChunkSize": 5242880
      }
    ],
    "alreadyBackedUp": [],
    "duplicates": [],
    "unsupported": []
  }
  ```

### 2.5 POST /uploads/init
- **설명**: 청크 업로드를 수행할 세션을 초기화합니다.
- **Request Payload (`UploadInitRequest`)**:
  ```json
  {
    "protocolVersion": { "major": 1, "minor": 0 },
    "device": { "deviceID": "iphone-uuid", "deviceName": "길동의 iPhone" },
    "asset": { "assetLocalID": "asset-10029", "byteSize": 2459000 },
    "filename": "IMG_0293.HEIC",
    "expectedByteSize": 2459000,
    "requestedChunkSize": 5242880
  }
  ```
- **Response Payload (`UploadInitResponse`)**:
  ```json
  {
    "uploadID": "upload-session-uuid-111",
    "accepted": true,
    "chunkSize": 5242880,
    "receivedBytes": 0,
    "expiresAt": "2026-05-27T13:00:00Z"
  }
  ```

### 2.6 PUT /uploads/{uploadId}/chunks/{index}
- **설명**: 지정된 오프셋 및 인덱스의 바이너리 파일 조각(chunk)을 업로드합니다.
- **Request Body**: `application/octet-stream` 바이너리 청크 데이터
- **Headers**:
  - `Content-Range: bytes {start}-{end}/{total}`
- **Response Payload**:
  - HTTP 200 OK
  ```json
  {
    "uploadID": "upload-session-uuid-111",
    "index": 0,
    "receivedBytes": 2459000,
    "status": "receiving"
  }
  ```

### 2.7 GET /uploads/{uploadId}/status
- **설명**: 업로드가 중간에 끊겼을 때 현재 서버가 수신 보관한 임시 크기를 확인하여 클라이언트가 전송 시작 위치를 알 수 있게 합니다.
- **Response Payload (`UploadStatusResponse`)**:
  ```json
  {
    "uploadID": "upload-session-uuid-111",
    "status": "paused",
    "receivedBytes": 1048576,
    "expiresAt": "2026-05-27T13:00:00Z"
  }
  ```

### 2.8 POST /uploads/{uploadId}/commit
- **설명**: 모든 청크 조각의 업로드를 끝마치고, Mac 리시버에게 최종 파일 결합 및 무결성(크기 및 SHA-256) 검증을 요청합니다.
- **Request Payload (`CommitUploadRequest`)**:
  ```json
  {
    "protocolVersion": { "major": 1, "minor": 0 },
    "uploadID": "upload-session-uuid-111",
    "assetLocalID": "asset-10029",
    "finalByteSize": 2459000,
    "finalContentHash": "a1b2c3d4e5f6...",
    "clientFinishedAt": "2026-05-26T13:05:00Z"
  }
  ```
- **Response Payload (`CommitUploadResponse`)**:
  ```json
  {
    "status": "completed",
    "backupID": "backup-uuid-777",
    "displayPath": "2026/05/IMG_0293.HEIC"
  }
  ```
  *(해시 또는 크기 검증 실패 시 status: "checksumMismatch" 또는 "sizeMismatch"와 함께 에러 반환)*

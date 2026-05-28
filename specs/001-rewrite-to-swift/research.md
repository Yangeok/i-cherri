# Technical Research: iCherri Swift-native Redirection

본 문서에서는 iCherri 프로젝트의 Swift 네이티브 재설계를 위해 결정된 주요 기술 스택, 아키텍처 패턴 및 검토된 대안들에 대해 다룹니다.

---

## 1. 단계별 중복 제거 전략 (Deduplication Policy)

- **결정 (Decision)**: 
  - 1차: `device_id` + `asset_local_id` 조회 (SQLite 인덱스 매칭)
  - 2차: `quick_fingerprint` (촬영일, 생성일, 바이트 크기, 해상도로 구성된 고유 메타데이터 키) 검색
  - 3차: `SHA-256` 콘텐츠 해시 매칭
- **결정 사유 (Rationale)**: 
  - iPhone의 배터리 및 CPU 리소스를 절약하기 위함입니다. 백업을 시작하기 전 수천 개의 사진과 수십 GB 동영상의 SHA-256을 기기에서 선제 계산하면 업로드 전 동기화 시작 단계에서 심각한 지연과 전력 소모가 발생합니다.
  - 메타데이터 매칭(1, 2단계)으로 먼저 분류하여 업로드 필요 목록을 거르고, 최종 업로드 완료 시점에 스트리밍 방식으로 SHA-256 해시를 검증함으로써 자원 소모를 최소화합니다.
- **검토 대안 (Alternatives Considered)**:
  - *대안 1*: 모든 자산의 SHA-256을 iOS 기기에서 미리 계산하여 `/backup/check-batch`에 전달하기.
  - *반려 이유*: 수십 GB의 동영상을 pre-hash하는 것은 모바일 배터리와 CPU 과열 문제를 유발하므로 부적합합니다.

---

## 2. 대용량 파일 Resumable HTTP Chunk Upload

- **결정 (Decision)**: 
  - Swift HTTP 기반의 Resumable Chunk Upload 구현.
  - 흐름: `POST /uploads/init` (유효성 검사 및 세션 시작) -> `PUT /uploads/{id}/chunks/{index}` (청크 업로드) -> `GET /uploads/{id}/status` (끊겼을 때 재개 위치 조회) -> `POST /uploads/{id}/commit` (Mac이 최종 병합, 크기 및 해시 검증 수행).
- **결정 사유 (Rationale)**: 
  - iOS의 `URLSession` 및 macOS 리시버의 HTTP 서버 컴포넌트를 사용하면 진행률 콜백, 세션 유지, 재시도 제어를 Swift 코드로 매우 미세하게 제어할 수 있습니다. 
  - SMB 복사는 iOS의 Files App 데몬이 관리하여 세부적인 진행 제어나 업로드 결과 콜백을 Swift 코드 내에서 가로채기 어려우며, 중단 시 재개(Resume) 관리가 곤란합니다.
- **검토 대안 (Alternatives Considered)**:
  - *대안 1*: iOS의 `파일` 공유 API를 통한 SMB 저장 폴더 복사 방식.
  - *반려 이유*: 진행 상태의 상세 표시가 어렵고, 네트워크 끊김 시 이어서 복사하는 로직을 제어하기 힘들며, 중복 제거 여부를 업로드 도중에 가려내기 어렵습니다.

---

## 3. macOS 리시버용 데이터베이스 프레임워크

- **결정 (Decision)**: 
  - SQLite를 로우 레벨로 다룰 수 있는 **GRDB.swift** 라이브러리 채택.
- **결정 사유 (Rationale)**: 
  - GRDB.swift는 SQLite의 이중 접근 및 다중 쓰기 스레드 안전성(Concurrent access)이 뛰어나며 스키마 마이그레이션이 매우 투명합니다. 
  - 백업 자산이 수십만 개로 늘어났을 때도 고속의 SQLite 튜플 읽기/쓰기가 가능하고 DB 파일 이동 및 백업 관리가 쉽습니다.
- **검토 대안 (Alternatives Considered)**:
  - *대안 1*: Apple의 Core Data 또는 SwiftData 사용.
  - *반려 이유*: SwiftData는 아직 프레임워크 수준에서 외부 백업 폴더 내부로의 DB 마이그레이션 및 동적 물리 볼륨 경로 변경 시 예기치 못한 스레드 락이나 마이그레이션 예외 처리가 까다로우며, CLI 도구 연동이나 로우 쿼리 검색 효율성 측면에서 GRDB.swift가 더 단순하고 안정적입니다.

---

## 4. 로컬 기기 발견 및 페어링 프로토콜

- **결정 (Decision)**: 
  - Apple의 **Bonjour (mDNS)** 프로토콜 및 Network.framework (`NWBrowser` 및 `NWListener`) 활용. 수동 IP 입력Fallback 필수 포함.
- **결정 사유 (Rationale)**: 
  - Apple 플랫폼 전용 앱이므로, iOS와 macOS에서 zero-configuration 네트워킹을 구현하기에 가장 네이티브하고 신뢰할 수 있는 수단입니다.
- **검토 대안 (Alternatives Considered)**:
  - *대안 1*: SSDP (Simple Service Discovery Protocol) 또는 UDP 커스텀 브로드캐스트.
  - *반려 이유*: iOS 앱에서 원시 UDP 브로드캐스트 송수신을 사용하려면 Apple로부터 별도의 로컬 네트워크 브로드캐스트 권한(Local Network Multicast Entitlement) 승인을 받아야 하는 등 배포 제약이 심하며, 전력 소모도 더 큽니다.

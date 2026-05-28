# Implementation Plan: iCherri Swift-native Redirection

**Branch**: `001-rewrite-to-swift` | **Date**: 2026-05-26 | **Spec**: [spec.md](file:///Users/yangeok/Dev/Test/i-cherri/specs/001-rewrite-to-swift/spec.md)

**Input**: Feature specification from `/specs/001-rewrite-to-swift/spec.md`

---

## 요약 (Summary)
기존의 iOS Shortcuts + Go server + SMB 기반의 아키텍처를 완전히 폐기하고, **SwiftUI 기반 iOS 백업 클라이언트 앱**과 **SwiftUI 기반 macOS 메뉴바 리시버 앱**을 네이티브 방식으로 구현합니다. 
자산 스캔, 로컬 네트워크 탐색(Bonjour), Resumable HTTP Chunk Upload, SQLite 기반 백업 인덱싱, 스트리밍 SHA-256 무결성 검증, 3단계 중복 제거를 통해 대용량 미디어를 안전하고 효율적으로 백업합니다. 
공통 데이터 계약과 UI 토큰은 공유 Swift Package 구조로 설계하여 모노레포 내 코드 중복을 최소화합니다.

---

## 기술 컨텍스트 (Technical Context)

- **언어 및 버전**: Swift 5.9+ (Swift 6 호환 모드)
- **주요 의존성**: Photos.framework, Network.framework, SQLite (GRDB.swift 권장), SwiftUI, Foundation
- **저장소**: SQLite 및 로컬 파일 시스템 (`incoming/` 및 `YYYY/MM/` 오리지널 폴더)
- **테스트 프레임워크**: XCTest 및 Swift Testing (유닛 테스트 및 상태 머신 검증)
- **대상 플랫폼**: iOS 26.0+ 및 macOS 26.0+ (Tahoe) 지원 최적화 (하위 호환: iOS 16.0+, macOS 13.0+)
- **프로젝트 유형**: iOS 모바일 앱 + macOS 데스크탑 리시버 앱 + 공유 패키지 (Swift Package)
- **성능 목표**: 기기 자산 스캔 속도 초당 1,000개 이상, 스트리밍 해시 계산 시 메모리 100MB 이하 유지
- **제약 조건**: 로컬 LAN 전용(인터넷 백업 제외), 샌드박스 외부 볼륨 쓰기 지원 권한 확보(Security-scoped bookmark)
- **규모/범위**: MVP 사양 (1기기 페어링 및 로컬 단방향 백업 연동)

---

## 헌법 점검 (Constitution Check)

*GATE: Phase 0 연구 전 통과 필요. 디자인 및 계약 정의 후 재확인.*

본 프로젝트의 핵심 아키텍처 원칙에 따라 점검합니다:
- **플랫폼 분리 원칙**: UI와 도메인, 플랫폼 종속 아답터(Photos, SQLite 로우)가 엄격하게 분리되었는가? -> **Pass**. 플랫폼 특화 구현은 각 App 내부 Platform 계층에 한정하며, 공유 패키지는 순수 도메인 로직과 데이터 계약(DTO)만을 다룹니다.
- **스트리밍 아키텍처**: 대용량 비디오 검증을 위한 스트리밍 처리가 명시되었는가? -> **Pass**. 전체 파일을 메모리에 로드하지 않는 스트리밍 SHA-256 파이프라인 설계를 반영합니다.
- **데이터 일치성**: iOS와 macOS 간 DTO가 일관되게 공유되는가? -> **Pass**. `ICherriProtocol` 공유 패키지를 통해 컴파일 타임에 타입 불일치를 원천 차단합니다.
- **디자인 가이드라인 준수**: iOS 26 및 macOS Tahoe의 Liquid Glass / Glassmorphism 스타일 원칙이 UI 스펙에 반영되었는가? -> **Pass**. SwiftUI의 Material 시스템(`ultraThinMaterial`)과 공간 감각적 레이아웃이 요구사항에 공식 통합되었습니다.


---

## 프로젝트 구조 (Project Structure)

### 문서 구조 (specs/001-rewrite-to-swift/)
```text
specs/001-rewrite-to-swift/
├── spec.md              # 요구사항 명세서
├── plan.md              # 구현 계획서 (본 파일)
├── research.md          # 기술 조사서 (Phase 0)
├── data-model.md        # 데이터 모델 설계서 (Phase 1)
├── quickstart.md        # 개발 가이드 (Phase 1)
└── contracts/           # API/DTO 규약 명세 (Phase 1)
```

### 소스 코드 레이아웃 (Repository Root)
```text
icherri/
  iCherri.xcworkspace

  apps/
    ios/
      iCherri-iOS/       # iOS Backup Client
    mac/
      iCherri-Mac/       # macOS Receiver (Menu Bar)

  packages/
    ICherriProtocol/      # Shared DTOs
    ICherriCore/          # Domain Logic & State Machine
    ICherriDesignSystem/  # Shared SwiftUI Tokens/Components
    ICherriPreviewSupport/# Preview Mock Data & Mock Services
```

**구조 결정**: 아키텍처 원칙에 따라 플랫폼 독립 패키지군(packages/)과 각 플랫폼 실행 단말 앱(apps/)으로 분리된 구조를 적용합니다.

---

## 복잡성 추적 (Complexity Tracking)

*헌법 점검 시 예외적으로 타협해야 하거나 추가적인 복잡성 도입이 요구되는 사항 기록*

| 위반/복잡성 사항 | 도입 목적 및 필요성 | 대안이 거부된 이유 |
|---|---|---|
| GRDB.swift 또는 외부 SQLite 라이브러리 도입 | SwiftData는 macOS 샌드박스 및 세밀한 로우레벨 파일 DB 잠금 관리에 다소 블랙박스 요소가 많고 무거움 | SwiftData/Core Data는 스키마 마이그레이션이 무겁고, 백업 인덱스의 신속한 로우 레벨 튜플 업데이트에 부적합하여 GRDB를 선택 |
| Bonjour와 수동 IP Fallback 동시 구현 | 다양한 공유기(AP Isolation 등) 및 Wi-Fi 대역 차단 환경에서도 백업 안정성 보장 | Bonjour 서비스 탐색 실패 시 사용자가 수동 연결할 수 있는 경로 없이는 네트워크 단절 이슈 대응이 불가능함 |

# Developer Quickstart: iCherri Swift Redirection

본 가이드는 새롭게 재정의된 iCherri Apple 네이티브 아키텍처 환경에서 개발 및 빌드를 시작하는 개발자를 위한 문서입니다.

---

## 1. 개발 환경 요구사항

- **OS**: macOS 13.0 (Ventura) 이상 권장
- **Xcode**: 15.0 이상 (Swift 5.9 및 SwiftUI 최적화)
- **CocoaPods / Carthage**: 사용하지 않음 (모든 공유 코드는 **Swift Package Manager(SPM)**로 관리)

---

## 2. 작업 공간 및 프로젝트 오픈

리포지토리 루트의 워크스페이스 파일을 통해 통합 빌드를 수행합니다:
1. Xcode를 실행하고 `iCherri.xcworkspace` 워크스페이스를 오픈합니다.
2. 워크스페이스 내에 `apps/` 폴더 산하의 개별 앱 프로젝트와 `packages/` 폴더 산하의 로컬 SPM 패키지들이 로드되어 있는지 확인합니다.

---

## 3. 공유 Swift Package 통합 빌드

모노레포 내의 코드는 아래와 같이 세분화된 패키지로 분리되어 타겟 앱에 임포트됩니다:
- `ICherriProtocol`: 데이터 전송 모델(DTO). iOS와 macOS 프로젝트 모두에 링크됩니다.
- `ICherriCore`: 백업 엔진 코어, 상태 머신 및 중복 판단 규칙.
- `ICherriDesignSystem`: 공유 SwiftUI 배지, 로딩바 컴포넌트들.
- `ICherriPreviewSupport`: UI 프리뷰 피스처 및 더미 Mock 서비스 제공.

**테스트 빌드 방법**:
- Xcode의 상단 스키마 선택 도구에서 `ICherriCore` 또는 `ICherriProtocol` 패키지를 선택하고 `Cmd + U`를 입력해 내장된 단위 테스트군을 실행할 수 있습니다.

---

## 4. 로컬 구동 및 검증 방법

### 4.1 macOS 리시버 서버 실행
1. Xcode 스키마에서 `iCherri-Mac` 앱을 타겟으로 선택합니다.
2. 실행 기기를 `My Mac`으로 지정하고 `Cmd + R`을 입력해 실행합니다.
3. 시스템 메뉴바 우측 상단에 🍒 아이콘이 표시되는지 확인합니다.
4. 대시보드를 열고, 설정 창에서 백업 루트 폴더를 로컬의 임의 폴더(예: `~/Desktop/iCherriBackup`)로 지정합니다.

### 4.2 iOS 백업 클라이언트 실행
1. Xcode 스키마에서 `iCherri-iOS` 앱을 타겟으로 선택합니다.
2. 시뮬레이터(Simulator) 또는 실제 Wi-Fi에 연결된 테스트용 iPhone 장비를 지정합니다.
3. `Cmd + R`로 실행 후 온보딩 화면에서 로컬 네트워크 권한 및 사진첩 전체 접근 권한을 승인합니다.
4. 동일한 공유기 Wi-Fi 대역 상에서 실행 중인 Mac 리시버가 기기 목록에 검색되는지 확인합니다.
5. 페어링 핀 코드를 입력해 연동을 완료하고, 임의의 사진 앨범을 지정해 테스트 백업 전송을 시작합니다.

---

## 5. 데이터 맵핑 및 네이밍 컨벤션 (Swift Naming & SQL Mapping)

iCherri는 Swift 언어 규격과 관계형 데이터베이스(SQLite)의 관례를 모두 존중하기 위해 다음 규칙에 맞춰 맵핑합니다:

- **Swift DTO 및 도메인 객체**: Swift API 디자인 가이드라인에 따라 **camelCase**를 채택합니다.
  - 예: `deviceID`, `assetLocalID`, `uniformTypeIdentifier`
- **SQLite 테이블 컬럼**: 데이터베이스 설계 표준에 따라 **snake_case**를 채택합니다.
  - 예: `device_id`, `asset_local_id`, `uniform_type_identifier`
- **자동 맵핑 구현 (GRDB 및 Codable)**:
  - GRDB.swift 레코드 구현 시 `CodingKeys`를 정의하거나 `DatabaseColumnDecodingStrategy`를 활용하여 컴파일 타임에 안전하게 상호 변환되도록 처리합니다.
  - API 통신 시 JSONEncoder/JSONDecoder의 `keyEncodingStrategy = .convertToSnakeCase` 및 `keyDecodingStrategy = .convertFromSnakeCase` 설정을 기본으로 적용하여 통신 패킷 수준의 일치성을 유지합니다.


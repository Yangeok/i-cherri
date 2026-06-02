<p align="center">
  <img src="assets/logo.png" width="300" />
</p>

# i-cherri

<p align="center">
  <a href="README.md">English</a> |
  <b>한국어</b>
</p>

**i-cherri**는 iPhone과 Mac 사이에서 동작하는 Swift 네이티브 로컬 네트워크 사진 백업 앱입니다.
iPhone 앱이 사진 보관함을 스캔하고 Bonjour로 Mac 리시버를 찾은 뒤, 재개 가능한 청크 업로드로 macOS 앱에 미디어를 전송합니다.

---

## 아키텍처

- `apps/ios/`: SwiftUI 기반 iPhone 백업 클라이언트
- `apps/mac/`: SwiftUI 기반 macOS 리시버 앱
- `packages/ICherriProtocol`: 공용 DTO와 API 계약
- `packages/ICherriCore`: 중복 제거, 해시, 백업 코어 로직
- `packages/ICherriDesignSystem`: 공용 UI 컴포넌트

---

## 요구 사항

- Xcode 16+
- 로컬 네트워크 접근이 가능한 macOS
- 같은 LAN에 있는 iPhone
- Make

---

## 개발

```bash
make mac-app
make ios-app
```

자주 쓰는 명령:

- `make mac-run`: macOS 리시버 앱 빌드 후 실행
- `make mac-dev`: macOS 앱 실행 후 로그 스트림 연결
- `make ios-run`: 연결된 iPhone에 빌드/설치/실행
- `make ios-dev`: iPhone 앱 실행 후 콘솔 연결

---

## 현재 백업 흐름

1. macOS 리시버 앱 실행
2. iPhone 앱 실행 후 사진/로컬 네트워크 권한 허용
3. iPhone과 Mac 페어링
4. iPhone에서 백업 시작
5. macOS 대시보드에서 active session과 백업 이력 확인

---

## 보안

- 신뢰 가능한 로컬 네트워크에서만 사용
- 리시버를 공용 인터넷에 노출하지 말 것
- 페어링 데이터는 신뢰되지 않은 머신과 공유하지 말 것

---

## 상태

이 저장소는 예전 Go 서버 + Shortcut 기반 백업 흐름에서 벗어났다.
현재 개발 대상은 Swift 네이티브 iPhone/macOS 앱뿐이다.

# iOS Shortcuts `Find Photos` 액션 Cherri `rawAction` 역추적 실험

---

## 1. 핵심 요약 및 결론 (Overview & Objective)

**Cherri가 네이티브로 지원하지 않는 iOS 단축어의 "사진 필터링(Find Photos)" 기능은 수동으로 작성한 단축어의 plist를 역추적(리버싱)하여 `rawAction` 구조로 완벽히 변환하고 동적 변수 제어까지 구현할 수 있습니다.**

본 문서는 Cherri 언어의 한계를 극복하고 동적 날짜 조건으로 사진 백업 단축어를 빌드하기 위해, 단축어 앱에서 직접 필터를 걸어 추출한 파일을 분석하여 작동 가능한 Cherri 코드 및 서명 빌드 프로세스를 도출해낸 결과와 그 과정을 설명합니다.

---

## 2. 역추적 배경 및 필요성 (Rationale)

Cherri 언어는 네이티브 사진 관련 액션으로 단순 텍스트 사진 검색(`searchPhotos`)만 제공할 뿐, 특정 날짜 범위를 필터링하는 기능을 내장하고 있지 않습니다. 
따라서 특정 기간의 사진을 추출하여 백업하는 등의 복잡한 워크플로우를 구현하려면, iOS 내부 단축어 액션인 `is.workflow.actions.filter.photos`를 `rawAction()`을 통해 직접 호출하여 파라미터를 제어해야만 합니다.

---

## 3. 상세 역추적 분석 및 구현 예시 (Methodology & Implementation)

### Step 1: 수동 단축어 필터 설정 및 서명 제거
1. 아이폰 단축어 앱에서 **Find Photos** 액션의 날짜 범위 필터(`Creation Date`가 두 날짜 사이)를 직접 구성한 단축어 파일([FindPhotos.shortcut](file:///Users/yangeok/Dev/Test/i-cherri/experiments/FindPhotos.shortcut))을 Mac으로 가져옵니다.
2. iOS에서 내보낸 단축어는 Apple 서명(`signed`)이 적용되어 있으므로, 내부 plist를 온전히 분석하기 위해 **Cherri 개발 팀(0xilis)이 만든 오픈소스 단축어 서명 도구**인 [shortcut-sign](file:///Users/yangeok/Dev/Test/i-cherri/experiments/shortcut-sign)을 이용해 서명을 해제하여 **unsigned** 상태로 변환합니다.

#### 📦 `shortcut-sign` 빌드 방법
[0xilis/shortcut-sign](https://github.com/0xilis/shortcut-sign) 레포지토리를 복제한 뒤, `libplist`와 `OpenSSL`을 설치하고 컴파일합니다.
```bash
git clone --recursive https://github.com/0xilis/shortcut-sign.git
cd shortcut-sign
make
```

#### 🛠️ 서명 추출(Extract) 명령어
```bash
./shortcut-sign extract -i FindPhotos.shortcut -o FindPhotos_unsigned.shortcut
```

### Step 2: plist 구조 리버싱 및 분석 (JSON 파일 추출)
추출된 [FindPhotos_unsigned.shortcut](file:///Users/yangeok/Dev/Test/i-cherri/experiments/FindPhotos_unsigned.shortcut) 내부의 plist 데이터를 분석하여 가독성 높은 JSON 파일로 추출합니다. 이 작업을 수행하기 위해 `plutil` 도구를 활용하거나 파이썬 스크립트를 작성하여 실행합니다.

#### 쉘 유틸리티(plutil & jq)를 활용한 JSON 추출
```bash
# 1. plist 형식의 .shortcut 바이너리 파일을 전체 JSON 파일로 변환하여 추출
plutil -convert json -o shortcut.json FindPhotos_unsigned.shortcut

# 2. jq 유틸리티를 사용하여 'is.workflow.actions.filter.photos' 액션 정보만 골라 추출
jq '.WFWorkflowActions[] | select(.WFWorkflowActionIdentifier == "is.workflow.actions.filter.photos")' shortcut.json > find_photos_action.json
```

#### 파이썬 스크립트를 활용한 JSON 추출
전체 plist를 [shortcut.json](file:///Users/yangeok/Dev/Test/i-cherri/experiments/shortcut.json)으로 내보내고, 그 중 사진 필터링 액션 데이터만 골라 [find_photos_action.json](file:///Users/yangeok/Dev/Test/i-cherri/experiments/find_photos_action.json)으로 별도 저장하는 파이썬 예제 스크립트입니다.
```python
# 주석: .shortcut 바이너리 파일로부터 원하는 액션 파라미터를 JSON으로 파싱 및 저장하는 스크립트
import plistlib
import json

def extract_shortcut_to_json(shortcut_path, all_json_path, action_json_path):
    # 1. 서명 해제된 단축어 바이너리(plist 포맷) 읽기
    with open(shortcut_path, 'rb') as f:
        plist_data = plistlib.load(f)
        
    # 2. 전체 내용을 JSON 파일로 저장 (shortcut.json)
    with open(all_json_path, 'w', encoding='utf-8') as f:
        json.dump(plist_data, f, indent=2, ensure_ascii=False)
    print(f"전체 구조 추출 완료 -> {all_json_path}")
    
    # 3. 사진 필터 액션(filter.photos)만 탐색하여 별도 추출
    actions = plist_data.get("WFWorkflowActions", [])
    target_action_id = "is.workflow.actions.filter.photos"
    
    for action in actions:
        if action.get("WFWorkflowActionIdentifier") == target_action_id:
            with open(action_json_path, 'w', encoding='utf-8') as f:
                json.dump(action, f, indent=2, ensure_ascii=False)
            print(f"사진 필터 액션 데이터 추출 완료 -> {action_json_path}")
            return
            
    print(f"경고: {target_action_id} 액션을 찾을 수 없습니다.")

# 스크립트 실행부
extract_shortcut_to_json(
    "FindPhotos_unsigned.shortcut", 
    "shortcut.json", 
    "find_photos_action.json"
)
```

추출된 JSON 분석을 통해 파악한 파싱 결과 중 `is.workflow.actions.filter.photos` 식별자의 핵심 구조는 아래와 같습니다.

**파싱된 plist 핵심 구조:**
```json
{
  "WFWorkflowActionIdentifier": "is.workflow.actions.filter.photos",
  "WFWorkflowActionParameters": {
    "WFContentItemFilter": {
      "Value": {
        "WFActionParameterFilterPrefix": 1,
        "WFActionParameterFilterTemplates": [
          {
            "Operator": 1003, // 'is between' 연산자
            "Property": "Creation Date",
            "Removable": true,
            "Values": {
              "AnotherDate": 1779289140, // 정적 종료일 타임스탬프
              "Date": 1779202800,        // 정적 시작일 타임스탬프
              "Unit": 4
            }
          }
        ],
        "WFContentPredicateBoundedDate": false
      },
      "WFSerializationType": "WFContentPredicateTableTemplate"
    },
    "WFContentItemLimitEnabled": false
  }
}
```

### Step 3: Cherri 문법 제약 극복 및 코드 변환
위 plist의 정적 타임스탬프 자리에 Cherri 변수를 매핑하고 컴파일하는 과정에서 발견한 제약과 우회 기법입니다.

* **제약 1 (중첩 구조 내 변수 참조)**: Cherri는 중첩 dict 내에서 `"${startDate}"` 문자열 보간을 인식하지 못합니다.
  * **해결**: 단축어가 인식하는 `WFTextTokenAttachment` 구조를 JSON 내부에 수동으로 선언합니다.
* **제약 2 (출력 변수 대입 실패)**: `@allMedia = rawAction(...)` 대입문은 unknown action 컴파일 오류를 냅니다.
  * **해결**: `is.workflow.actions.setvariable`을 연계 호출하고 이전 출력 대상 이름(`OutputName: "Filter Photos"`)을 직접 참조합니다.

#### 🍒 리버싱 결과로 도출한 Cherri 코드 (`find-photos.cherri`)
```cherri
# filter.photos rawAction을 호출하여 사진 필터링 실행
rawAction("is.workflow.actions.filter.photos", {
    "WFContentItemFilter": {
        "Value": {
            "WFActionParameterFilterPrefix": 1,
            "WFActionParameterFilterTemplates": [
                {
                    "Operator": 1003,             # 1003 = 'is between' 연산
                    "Property": "Creation Date",
                    "Removable": true,
                    "Values": {
                        # 종료일 변수 주입 (중첩 dict이므로 WFTextTokenAttachment 명시)
                        "AnotherDate": {
                            "Value": { "Type": "Variable", "VariableName": "endDate" },
                            "WFSerializationType": "WFTextTokenAttachment"
                        },
                        # 시작일 변수 주입 (중첩 dict이므로 WFTextTokenAttachment 명시)
                        "Date": {
                            "Value": { "Type": "Variable", "VariableName": "startDate" },
                            "WFSerializationType": "WFTextTokenAttachment"
                        },
                        "Unit": 4
                    }
                }
            ],
            "WFContentPredicateBoundedDate": false
        },
        "WFSerializationType": "WFContentPredicateTableTemplate"
    },
    "WFContentItemLimitEnabled": false
})

# setvariable rawAction으로 직전 필터링 결과("Filter Photos")를 'allMedia' 변수에 할당
rawAction("is.workflow.actions.setvariable", {
    "WFVariableName": "allMedia",
    "WFInput": {
        "Value": {
            "OutputName": "Filter Photos",   # filter.photos 액션의 기본 출력명 지정
            "Type": "ActionOutput"
        },
        "WFSerializationType": "WFTextTokenAttachment"
    }
})
```

---

## 4. 활용 방안 및 향후 제안 (Future Recommendations)

1. **자동화 스크립트 활용**: Cherri 코드를 컴파일하고 [patch_and_sign.py](file:///Users/yangeok/Dev/Test/i-cherri/experiments/patch_and_sign.py) 및 `shortcut-sign`을 통해 빌드/서명을 자동화하여 단축어를 생성해 사용합니다.
2. **리버싱 패턴의 확장**: 이와 동일한 리버싱 워크플로우(수동 생성 → `shortcut-sign extract` → `plutil` 구조 분석 → 중첩 변수 `WFTextTokenAttachment` 수동 선언)를 적용하면, Cherri가 네이티브로 제공하지 않는 건강 데이터(Health), 위치 정보(Location) 등 다른 모든 iOS 전용 액션도 rawAction을 통해 무한히 연동하여 사용할 수 있습니다.

---

## 부록: 임시 산출물(JSON, Unsigned 파일) 복구 가이드

리버싱 과정에서 분석용으로 추출했던 임시 산출물들([FindPhotos_unsigned.shortcut](file:///Users/yangeok/Dev/Test/i-cherri/experiments/FindPhotos_unsigned.shortcut), [shortcut.json](file:///Users/yangeok/Dev/Test/i-cherri/experiments/shortcut.json), [find_photos_action.json](file:///Users/yangeok/Dev/Test/i-cherri/experiments/find_photos_action.json))은 디렉토리 정리 정돈을 위해 삭제 처리하였습니다.

향후 분석을 위해 해당 파일들이 다시 필요하다면, `experiments` 폴더 내에서 아래의 복구 스크립트 명령어를 실행하여 100% 동일하게 복원할 수 있습니다.

### 🛠️ 임시 파일 일괄 복구 스크립트
```bash
# 1. 원본 서명 단축어로부터 서명이 제거된 unsigned 단축어 데이터 복구
./shortcut-sign extract -i FindPhotos.shortcut -o FindPhotos_unsigned.shortcut

# 2. unsigned plist 단축어 데이터 전체를 가독성 높은 JSON 파일로 복구
plutil -convert json -o shortcut.json FindPhotos_unsigned.shortcut

# 3. 전체 JSON 데이터로부터 사진 필터(filter.photos) 액션 정보만 골라 JSON으로 복구
jq '.WFWorkflowActions[] | select(.WFWorkflowActionIdentifier == "is.workflow.actions.filter.photos")' shortcut.json > find_photos_action.json
```

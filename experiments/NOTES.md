# filter.photos rawAction 역추적 노트

## 왜 rawAction인가

Cherri에는 날짜 범위로 사진을 필터링하는 네이티브 액션이 없다.
`searchPhotos(text criteria)`가 유일한 네이티브 사진 액션이지만 텍스트 검색만 지원하고 날짜 범위를 못 쓴다.

iOS Shortcuts 내부 액션 `is.workflow.actions.filter.photos`가 날짜 범위 필터링을 지원하는데, Cherri가 이걸 바인딩하지 않아서 `rawAction()`으로 직접 호출해야 한다.

---

## 역추적 과정

### 1단계 — 실제 단축어 생성

iPhone Shortcuts 앱에서 "Find Photos" 액션을 써서 단축어 하나를 만들었다.  
날짜 범위 조건은 `Creation Date` / `is between` / 특정 두 날짜로 설정했다.

### 2단계 — 단축어 파일 추출 및 파싱

단축어를 Mac으로 내보낸 뒤 (`FindPhotos_unsigned.shortcut`), plist 구조를 읽었다:

```bash
plutil -p experiments/FindPhotos_unsigned.shortcut
```

출력:
```
"WFWorkflowActions" => [
  0 => {
    "WFWorkflowActionIdentifier" => "is.workflow.actions.filter.photos"
    "WFWorkflowActionParameters" => {
      "WFContentItemFilter" => {
        "Value" => {
          "WFActionParameterFilterPrefix" => 1
          "WFActionParameterFilterTemplates" => [
            0 => {
              "Operator" => 1003
              "Property" => "Creation Date"
              "Removable" => 1
              "Values" => {
                "AnotherDate" => 2026-05-20 14:59:00 +0000
                "Date"        => 2026-05-19 15:00:00 +0000
                "Unit"        => 4
              }
            }
          ]
          "WFContentPredicateBoundedDate" => 0
        }
        "WFSerializationType" => "WFContentPredicateTableTemplate"
      }
      "WFContentItemLimitEnabled" => 0
    }
  }
]
```

→ 최소 필드는 `WFContentItemFilter` + `WFContentItemLimitEnabled` 두 개뿐이다.  
→ UUID, CustomOutputName, sort 필드는 없다.

### 3단계 — Cherri rawAction으로 변환

plist에서 날짜는 하드코딩된 값이지만, 우리는 동적 변수가 필요하다.  
Shortcuts에서 변수를 액션 파라미터 안에 넣을 때 쓰는 포맷이 `WFTextTokenAttachment`다:

```json
"Date": {
    "Value": {
        "Type": "Variable",
        "VariableName": "startDate"
    },
    "WFSerializationType": "WFTextTokenAttachment"
}
```

`@variable` 이나 `"${variable}"` 을 rawAction JSON 안에 직접 쓰면 안 된다:

- `@startDate` → Cherri JSON 파서 오류
- `"${startDate}"` → `is.workflow.actions.rawaction` 이라는 가짜 액션 ID로 컴파일됨 (Shortcuts에서 unknown action)

### 4단계 — 출력 캡처

filter.photos는 결과를 바로 반환하지 않고 액션 출력으로 남긴다.  
이걸 변수로 담으려면 `is.workflow.actions.setvariable`을 체인으로 걸어야 한다.

UUID/CustomOutputName을 쓰면 특정 액션 출력을 UUID로 정확히 참조할 수 있지만, 불필요한 필드다. `OutputName: "Filter Photos"` (액션 기본 출력명)으로 충분하다:

```json
rawAction("is.workflow.actions.setvariable", {
    "WFVariableName": "allMedia",
    "WFInput": {
        "Value": {
            "OutputName": "Filter Photos",
            "Type": "ActionOutput"
        },
        "WFSerializationType": "WFTextTokenAttachment"
    }
})
```

---

## 최종 패턴 (현재 iphone_daily_backup.cherri)

```cherri
rawAction("is.workflow.actions.filter.photos", {
    "WFContentItemFilter": {
        "Value": {
            "WFActionParameterFilterPrefix": 1,
            "WFActionParameterFilterTemplates": [
                {
                    "Operator": 1003,
                    "Property": "Creation Date",
                    "Removable": true,
                    "Values": {
                        "AnotherDate": {
                            "Value": { "Type": "Variable", "VariableName": "endDate" },
                            "WFSerializationType": "WFTextTokenAttachment"
                        },
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
rawAction("is.workflow.actions.setvariable", {
    "WFVariableName": "allMedia",
    "WFInput": {
        "Value": {
            "OutputName": "Filter Photos",
            "Type": "ActionOutput"
        },
        "WFSerializationType": "WFTextTokenAttachment"
    }
})
```

---

## 주요 교훈

| 시도 | 결과 |
|---|---|
| `"Date": @startDate` | Cherri JSON 파서 오류 |
| `"Date": "${startDate}"` | `is.workflow.actions.rawaction` (unknown action) |
| `"Date": { WFTextTokenAttachment }` | `is.workflow.actions.filter.photos` 정상 컴파일 |
| `@result = rawAction(...)` 할당 문법 | `is.workflow.actions.rawaction` (unknown action) |
| UUID + CustomOutputName 포함 | 동작하지만 plist 원본에 없는 불필요 필드 |
| `OutputName: "Filter Photos"` 참조 | UUID 없이도 출력 캡처 가능 |

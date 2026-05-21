#!/usr/bin/env python3
"""
patch_and_sign.py: Cherri 컴파일된 unsigned shortcut의 formRequest에서
"file" 키 form 필드를 WFItemType=1 (File) + WFTextTokenAttachment로 변환 후 HubSign 서명.

Usage: python3 patch_and_sign.py input_unsigned.shortcut output_signed.shortcut
"""

import plistlib
import sys
import urllib.request

HUBSIGN_URL = "https://hubsign.routinehub.services/sign"
HUBSIGN_BOUNDARY = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
FILE_FORM_KEYS = {"file"}


def patch(data: dict) -> int:
    """WFFormValues 내 FILE_FORM_KEYS 필드를 WFItemType=1 + WFTextTokenAttachment로 변환."""
    patched = 0
    for action in data.get("WFWorkflowActions", []):
        if action.get("WFWorkflowActionIdentifier") != "is.workflow.actions.downloadurl":
            continue
        params = action.get("WFWorkflowActionParameters", {})
        if params.get("WFHTTPBodyType") != "Form":
            continue

        items = (
            params
            .get("WFFormValues", {})
            .get("Value", {})
            .get("WFDictionaryFieldValueItems", [])
        )
        for item in items:
            key_str = item.get("WFKey", {}).get("Value", {}).get("string", "")
            if key_str not in FILE_FORM_KEYS:
                continue

            # "{@item}" → attachmentsByRange에서 변수명 추출
            wf_value = item.get("WFValue", {})
            value_content = wf_value.get("Value", {})
            attachments = value_content.get("attachmentsByRange", {})

            var_name = None
            output_uuid = None
            output_name = None
            for _, att in attachments.items():
                if att.get("Type") == "Variable":
                    var_name = att.get("VariableName")
                    break
                if att.get("Type") == "ActionOutput":
                    output_uuid = att.get("OutputUUID")
                    output_name = att.get("OutputName")
                    break

            if var_name:
                new_value = {
                    "Value": {"Type": "Variable", "VariableName": var_name},
                    "WFSerializationType": "WFTextTokenAttachment",
                }
            elif output_uuid:
                new_value = {
                    "Value": {
                        "OutputName": output_name,
                        "OutputUUID": output_uuid,
                        "Type": "ActionOutput",
                    },
                    "WFSerializationType": "WFTextTokenAttachment",
                }
            else:
                print(f"  [warn] '{key_str}' 필드에서 변수 참조를 찾을 수 없음, 건너뜀", file=sys.stderr)
                continue

            item["WFItemType"] = 1
            item["WFValue"] = new_value
            patched += 1
            print(f"  patched field '{key_str}' → WFItemType=1 (var={var_name or output_uuid})")

    return patched


def hubsign(shortcut_bytes: bytes) -> bytes:
    body = (
        b"--" + HUBSIGN_BOUNDARY.encode() + b"\r\n"
        b'Content-Disposition: form-data; name="shortcut"; filename="shortcut.shortcut"\r\n'
        b"Content-Type: application/octet-stream\r\n\r\n"
        + shortcut_bytes
        + b"\r\n--" + HUBSIGN_BOUNDARY.encode() + b"--\r\n"
    )
    req = urllib.request.Request(
        HUBSIGN_URL,
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={HUBSIGN_BOUNDARY}",
            "User-Agent": "cherri/2.2.0",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input_unsigned.shortcut output_signed.shortcut")
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]

    with open(in_path, "rb") as f:
        raw = f.read()

    data = plistlib.loads(raw)
    n = patch(data)
    print(f"패치 완료: {n}개 필드 변환")

    patched_bytes = plistlib.dumps(data, fmt=plistlib.FMT_BINARY)

    print("HubSign 서명 중...")
    signed = hubsign(patched_bytes)

    with open(out_path, "wb") as f:
        f.write(signed)
    print(f"서명 완료 → {out_path} ({len(signed)} bytes)")


if __name__ == "__main__":
    main()

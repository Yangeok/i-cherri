#!/usr/bin/env python3
"""
organize_by_month.py
아이폰 직결 백업 파일을 YYYY-MM 폴더로 분류.

사용법:
  python3 organize_by_month.py <src_dir> [dst_dir] [--copy] [--dry-run]

  src_dir  : 백업된 파일이 있는 디렉터리
  dst_dir  : 정리할 대상 디렉터리 (생략 시 src_dir 내에 정리)
  --copy   : 이동 대신 복사
  --dry-run: 실제로 파일을 건드리지 않고 결과만 출력

날짜 추출 우선순위:
  1. JPEG/HEIC EXIF DateTimeOriginal
  2. MP4/MOV mvhd 박스 creation_time
  3. 파일 수정일
"""

import os
import re
import sys
import struct
import shutil
import datetime
import argparse
from pathlib import Path

PHOTO_EXTS = {'.jpg', '.jpeg', '.heic', '.heif', '.png', '.dng', '.tiff', '.tif', '.webp'}
VIDEO_EXTS = {'.mov', '.mp4', '.m4v', '.avi', '.mkv'}
ALL_EXTS   = PHOTO_EXTS | VIDEO_EXTS

# ── JPEG / HEIC EXIF ────────────────────────────────────────────────────────

def _read_exif_date_jpeg(path: Path) -> datetime.datetime | None:
    """JPEG APP1 EXIF에서 DateTimeOriginal(0x9003) 파싱."""
    try:
        with open(path, 'rb') as f:
            if f.read(2) != b'\xff\xd8':
                return None
            while True:
                marker = f.read(2)
                if len(marker) < 2:
                    break
                if marker[0] != 0xff:
                    break
                seg_len = struct.unpack('>H', f.read(2))[0] - 2
                if marker[1] == 0xe1:   # APP1
                    data = f.read(seg_len)
                    return _parse_exif_block(data)
                else:
                    f.seek(seg_len, 1)
    except Exception:
        pass
    return None

def _parse_exif_block(data: bytes) -> datetime.datetime | None:
    if data[:4] not in (b'Exif', b'Exif'):
        return None
    if data[4:6] != b'\x00\x00':
        return None
    tiff = data[6:]
    byte_order = tiff[:2]
    if byte_order == b'II':
        endian = '<'
    elif byte_order == b'MM':
        endian = '>'
    else:
        return None

    def u16(off): return struct.unpack_from(endian + 'H', tiff, off)[0]
    def u32(off): return struct.unpack_from(endian + 'I', tiff, off)[0]

    ifd0_off = u32(4)
    # IFD0: look for ExifIFD pointer (0x8769)
    exif_ifd_off = None
    n = u16(ifd0_off)
    for i in range(n):
        entry = ifd0_off + 2 + i * 12
        tag = u16(entry)
        if tag == 0x8769:
            exif_ifd_off = u32(entry + 8)
            break

    # Search IFD0 and ExifIFD for DateTimeOriginal (0x9003) or DateTime (0x0132)
    for ifd_off in filter(None, [ifd0_off, exif_ifd_off]):
        try:
            n = u16(ifd_off)
        except Exception:
            continue
        for i in range(n):
            entry = ifd_off + 2 + i * 12
            try:
                tag = u16(entry)
            except Exception:
                continue
            if tag in (0x9003, 0x9004, 0x0132):
                count = u32(entry + 4)
                val_off = u32(entry + 8) if count > 4 else entry + 8
                try:
                    raw = tiff[val_off:val_off + 19].decode('ascii', errors='ignore')
                    return _parse_exif_datetime(raw)
                except Exception:
                    pass
    return None

def _parse_exif_datetime(s: str) -> datetime.datetime | None:
    s = s.strip('\x00').strip()
    for fmt in ('%Y:%m:%d %H:%M:%S', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None

def _read_exif_date_heic(path: Path) -> datetime.datetime | None:
    """HEIC/HEIF: ftyp → meta → iinf → Exif item → 파싱."""
    try:
        with open(path, 'rb') as f:
            data = f.read()
        return _search_exif_in_heic(data)
    except Exception:
        return None

def _search_exif_in_heic(data: bytes) -> datetime.datetime | None:
    # Scan for Exif marker and try to parse TIFF block after it
    idx = 0
    while True:
        pos = data.find(b'Exif\x00\x00', idx)
        if pos == -1:
            break
        result = _parse_exif_block(data[pos:pos + 65536])
        if result:
            return result
        idx = pos + 1
    return None

# ── MP4 / MOV mvhd ──────────────────────────────────────────────────────────

_MAC_EPOCH = datetime.datetime(1904, 1, 1)

def _read_date_video(path: Path) -> datetime.datetime | None:
    """MP4/MOV の mvhd box から creation_time を取得."""
    try:
        with open(path, 'rb') as f:
            return _parse_mp4_boxes(f)
    except Exception:
        return None

def _parse_mp4_boxes(f, limit: int = 0, depth: int = 0) -> datetime.datetime | None:
    if depth > 6:
        return None
    start = f.tell()
    while True:
        hdr = f.read(8)
        if len(hdr) < 8:
            break
        size, box = struct.unpack('>I4s', hdr)
        if size == 1:
            size = struct.unpack('>Q', f.read(8))[0]
            data_size = size - 16
        elif size == 0:
            break
        else:
            data_size = size - 8

        pos = f.tell()
        if box in (b'moov', b'udta', b'meta', b'ilst'):
            result = _parse_mp4_boxes(f, data_size, depth + 1)
            if result:
                return result
        elif box == b'mvhd':
            raw = f.read(min(data_size, 28))
            version = raw[0]
            if version == 1 and len(raw) >= 25:
                ts = struct.unpack('>Q', raw[8:16])[0]
            elif version == 0 and len(raw) >= 13:
                ts = struct.unpack('>I', raw[4:8])[0]
            else:
                ts = 0
            if ts > 0:
                dt = _MAC_EPOCH + datetime.timedelta(seconds=ts)
                if 2000 <= dt.year <= 2100:
                    return dt
        f.seek(pos + data_size)
        if limit and f.tell() >= start + limit:
            break
    return None

# ── 날짜 추출 진입점 ─────────────────────────────────────────────────────────

def get_date(path: Path) -> datetime.datetime:
    ext = path.suffix.lower()
    dt = None

    if ext in ('.jpg', '.jpeg'):
        dt = _read_exif_date_jpeg(path)
    elif ext in ('.heic', '.heif'):
        dt = _read_exif_date_heic(path)
    elif ext in VIDEO_EXTS:
        dt = _read_date_video(path)

    if dt is None:
        dt = datetime.datetime.fromtimestamp(path.stat().st_mtime)

    return dt

# ── 정리 로직 ────────────────────────────────────────────────────────────────

def unique_path(dst: Path) -> Path:
    if not dst.exists():
        return dst
    stem, suffix = dst.stem, dst.suffix
    i = 1
    while True:
        candidate = dst.with_name(f"{stem}_{i}{suffix}")
        if not candidate.exists():
            return candidate
        i += 1

def organize(src_dir: Path, dst_dir: Path, copy: bool, dry_run: bool):
    files = [
        p for p in src_dir.rglob('*')
        if p.is_file() and p.suffix.lower() in ALL_EXTS
    ]
    if not files:
        print("파일 없음.")
        return

    ok = skip = err = 0
    for p in sorted(files):
        try:
            dt = get_date(p)
            folder = dst_dir / dt.strftime('%Y-%m')
            dst = unique_path(folder / p.name)

            action = 'copy' if copy else 'move'
            print(f"[{action}] {p.relative_to(src_dir)}  →  {dst.relative_to(dst_dir)}")

            if not dry_run:
                folder.mkdir(parents=True, exist_ok=True)
                if copy:
                    shutil.copy2(p, dst)
                else:
                    shutil.move(str(p), dst)
            ok += 1
        except Exception as e:
            print(f"[skip] {p.name}: {e}")
            err += 1

    label = '(dry-run) ' if dry_run else ''
    print(f"\n{label}완료: {ok}개 처리, {err}개 오류, {skip}개 건너뜀")

# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description='아이폰 백업 파일을 YYYY-MM 폴더로 분류')
    ap.add_argument('src', help='원본 디렉터리')
    ap.add_argument('dst', nargs='?', help='대상 디렉터리 (생략 시 src와 동일)')
    ap.add_argument('--copy',    action='store_true', help='이동 대신 복사')
    ap.add_argument('--dry-run', action='store_true', help='실제 파일 조작 없이 결과만 출력')
    args = ap.parse_args()

    src = Path(args.src).expanduser().resolve()
    dst = Path(args.dst).expanduser().resolve() if args.dst else src

    if not src.is_dir():
        print(f"오류: {src} 는 디렉터리가 아님")
        sys.exit(1)

    print(f"src: {src}")
    print(f"dst: {dst}")
    print(f"mode: {'copy' if args.copy else 'move'} {'[dry-run]' if args.dry_run else ''}\n")

    organize(src, dst, copy=args.copy, dry_run=args.dry_run)

if __name__ == '__main__':
    main()

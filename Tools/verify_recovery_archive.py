#!/usr/bin/env python3
"""Offline DreamLife House recovery export verifier; never uploads or prints save data.

Exit 0: format v2 verified; 2: legacy v1 (no checksums); 1: invalid.
CRC32 detects accidental damage, not malicious edits or file authenticity.
"""
import argparse
import base64
import binascii
import json
from pathlib import Path
import zlib


class InvalidArchive(ValueError):
    pass


def unique_pairs(pairs):
    output = {}
    for key, value in pairs:
        if key in output:
            raise InvalidArchive(f"Duplicate JSON key: {key}")
        output[key] = value
    return output


def verify(payload: bytes) -> str:
    if len(payload) > 64 * 1024 * 1024:
        raise InvalidArchive("Archive exceeds offline verification size limit")
    try:
        obj = json.loads(payload, object_pairs_hook=unique_pairs)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise InvalidArchive("Invalid JSON") from exc
    if not isinstance(obj, dict):
        raise InvalidArchive("Archive root must be an object")
    version = obj.get("formatVersion")
    if type(version) is not int or version not in (1, 2):
        raise InvalidArchive("Unsupported archive format")
    if obj.get("reason") != "ambiguous-equal-sequence":
        raise InvalidArchive("Unexpected recovery reason")
    slots = obj.get("slots")
    if not isinstance(slots, list) or len(slots) != 3:
        raise InvalidArchive("Expected three recovery slots")
    if [slot.get("name") if isinstance(slot, dict) else None for slot in slots] != ["primary", "backup", "pending"]:
        raise InvalidArchive("Recovery slots missing, duplicated or reordered")
    for slot in slots:
        encoded = slot.get("bytes")
        if encoded is not None and not isinstance(encoded, str):
            raise InvalidArchive("Slot bytes must be Base64 or absent")
        if encoded is None:
            expected = "absent"
        else:
            try:
                raw = base64.b64decode(encoded, validate=True)
            except (ValueError, binascii.Error) as exc:
                raise InvalidArchive("Invalid Base64 in recovery slot") from exc
            expected = f"crc32:{zlib.crc32(raw):08X}:{len(raw)}"
        if version == 2 and slot.get("checksum") != expected:
            raise InvalidArchive(f"Checksum mismatch for {slot['name']} slot")
    return "verified" if version == 2 else "legacy-unverified"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        status = verify(args.archive.read_bytes())
    except (OSError, InvalidArchive) as exc:
        print(f"INVALID: {exc}")
        return 1
    if status == "verified":
        print("VERIFIED: format v2, all three recovery slots passed CRC32 checks (not authentication).")
        return 0
    print("LEGACY: format v1 has no checksums; integrity cannot be verified.")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

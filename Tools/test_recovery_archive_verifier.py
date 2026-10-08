import base64
import json
from pathlib import Path
import sys
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_recovery_archive import verify, InvalidArchive


def slot(name, raw):
    return {"name": name, "bytes": None if raw is None else base64.b64encode(raw).decode(),
            "checksum": "absent" if raw is None else f"crc32:{zlib.crc32(raw):08X}:{len(raw)}"}


def archive(version=2):
    return {"formatVersion": version, "reason": "ambiguous-equal-sequence",
            "slots": [slot("primary", None), slot("backup", b"\x00\xff\x80"), slot("pending", b"")]}


def encoded(data):
    return json.dumps(data, sort_keys=True).encode()


class RecoveryArchiveVerifierTests(unittest.TestCase):
    def test_valid_v2(self):
        self.assertEqual(verify(encoded(archive())), "verified")

    def test_v1_decodes_but_is_not_verified(self):
        old = archive(1)
        for s in old["slots"]:
            del s["checksum"]
        self.assertEqual(verify(encoded(old)), "legacy-unverified")

    def test_modified_base64_is_rejected(self):
        obj = archive()
        obj["slots"][1]["bytes"] = base64.b64encode(b"different").decode()
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_missing_checksum_is_rejected(self):
        obj = archive()
        del obj["slots"][0]["checksum"]
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_empty_and_absent_are_not_interchangeable(self):
        obj = archive()
        obj["slots"][0]["bytes"] = ""
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_wrong_order(self):
        obj = archive()
        obj["slots"].reverse()
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_invalid_base64(self):
        obj = archive()
        obj["slots"][2]["bytes"] = "not*base64"
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_duplicate_json_keys(self):
        payload = encoded(archive()).replace(b'"formatVersion": 2', b'"formatVersion": 2, "formatVersion": 2')
        with self.assertRaises(InvalidArchive): verify(payload)

    def test_unsupported_format(self):
        obj = archive(3)
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_missing_slot(self):
        obj = archive()
        obj["slots"].pop()
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_wrong_reason(self):
        obj = archive()
        obj["reason"] = "unknown"
        with self.assertRaises(InvalidArchive): verify(encoded(obj))

    def test_malformed_json(self):
        with self.assertRaises(InvalidArchive): verify(b"{")


if __name__ == "__main__":
    unittest.main()

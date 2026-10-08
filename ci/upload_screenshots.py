#!/usr/bin/env python3
"""Upload App Store screenshots for the editable iOS version via the App Store Connect API.

Usage: upload_screenshots.py <dir-with-iphone-pngs> <dir-with-ipad-pngs>
Env: ASC_KEY_ID, ASC_ISSUER_ID, KEY_PATH, BUNDLE_ID, LOCALE (default tr)
Existing screenshots in the target sets are replaced.
"""
import hashlib, json, os, sys, time, urllib.request, urllib.error
import jwt

API = "https://api.appstoreconnect.apple.com/v1"
KID = os.environ["ASC_KEY_ID"].replace("AuthKey_", "").replace(".p8", "").strip()
ISS = os.environ["ASC_ISSUER_ID"].strip()
KEY = open(os.environ["KEY_PATH"]).read()
BUNDLE = os.environ.get("BUNDLE_ID", "com.birolseker.dreamlifehouse")
LOCALE = os.environ.get("LOCALE", "tr")


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISS, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KID})


def call(method, url, body=None, raw=None, headers=None):
    if not url.startswith("http"):
        url = API + url
    h = {"Authorization": "Bearer " + token()}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        h["Content-Type"] = "application/json"
    if raw is not None:
        data = raw
        h = headers or {}
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read()
            return json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        print(f"::error::{method} {url} -> {e.code} {e.read().decode()[:500]}")
        raise


def main(iphone_dir, ipad_dir):
    app = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]
    versions = call("GET", f"/apps/{app['id']}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in
                ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    version = (editable or versions)[0]
    locs = call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"].lower().startswith(LOCALE)), locs[0])
    print("Version", version["attributes"]["versionString"], "locale", loc["attributes"]["locale"])

    sets = call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    for display, folder in (("APP_IPHONE_67", iphone_dir), ("APP_IPAD_PRO_3GEN_129", ipad_dir)):
        files = sorted(f for f in os.listdir(folder) if f.lower().endswith(".png"))[:10]
        if not files:
            print("No screenshots in", folder); continue
        sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display), None)
        if sset is None:
            sset = call("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
        for old in call("GET", f"/appScreenshotSets/{sset['id']}/appScreenshots")["data"]:
            call("DELETE", f"/appScreenshots/{old['id']}")
        for name in files:
            path = os.path.join(folder, name)
            blob = open(path, "rb").read()
            shot = call("POST", "/appScreenshots", {"data": {"type": "appScreenshots",
                "attributes": {"fileName": name, "fileSize": len(blob)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
            for op in shot["attributes"]["uploadOperations"]:
                part = blob[op["offset"]:op["offset"] + op["length"]]
                hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                call(op["method"], op["url"], raw=part, headers=hdrs)
            call("PATCH", f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            print("Uploaded", display, name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

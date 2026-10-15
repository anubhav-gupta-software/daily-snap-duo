#!/usr/bin/env python3
"""A tiny relay for Daily Snap Duo.

Run it on your Mac, then point both phones at http://<mac-ip>:8787.
The invite code is the only credential. Don't put this on the public internet
with photos you care about.

    python3 sync-server/server.py
"""

from __future__ import annotations

import base64
import json
import re
import socket
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent / "data"
HOST = "0.0.0.0"
PORT = 8787
MAX_BODY = 12 * 1024 * 1024
CODE_RE = re.compile(r"^[A-Z0-9]{6}$")
LOCK = threading.Lock()


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(value: str) -> str:
    # Keep the client's timestamp, but reject anything that isn't a date.
    cleaned = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(cleaned)
    return parsed.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def pair_dir(code: str) -> Path:
    return ROOT / code


def read_pair(code: str) -> dict | None:
    path = pair_dir(code) / "pair.json"
    if not path.exists():
        return None
    return json.loads(path.read_text())


def write_pair(pair: dict) -> None:
    directory = pair_dir(pair["code"])
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "pair.json").write_text(json.dumps(pair, indent=2))


def snap_meta_path(code: str, snap_id: str) -> Path:
    return pair_dir(code) / "snaps" / f"{snap_id}.json"


def public_pair(pair: dict) -> dict:
    snaps = []
    snap_dir = pair_dir(pair["code"]) / "snaps"
    if snap_dir.exists():
        for path in sorted(snap_dir.glob("*.json")):
            meta = json.loads(path.read_text())
            snaps.append(
                {
                    "id": meta["id"],
                    "dayKey": meta["dayKey"],
                    "authorId": meta["authorId"],
                    "authorName": meta["authorName"],
                    "capturedAt": meta["capturedAt"],
                    "onTime": meta["onTime"],
                }
            )
    return {
        "code": pair["code"],
        "timeZone": pair["timeZone"],
        "createdAt": pair["createdAt"],
        "members": pair["members"],
        "snaps": snaps,
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        parts = self.parts()
        if len(parts) == 3 and parts[:2] == ["v1", "pairs"] and CODE_RE.match(parts[2]):
            with LOCK:
                pair = read_pair(parts[2])
            if pair is None:
                self.finish_json(404, {"error": "No duo with that code yet."})
                return
            self.finish_json(200, public_pair(pair))
            return
        if (
            len(parts) == 5
            and parts[:2] == ["v1", "pairs"]
            and parts[3] == "snaps"
            and CODE_RE.match(parts[2])
        ):
            path = snap_meta_path(parts[2], parts[4])
            with LOCK:
                if not path.exists():
                    self.finish_json(404, {"error": "That snap isn't on the relay."})
                    return
                payload = json.loads(path.read_text())
            self.finish_json(200, payload)
            return
        self.finish_json(404, {"error": "Not found."})

    def do_POST(self) -> None:
        parts = self.parts()
        try:
            body = self.read_json()
        except ValueError as error:
            self.finish_json(400, {"error": str(error)})
            return

        if parts == ["v1", "pairs"]:
            self.create_or_join(body)
            return
        if len(parts) == 4 and parts[:2] == ["v1", "pairs"] and parts[3] == "snaps" and CODE_RE.match(parts[2]):
            self.save_snap(parts[2], body)
            return
        self.finish_json(404, {"error": "Not found."})

    def create_or_join(self, body: dict) -> None:
        code = str(body.get("code", "")).upper()
        member = body.get("member") or {}
        if not CODE_RE.match(code):
            self.finish_json(400, {"error": "The invite code should be 6 letters or numbers."})
            return
        member_id = str(member.get("id", "")).strip()
        name = str(member.get("displayName", "")).strip()[:24]
        if not member_id or not name:
            self.finish_json(400, {"error": "Add a name before joining."})
            return
        try:
            created = parse_iso(str(body.get("createdAt") or now_iso()))
        except ValueError:
            created = now_iso()
        zone = str(body.get("timeZone") or "UTC")[:80]

        with LOCK:
            pair = read_pair(code)
            if pair is None:
                pair = {
                    "code": code,
                    "timeZone": zone,
                    "createdAt": created,
                    "members": [],
                }
            members = pair["members"]
            found = False
            for existing in members:
                if existing["id"] == member_id:
                    existing["displayName"] = name
                    existing["isSample"] = False
                    found = True
            if not found:
                members.append({"id": member_id, "displayName": name, "isSample": False})
            write_pair(pair)
            payload = public_pair(pair)
        self.finish_json(200, payload)

    def save_snap(self, code: str, body: dict) -> None:
        snap_id = str(body.get("id", "")).strip()
        if not snap_id:
            self.finish_json(400, {"error": "Missing snap id."})
            return
        with LOCK:
            if read_pair(code) is None:
                self.finish_json(404, {"error": "Create the duo before posting."})
                return
            path = snap_meta_path(code, snap_id)
            if path.exists():
                payload = json.loads(path.read_text())
                self.finish_json(200, payload)
                return
            try:
                back = base64.b64decode(body.get("backBase64") or "", validate=True)
                front = base64.b64decode(body.get("frontBase64") or "", validate=True)
            except Exception:
                self.finish_json(400, {"error": "The photos weren't valid."})
                return
            if not back or not front:
                self.finish_json(400, {"error": "A snap needs both photos."})
                return
            try:
                captured = parse_iso(str(body.get("capturedAt") or now_iso()))
            except ValueError:
                captured = now_iso()
            payload = {
                "id": snap_id,
                "dayKey": str(body.get("dayKey", "")),
                "authorId": str(body.get("authorId", "")),
                "authorName": str(body.get("authorName", ""))[:24],
                "capturedAt": captured,
                "onTime": bool(body.get("onTime", False)),
                "backBase64": base64.b64encode(back).decode("ascii"),
                "frontBase64": base64.b64encode(front).decode("ascii"),
            }
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(payload))
        self.finish_json(200, payload)

    def parts(self) -> list[str]:
        parsed = urlparse(self.path)
        return [part for part in parsed.path.split("/") if part]

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BODY:
            raise ValueError("That request was empty or too large.")
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError as error:
            raise ValueError("The relay expected JSON.") from error
        if not isinstance(body, dict):
            raise ValueError("The relay expected a JSON object.")
        return body

    def finish_json(self, status: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, fmt: str, *args) -> None:
        print("%s - %s" % (self.address_string(), fmt % args))


def lan_addresses() -> list[str]:
    addresses = set()
    try:
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.connect(("8.8.8.8", 80))
        addresses.add(probe.getsockname()[0])
        probe.close()
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            addresses.add(info[4][0])
    except OSError:
        pass
    addresses.discard("127.0.0.1")
    return sorted(addresses)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Daily Snap Duo relay on port {PORT}")
    found = lan_addresses()
    if found:
        for address in found:
            print(f"  on your phones, use http://{address}:{PORT}")
    else:
        print(f"  on your phones, use http://<this-mac-ip>:{PORT}")
    print("Press Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()


if __name__ == "__main__":
    main()

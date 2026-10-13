#!/usr/bin/env python3
"""Opt-in development relay. RAM-only display state; no Health samples or credentials."""
import argparse
from datetime import datetime, timezone
import hmac
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class RelayServer(ThreadingHTTPServer):
    def __init__(self, address, phone_token, companion_token):
        super().__init__(address, Handler)
        self.phone_token = phone_token
        self.companion_token = companion_token
        self.state = None
        self.commands = {}
        self.results = {}
        self.lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # Never log tokens or user action titles.

    def role(self):
        token = self.headers.get("Authorization", "").removeprefix("Bearer ")
        if hmac.compare_digest(token, self.server.phone_token): return "phone"
        if hmac.compare_digest(token, self.server.companion_token): return "companion"
        return None

    def reply(self, status, value):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def fresh(self):
        try:
            stamp = datetime.fromisoformat(self.server.state["asOf"].replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - stamp).total_seconds()
            return -10 <= age < 120
        except (TypeError, KeyError, ValueError): return False

    def do_GET(self):
        role = self.role()
        if not role: return self.reply(401, {"error": "unauthorized"})
        with self.server.lock:
            if self.path == "/state":
                return self.reply(200, self.server.state) if self.server.state else self.reply(503, {"error": "waiting for iPhone"})
            if self.path == "/commands" and role == "phone":
                self.server.commands = {key: value for key, value in self.server.commands.items() if time.monotonic() - value[0] < 30}
                return self.reply(200, [value[1] for value in self.server.commands.values()])
            if self.path.startswith("/ack/"):
                return self.reply(200, self.server.results.get(self.path[5:], {"status": "pending or expired"}))
        self.reply(404, {"error": "not found"})

    def do_POST(self):
        role = self.role()
        if not role: return self.reply(401, {"error": "unauthorized"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 100_000: return self.reply(413, {"error": "invalid size"})
            value = json.loads(self.rfile.read(length))
            if not isinstance(value, dict): raise ValueError()
        except (ValueError, json.JSONDecodeError): return self.reply(400, {"error": "invalid JSON"})
        with self.server.lock:
            if self.path == "/state" and role == "phone":
                if value.get("version") != 1 or not all(k in value for k in ("asOf", "periods", "actions", "dayStart", "dayEnd")):
                    return self.reply(400, {"error": "unsupported projection"})
                if self.server.state and value["asOf"] < self.server.state["asOf"]:
                    return self.reply(409, {"error": "older projection"})
                self.server.state = value
                return self.reply(200, {"status": "published"})
            if self.path == "/command" and role == "companion":
                if not self.fresh(): return self.reply(409, {"error": "stale iPhone"})
                if value.get("type") not in ("start", "pause", "resume", "complete") or not isinstance(value.get("id"), str) or not value.get("actionID"):
                    return self.reply(400, {"error": "invalid command"})
                key = value["id"]
                if key in self.server.results: return self.reply(200, self.server.results[key])
                if len(self.server.commands) >= 32: return self.reply(429, {"error": "queue full"})
                self.server.commands.setdefault(key, (time.monotonic(), value))
                return self.reply(202, {"id": key, "status": "awaiting iPhone"})
            if self.path == "/ack" and role == "phone":
                key = value.get("id")
                if key not in self.server.commands: return self.reply(409, {"error": "unknown command"})
                self.server.commands.pop(key)
                self.server.results[key] = value
                if len(self.server.results) > 256: self.server.results.pop(next(iter(self.server.results)))
                return self.reply(200, {"status": "acknowledged"})
        self.reply(403, {"error": "role cannot perform this operation"})

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    phone = os.environ.get("TIMEBITE_PHONE_TOKEN", "")
    companion = os.environ.get("TIMEBITE_COMPANION_TOKEN", "")
    if min(len(phone), len(companion)) < 32 or phone == companion:
        parser.error("Set distinct TIMEBITE_PHONE_TOKEN and TIMEBITE_COMPANION_TOKEN values (32+ characters).")
    print(f"TimeBite development relay on {args.host}:{args.port}; keep iPhone app open.")
    RelayServer((args.host, args.port), phone, companion).serve_forever()

if __name__ == "__main__": main()

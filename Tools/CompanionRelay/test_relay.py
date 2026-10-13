import json
import threading
import unittest
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from relay import RelayServer

class RelayTests(unittest.TestCase):
    def setUp(self):
        self.server = RelayServer(("127.0.0.1", 0), "p" * 32, "c" * 32)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()
    def request(self, path, token, value=None):
        headers = {"Authorization": "Bearer " + token}
        data = None if value is None else json.dumps(value).encode()
        request = Request(f"http://127.0.0.1:{self.server.server_port}" + path, data=data, headers=headers)
        try:
            with urlopen(request) as response: return response.status, json.load(response)
        except HTTPError as error: return error.code, json.load(error)
    def state(self, as_of=None):
        return {"version": 1, "asOf": as_of or datetime.now(timezone.utc).isoformat(), "dayStart": "today", "dayEnd": "tomorrow", "periods": [], "actions": []}
    def test_role_boundaries_and_no_state(self):
        self.assertEqual(self.request("/state", "wrong")[0], 401)
        self.assertEqual(self.request("/state", "c" * 32)[0], 503)
        self.assertEqual(self.request("/state", "c" * 32, self.state())[0], 403)
    def test_round_trip_ack_duplicate_and_expiry(self):
        self.assertEqual(self.request("/state", "p" * 32, self.state())[0], 200)
        command = {"id": "unique-command", "type": "pause", "actionID": "action"}
        self.assertEqual(self.request("/command", "c" * 32, command)[0], 202)
        self.assertEqual(self.request("/command", "c" * 32, command)[0], 202)
        self.assertEqual(len(self.request("/commands", "p" * 32)[1]), 1)
        result = {"id": command["id"], "status": "applied"}
        self.assertEqual(self.request("/ack", "p" * 32, result)[0], 200)
        self.assertEqual(self.request("/ack/" + command["id"], "c" * 32)[1], result)
        self.assertEqual(self.request("/commands", "p" * 32)[1], [])
        self.assertEqual(self.request("/command", "c" * 32, command)[1], result)
        self.server.state["asOf"] = "2000-01-01T00:00:00Z"
        self.assertEqual(self.request("/command", "c" * 32, {**command, "id": "new"})[0], 409)

if __name__ == "__main__": unittest.main()

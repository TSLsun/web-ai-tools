#!/usr/bin/env python3
import json
import subprocess
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

CONFIG_PATH = os.path.expanduser("~/.config/newssummarizer/config.json")
PORT = 8765


def load_secret() -> str:
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f).get("secret", "")
    except FileNotFoundError:
        print(f"Config not found at {CONFIG_PATH}. Run setup.sh first.", file=sys.stderr)
        sys.exit(1)


SECRET = load_secret()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/summarize":
            self._respond(404, {"error": "not_found"})
            return

        if self.headers.get("X-Secret") != SECRET:
            self._respond(401, {"error": "unauthorized"})
            return

        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))

        clean_text = body.get("cleanText", "")[:4000]
        language = body.get("language", "zh-TW")
        url = body.get("url", "")

        prompt = (
            f"Summarize the following article in {language}.\n"
            "Return ONLY valid JSON with no markdown, no code fences:\n"
            '{"title": "article title", "bullets": ["point 1", "point 2", "point 3"]}\n\n'
            f"Article:\n{clean_text}"
        )

        try:
            result = subprocess.run(
                ["claude", "-p", prompt],
                capture_output=True, text=True, timeout=30
            )
            raw = result.stdout.strip()
            # Strip markdown code fences if claude wraps in ```json ... ```
            if raw.startswith("```"):
                raw = "\n".join(raw.split("\n")[1:-1])
            summary = json.loads(raw)
            summary["url"] = url
            self._respond(200, summary)
        except subprocess.TimeoutExpired:
            self._respond(504, {"error": "claude_timeout"})
        except json.JSONDecodeError:
            self._respond(500, {"error": "parse_failed", "raw": result.stdout[:200]})

    def _respond(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(payload))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        pass  # suppress per-request logs


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"NewsSummarizer server listening on port {PORT}", flush=True)
    server.serve_forever()

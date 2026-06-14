#!/usr/bin/env python3
import json
import subprocess
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

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
        client = self.client_address[0]

        if self.path != "/summarize":
            log(f"404 {client} {self.path}")
            self._respond(404, {"error": "not_found"})
            return

        if self.headers.get("X-Secret") != SECRET:
            log(f"401 {client} — wrong secret")
            self._respond(401, {"error": "unauthorized"})
            return

        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, ValueError):
            log(f"400 {client} — invalid JSON")
            self._respond(400, {"error": "invalid_json"})
            return

        clean_text = body.get("cleanText", "")[:4000]
        language = body.get("language", "zh-TW")
        url = body.get("url", "")

        log(f"→ summarize request from {client} | url={url!r} | lang={language} | text={len(clean_text)}chars")

        prompt = (
            f"Summarize the following article in {language}.\n"
            "Return ONLY valid JSON with no markdown, no code fences:\n"
            '{"title": "article title", "bullets": ["point 1", "point 2", "point 3"]}\n\n'
            f"Article:\n{clean_text}"
        )

        t0 = time.time()
        try:
            log("  running claude -p ...")
            result = subprocess.run(
                ["claude", "-p", prompt],
                capture_output=True, text=True, timeout=30
            )
            elapsed = time.time() - t0
            raw = result.stdout.strip()
            log(f"  claude done in {elapsed:.1f}s | stdout={len(raw)}chars")
            if result.stderr.strip():
                log(f"  claude stderr: {result.stderr.strip()[:200]}")
            # Strip markdown code fences if claude wraps in ```json ... ```
            if raw.startswith("```"):
                raw = "\n".join(raw.split("\n")[1:-1])
            summary = json.loads(raw)
            summary["url"] = url
            log(f"← 200 OK | title={summary.get('title','')!r}")
            self._respond(200, summary)
        except subprocess.TimeoutExpired:
            log(f"← 504 claude timeout after 30s")
            self._respond(504, {"error": "claude_timeout"})
        except json.JSONDecodeError:
            log(f"← 500 parse_failed | raw={result.stdout[:200]!r}")
            self._respond(500, {"error": "parse_failed", "raw": result.stdout[:200]})
        except Exception as e:
            log(f"← 500 claude_failed | {e}")
            self._respond(500, {"error": "claude_failed", "detail": str(e)})

    def _respond(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(payload))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        pass  # handled by log()


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    log(f"NewsSummarizer server listening on port {PORT}")
    server.serve_forever()

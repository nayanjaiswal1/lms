#!/usr/bin/env python3
"""Payments provider stub for the lab (stdlib only; psycopg is used when present).

API used by the shop:
  POST /v1/charges          {amount_cents, currency, reference}  + optional Idempotency-Key header
      200 {"id", "status": "succeeded", "amount_cents", "currency"}   (contract_version 1)
      200 {"id", "state": "succeeded", "amount", "currency"}          (contract_version 2)
      402 {"error": "card_declined"}   when the reference contains "decline"
  A repeated Idempotency-Key replays the stored response and never charges twice.

Fault API (memory, also seeded from the environment at start):
  GET  /__fault            current fault settings
  POST /__fault            {latency_ms, error_rate, contract_version, error_mode}
      latency_ms        delay before answering (default 0)
      error_rate        0..1 chance of answering 500 (deterministic per MF_SEED)
      contract_version  1 or 2 (response field names)
      error_mode        "after" (default): the charge is recorded, then the 500 is returned (a lost response);
                        "before": the 500 is returned without recording anything
Observability (readable by probes):
  GET  /__charges          {"count", "charges": [...]}
  POST /__reset            clears charges and idempotency keys (memory and database)
  Every recorded charge is also written to the table mf_stub_payments_charge in $DATABASE_URL when it is set,
  so grader SQL can assert, for example, that no order was charged twice:
      SELECT count(*) - count(DISTINCT reference) FROM mf_stub_payments_charge

Environment: PAYMENTS_STUB_PORT (9101), PAYMENTS_STUB_LATENCY_MS, PAYMENTS_STUB_ERROR_RATE,
PAYMENTS_STUB_CONTRACT_VERSION, PAYMENTS_STUB_ERROR_MODE, MF_SEED, DATABASE_URL.
"""

import json
import os
import random
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:  # optional: mirror charges into the app database
    import psycopg
except ImportError:  # pragma: no cover
    psycopg = None

LOCK = threading.Lock()
STATE = {
    "latency_ms": int(os.environ.get("PAYMENTS_STUB_LATENCY_MS", "0")),
    "error_rate": float(os.environ.get("PAYMENTS_STUB_ERROR_RATE", "0")),
    "contract_version": int(os.environ.get("PAYMENTS_STUB_CONTRACT_VERSION", "1")),
    "error_mode": os.environ.get("PAYMENTS_STUB_ERROR_MODE", "after"),
}
CHARGES = []
BY_KEY = {}
RNG = random.Random(f"{os.environ.get('MF_SEED', '0')}:payments-stub")
DDL = (
    "CREATE TABLE IF NOT EXISTS mf_stub_payments_charge ("
    "id bigserial PRIMARY KEY, idempotency_key text, reference text NOT NULL, "
    "amount_cents integer NOT NULL, created_at timestamptz NOT NULL DEFAULT now())"
)


def log(message):
    print(f"[payments-stub] {message}", file=sys.stderr, flush=True)


def db_execute(sql, params=()):
    url = os.environ.get("DATABASE_URL", "")
    if not url or psycopg is None or not url.startswith(("postgres://", "postgresql://")):
        return
    try:
        with psycopg.connect(url, autocommit=True, connect_timeout=2) as conn:
            conn.execute(DDL)
            conn.execute(sql, params)
    except Exception as exc:  # the stub must keep answering even when the database is away
        log(f"database mirror failed: {exc}")


def validate_fault(data):
    out = {}
    if "latency_ms" in data:
        out["latency_ms"] = max(0, min(int(data["latency_ms"]), 120000))
    if "error_rate" in data:
        out["error_rate"] = max(0.0, min(float(data["error_rate"]), 1.0))
    if "contract_version" in data:
        if int(data["contract_version"]) not in (1, 2):
            raise ValueError("contract_version must be 1 or 2")
        out["contract_version"] = int(data["contract_version"])
    if "error_mode" in data:
        if data["error_mode"] not in ("before", "after"):
            raise ValueError("error_mode must be before or after")
        out["error_mode"] = data["error_mode"]
    return out


def render_charge(charge, version):
    if version == 2:
        return {"id": charge["id"], "state": "succeeded", "amount": charge["amount_cents"], "currency": charge["currency"]}
    return {"id": charge["id"], "status": "succeeded", "amount_cents": charge["amount_cents"], "currency": charge["currency"]}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        log(fmt % args)

    def _send(self, status, body):
        raw = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _json_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        if self.path == "/healthz":
            return self._send(200, {"status": "ok"})
        if self.path == "/__fault":
            return self._send(200, STATE)
        if self.path == "/__charges":
            with LOCK:
                return self._send(200, {"count": len(CHARGES), "charges": list(CHARGES)})
        return self._send(404, {"error": "not_found"})

    def do_POST(self):
        try:
            data = self._json_body()
        except ValueError:
            return self._send(400, {"error": "invalid_json"})
        if self.path == "/__fault":
            try:
                update = validate_fault(data)
            except (ValueError, TypeError) as exc:
                return self._send(400, {"error": str(exc)})
            with LOCK:
                STATE.update(update)
                return self._send(200, STATE)
        if self.path == "/__reset":
            with LOCK:
                CHARGES.clear()
                BY_KEY.clear()
            db_execute("TRUNCATE mf_stub_payments_charge")
            return self._send(200, {"count": 0})
        if self.path == "/v1/charges":
            return self._charge(data)
        return self._send(404, {"error": "not_found"})

    def _charge(self, data):
        with LOCK:
            state = dict(STATE)
            fail = state["error_rate"] > 0 and RNG.random() < state["error_rate"]
        if state["latency_ms"]:
            time.sleep(state["latency_ms"] / 1000)
        key = self.headers.get("Idempotency-Key")
        reference = str(data.get("reference", ""))
        amount = data.get("amount_cents")
        if not isinstance(amount, int) or amount <= 0 or not reference:
            return self._send(400, {"error": "invalid_request"})
        if "decline" in reference:
            return self._send(402, {"error": "card_declined"})
        with LOCK:
            charge = BY_KEY.get(key) if key else None
            if charge is None and not (fail and state["error_mode"] == "before"):
                charge = {"id": f"ch_{len(CHARGES) + 1:06d}", "reference": reference, "amount_cents": amount,
                          "currency": data.get("currency", "USD"), "idempotency_key": key}
                CHARGES.append(charge)
                if key:
                    BY_KEY[key] = charge
                new = True
            else:
                new = False
        if new:
            db_execute("INSERT INTO mf_stub_payments_charge (idempotency_key, reference, amount_cents) VALUES (%s, %s, %s)",
                       (key, reference, amount))
        if fail:
            return self._send(500, {"error": "internal_error"})
        return self._send(200, render_charge(charge, state["contract_version"]))


def main():
    port = int(os.environ.get("PAYMENTS_STUB_PORT", "9101"))
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    log(f"listening on 127.0.0.1:{port} with {STATE}")
    server.serve_forever()


if __name__ == "__main__":
    main()

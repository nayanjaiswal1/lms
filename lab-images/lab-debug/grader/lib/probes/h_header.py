"""Kind H — header / cookie / schema contract.

params:
  method, path, headers?, body?, expect_status?
  expect_headers:  {"Access-Control-Allow-Origin": "regex"}      must match
  forbid_headers:  {"Access-Control-Allow-Origin": "regex"}      must NOT match
  expect_cookies:  {"sessionid": {httponly: true, secure?: bool, samesite?: "Lax", path?: "/"}}
  json_schema:     minimal JSON-schema-like {type, required?, properties?, items?}
Set-Cookie values are inspected attribute by attribute.
"""
from __future__ import annotations

import re
from typing import Any

from .common import Context, ProbeFailure, http_request, render, status_ok

KIND = "H"

_TYPES = {"string": str, "number": (int, float), "integer": int, "boolean": bool,
          "array": list, "object": dict, "null": type(None)}


def _validate(schema: dict[str, Any], value: Any) -> bool:
    want = schema.get("type")
    if want:
        py = _TYPES.get(want)
        if py is None or not isinstance(value, py) or (isinstance(value, bool) and want in ("number", "integer")):
            return False
    if isinstance(value, dict):
        if any(k not in value for k in schema.get("required", [])):
            return False
        for k, sub in schema.get("properties", {}).items():
            if k in value and not _validate(sub, value[k]):
                return False
    if isinstance(value, list) and "items" in schema:
        return all(_validate(schema["items"], v) for v in value)
    return True


def _cookie_attrs(raw: str) -> tuple[str, dict[str, str | bool]]:
    parts = [p.strip() for p in raw.split(";")]
    name = parts[0].split("=", 1)[0]
    attrs: dict[str, str | bool] = {}
    for p in parts[1:]:
        k, _, v = p.partition("=")
        attrs[k.lower()] = v if v else True
    return name, attrs


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    p = render(params, ctx.rng(name), {"seed": ctx.seed})
    resp = http_request(ctx, p.get("method", "GET"), p["path"], p.get("headers"), p.get("body"))
    if not status_ok(resp.status, p.get("expect_status")):
        raise ProbeFailure("")
    for header, pattern in (p.get("expect_headers") or {}).items():
        if not re.search(pattern, resp.headers.get(header.lower(), "")):
            raise ProbeFailure("")
    for header, pattern in (p.get("forbid_headers") or {}).items():
        if header.lower() in resp.headers and re.search(pattern, resp.headers[header.lower()]):
            raise ProbeFailure("")
    if p.get("expect_cookies"):
        cookies = dict(_cookie_attrs(c) for c in resp.set_cookies())
        for cname, want in p["expect_cookies"].items():
            attrs = cookies.get(cname)
            if attrs is None:
                raise ProbeFailure("")
            for key, expected in want.items():
                got = attrs.get(key.lower(), False)
                if isinstance(expected, bool):
                    if bool(got) != expected:
                        raise ProbeFailure("")
                elif str(got).lower() != str(expected).lower():
                    raise ProbeFailure("")
    if p.get("json_schema") and not _validate(p["json_schema"], resp.json()):
        raise ProbeFailure("")

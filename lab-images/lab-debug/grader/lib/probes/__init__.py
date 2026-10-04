"""Generic probe library (kinds P/Q/C/M/L/H/T).

Root-owned, part of the image. A grader bundle only supplies JSON params for
these kinds; it never ships probe code. `run_probe` converts any outcome into
a {name, passed, message} dict where message is the author's text — never
server output, test source or expected values.
"""
from __future__ import annotations

import subprocess
import sys
import traceback
from typing import Any

from . import c_concurrent, h_header, l_latency, m_migrate, p_http, q_query, t_test
from .common import Context, ProbeFailure

KINDS = {mod.KIND: mod for mod in (p_http, q_query, c_concurrent, m_migrate, l_latency, h_header, t_test)}

INFRA_MESSAGE = "The grader could not complete this check. Try again; if it persists, contact your instructor."


def run_probe(ctx: Context, spec: dict[str, Any]) -> dict[str, Any]:
    name = str(spec.get("name", spec.get("kind", "probe")))
    message = str(spec.get("message", ""))
    mod = KINDS.get(str(spec.get("kind", "")))
    if mod is None:
        return {"name": name, "passed": False, "message": INFRA_MESSAGE}
    try:
        mod.run(ctx, name, spec.get("params", {}))
    except ProbeFailure as exc:
        if exc.detail:
            sys.stderr.write(f"[probe {name}] {exc.detail}\n")
        return {"name": name, "passed": False, "message": str(exc) or message}
    except (subprocess.TimeoutExpired, OSError, KeyError, ValueError, TypeError):
        traceback.print_exc()  # stderr only; never in the JSON result
        return {"name": name, "passed": False, "message": message or INFRA_MESSAGE}
    return {"name": name, "passed": True}

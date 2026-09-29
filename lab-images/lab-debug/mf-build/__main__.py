"""mf-build entry point: /opt/mindforge/mf-build (run as `python3 -I /opt/mindforge/mf-build`).

Root-owned, part of the lab-debug image. Renders debug-lab scenario variants
from block payloads + a resolved render spec (docs/debug-labs.md Part 2 B2/B3):

  stdin   one tar (any compression): spec.json + blocks/<dir>/<payload files>
  --out   output directory; one subdirectory per variant key containing
            workspace.tar.gz   workspace with git history, ready to extract into
                               /home/labuser/work
            grader.tar.gz      grader bundle (grader.json + hidden regression tests)
            verify.tar.gz      overlay tarballs used by build verification
                               (overlays/fix-<n>.tgz, overlays/cheat-<i>-<j>.tgz)
            meta.json          payload fields, protected manifest, diffs, sizes
  stdout  one JSON line: {"ok": true, "variants": [keys...]} or
          {"ok": false, "error": "..."} (exit 1)

Parameter values arrive already formatted as source literals and ticket text
already substituted by the platform; this program never interprets parameters.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mfbuild.errors import BuildError  # noqa: E402
from mfbuild.inputs import read_input  # noqa: E402
from mfbuild.variant import build_variant  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    try:
        spec, blocks = read_input(sys.stdin.buffer)
        keys = []
        for variant in spec["variants"]:
            build_variant(variant, blocks, os.path.join(args.out, variant["key"]))
            keys.append(variant["key"])
    except BuildError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    print(json.dumps({"ok": True, "variants": keys}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib import probes
from lib.probes.common import ProbeFailure


class _Failing:
    KIND = "x"

    @staticmethod
    def run(ctx, name, params):
        raise ProbeFailure("student-facing", detail="author-only detail")


class ProbeFailureStderr(unittest.TestCase):
    def test_detail_goes_to_stderr_not_result(self):
        probes.KINDS["x"] = _Failing
        self.addCleanup(probes.KINDS.pop, "x")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            res = probes.run_probe(None, {"name": "n", "kind": "x"})
        self.assertIn("author-only detail", err.getvalue())
        self.assertNotIn("author-only detail", str(res))
        self.assertEqual(res["message"], "student-facing")


if __name__ == "__main__":
    unittest.main()

"""Self-test canonical-markdown labs against a real lab image.

For each lab (standalone `kind: lab` doc, or a lesson with a nested `lab:` block)
this starts a fresh container, writes `files:`, runs `setup_script` as root, then
for every task asserts that `verification_script` FAILS before `solution_script`
runs (catches always-true checks) and PASSES after it.

usage: python scripts/test-k8s-labs.py content/courses/<course>/<section>/<file>.md [...]
env:   LAB_IMAGE (default mindforge/lab-k8s:1.31) — build it first from lab-images/.
"""
import os, subprocess, sys, time, uuid

import yaml

IMAGE = os.environ.get("LAB_IMAGE", "mindforge/lab-k8s:1.31")


def sh(name, script, user="labuser"):
    r = subprocess.run(["docker", "exec", "-i", "-u", user, "-w", "/home/labuser/work", name, "bash", "-s"],
                       input=script.encode(), capture_output=True, timeout=180)
    return r.returncode, (r.stdout + r.stderr).decode(errors="replace")


def lab_of(path):
    text = open(path, encoding="utf-8").read()
    fm = yaml.safe_load(text.split("\n---\n", 1)[0].lstrip("-\n"))
    return fm["title"], (fm.get("lab") or fm)


def run(path):
    title, lab = lab_of(path)
    name = "labtest-" + uuid.uuid4().hex[:8]
    subprocess.run(["docker", "run", "-d", "--name", name, "--cap-drop", "ALL", IMAGE], check=True, capture_output=True)
    ok = True
    try:
        for _ in range(150):
            if subprocess.run(["docker", "exec", name, "test", "-f", "/tmp/lab-ready"]).returncode == 0:
                break
            time.sleep(2)
        for f in lab.get("files") or []:
            p = "/home/labuser/work/" + f["path"]
            sh(name, f"mkdir -p \"$(dirname {p})\"; cat > {p} <<'__EOF__'\n{f['content']}\n__EOF__\n")
        rc, out = sh(name, lab.get("setup_script") or "true", user="root")
        if rc:
            print(f"  SETUP FAILED: {out}")
            return False
        for t in lab["tasks"]:
            pre, _ = sh(name, t["verification_script"])
            rc, out = sh(name, t["solution_script"])
            ver, vout = 1, ""
            for _ in range(20):  # controllers need a moment to reconcile
                ver, vout = sh(name, t["verification_script"])
                if ver == 0:
                    break
                time.sleep(3)
            status = "PASS" if ver == 0 and pre != 0 else ("ALWAYS-TRUE" if pre == 0 else "FAIL")
            if status != "PASS":
                ok = False
                print(f"  [{status}] {t['id_key']}\n    solution rc={rc}: {out.strip()[:600]}\n    verify: {vout.strip()[:400]}")
            else:
                print(f"  [PASS] {t['id_key']}")
    finally:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True)
    return ok


if __name__ == "__main__":
    results = {}
    for p in sys.argv[1:]:
        print(p)
        results[p] = run(p)
    bad = [p for p, ok in results.items() if not ok]
    print("\nALL PASS" if not bad else "\nFAILED:\n" + "\n".join(bad))
    sys.exit(1 if bad else 0)

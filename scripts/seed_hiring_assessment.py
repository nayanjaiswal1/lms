#!/usr/bin/env python3
"""Seed one complete hiring assessment: 2 DSA questions (stdio-graded), a
FastAPI debugging question, and a React exercise — using MindForge's existing
assessment API end to end (categories -> questions -> hiring assessment ->
publish). Demonstrates the full enroll-to-review lifecycle: the printed
short_code is the no-auth candidate link (frontend route /hire/{code}),
already built into the platform.

Usage:
    MF_EMAIL=jaiswal2062+instructor@gmail.com MF_PASSWORD=... \
        python3 scripts/seed_hiring_assessment.py

Env vars:
    MF_BASE_URL   default http://localhost:8080
    MF_EMAIL      an org staff account (admin/instructor/mentor role)
    MF_PASSWORD   that account's password
    MF_REACT_TIER difficulty of the React question to attach: beginner|intermediate (default: both)
"""
import json
import os
import sys

import requests

BASE_URL = os.environ.get("MF_BASE_URL", "http://localhost:8080")
EMAIL = os.environ.get("MF_EMAIL")
PASSWORD = os.environ.get("MF_PASSWORD")
REACT_TIER = os.environ.get("MF_REACT_TIER", "both")

if not EMAIL or not PASSWORD:
    sys.exit("Set MF_EMAIL and MF_PASSWORD (a seeded admin/instructor/mentor account) before running.")

session = requests.Session()


def api(method, path, **kwargs):
    headers = kwargs.pop("headers", {})
    if method.upper() != "GET":
        csrf = session.cookies.get("csrf_token")
        if csrf:
            headers["X-CSRF-Token"] = csrf
    resp = session.request(method, BASE_URL + path, headers=headers, **kwargs)
    if not resp.ok:
        sys.exit(f"{method} {path} -> {resp.status_code}: {resp.text}")
    if not resp.text:
        return {}
    body = resp.json()
    # Successful responses are wrapped as {"data": ...}; errors are not, but
    # those already exited above via resp.ok.
    return body["data"] if isinstance(body, dict) and "data" in body else body


def login():
    api("POST", "/api/auth/login", json={"email": EMAIL, "password": PASSWORD})
    print(f"Logged in as {EMAIL}")


def create_category(name):
    cat = api("POST", "/api/categories", json={"name": name})
    print(f"Category '{name}' -> {cat['id']}")
    return cat["id"]


def create_question(category_id, qtype, title, difficulty, points, tags, content):
    q = api("POST", "/api/questions", json={
        "category_id": category_id,
        "type": qtype,
        "title": title,
        "difficulty": difficulty,
        "default_points": points,
        "tags": tags,
        "content": content,
    })
    print(f"Question '{title}' ({difficulty}) -> {q['id']}")
    return q["id"]


# ─── DSA questions (stdio-graded via Piston/Judge0 — no sandbox needed) ──────

def dsa_reverse_string(category_id):
    return create_question(category_id, "coding", "Reverse a String", "beginner", 10,
        ["dsa", "strings"], {
        "prompt": "Read a single line from stdin and print it reversed.",
        "languages": ["python"],
        "starter_code": {"python": "s = input()\n# TODO: print the reversed string\n"},
        "time_limit_ms": 2000,
        "memory_limit_kb": 65536,
        "test_cases": [
            {"id": "sample_1", "stdin": "hello\n", "expected": "olleh", "hidden": False, "weight": 1},
            {"id": "hidden_1", "stdin": "MindForge\n", "expected": "egroFdniM", "hidden": True, "weight": 1},
            {"id": "hidden_2", "stdin": "a\n", "expected": "a", "hidden": True, "weight": 1},
        ],
    })


def dsa_first_unique_char(category_id):
    return create_question(category_id, "coding", "First Non-Repeating Character", "intermediate", 15,
        ["dsa", "strings", "hash-map"], {
        "prompt": (
            "Read a single line from stdin. Print the 0-indexed position of the first "
            "character that does not repeat anywhere else in the string. Print -1 if "
            "every character repeats."
        ),
        "languages": ["python"],
        "starter_code": {"python": "s = input()\n# TODO: print the index of the first non-repeating character, or -1\n"},
        "time_limit_ms": 2000,
        "memory_limit_kb": 65536,
        "test_cases": [
            {"id": "sample_1", "stdin": "leetcode\n", "expected": "0", "hidden": False, "weight": 1},
            {"id": "hidden_1", "stdin": "aabb\n", "expected": "-1", "hidden": True, "weight": 1},
            {"id": "hidden_2", "stdin": "swiss\n", "expected": "1", "hidden": True, "weight": 1},
        ],
    })


# ─── FastAPI debugging (sandbox-graded — real app, real pytest run) ──────────

FASTAPI_MAIN_BUGGY = '''from fastapi import FastAPI

app = FastAPI()
_items = []

# BUG: this creates a new item but is wired up as a GET — a create endpoint
# must be POST, and repeatedly GETting it would silently keep mutating state.
@app.get("/items", status_code=201)
def create_item(item: dict):
    _items.append(item)
    return item


@app.get("/items")
def list_items():
    return _items
'''

FASTAPI_TEST_APP = '''from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_create_item():
    resp = client.post("/items", json={"name": "widget"})
    assert resp.status_code == 201


def test_list_items():
    client.post("/items", json={"name": "gadget"})
    resp = client.get("/items")
    assert any(i["name"] == "gadget" for i in resp.json())
'''


def fastapi_debug_question(category_id):
    return create_question(category_id, "coding", "Fix the Broken FastAPI Items Endpoint", "intermediate", 20,
        ["fastapi", "python", "debugging"], {
        "prompt": (
            "The FastAPI app below is supposed to let a client POST a new item to "
            "/items and GET the current list back from /items. One route is wired "
            "up wrong. Fix main.py so both tests pass."
        ),
        "languages": ["python"],
        "starter_code": {"python": FASTAPI_MAIN_BUGGY},
        "time_limit_ms": 30000,
        "runtime": "sandbox",
        "sandbox_image": "mindforge/lab-python-web:3.12",
        "submit_path": "/home/labuser/app/main.py",
        "verify_files": {"/home/labuser/app/test_app.py": FASTAPI_TEST_APP},
        "verify_command": (
            "cd /home/labuser/app && "
            "pytest --junitxml=/tmp/mindforge-grade-result.xml -q test_app.py"
        ),
        "test_cases": [
            {"id": "test_create_item", "hidden": False, "weight": 1},
            {"id": "test_list_items", "hidden": True, "weight": 1},
        ],
    })


# ─── React exercises (sandbox-graded — real component, real vitest+RTL run) ──

REACT_COUNTER_BUGGY = '''import { useState } from "react";

export default function Counter() {
  const [count, setCount] = useState(0);
  // BUG: setCount(count + 1) is called immediately during render instead of
  // being passed as a click handler.
  return <button onClick={setCount(count + 1)}>{count}</button>;
}
'''

REACT_COUNTER_TEST = '''import { render, screen, fireEvent } from "@testing-library/react";
import Counter from "./Counter.jsx";

test("increments on click", () => {
  render(<Counter />);
  fireEvent.click(screen.getByRole("button"));
  expect(screen.getByRole("button").textContent).toBe("1");
});
'''

REACT_TODOLIST_BUGGY = '''import { useState } from "react";

export default function TodoList() {
  const [items, setItems] = useState([]);
  const [text, setText] = useState("");
  const [showActiveOnly, setShowActiveOnly] = useState(false);

  function addItem() {
    if (!text.trim()) return;
    setItems((prev) => [...prev, { id: Date.now() + Math.random(), text, done: false }]);
    setText("");
  }

  function toggleDone(id) {
    setItems((prev) => prev.map((it) => (it.id === id ? { ...it, done: !it.done } : it)));
  }

  // BUG: inverted filter condition — "active only" shows completed items instead.
  const visible = showActiveOnly ? items.filter((it) => it.done) : items;

  return (
    <div>
      <input aria-label="new-todo" value={text} onChange={(e) => setText(e.target.value)} />
      <button onClick={addItem}>Add</button>
      <button onClick={() => setShowActiveOnly((v) => !v)}>Toggle active only</button>
      <ul>
        {visible.map((it) => (
          <li key={it.id} onClick={() => toggleDone(it.id)} data-done={it.done}>
            {it.text}
          </li>
        ))}
      </ul>
    </div>
  );
}
'''

REACT_TODOLIST_TEST = '''import { render, screen, fireEvent } from "@testing-library/react";
import TodoList from "./TodoList.jsx";

function addTodo(text) {
  fireEvent.change(screen.getByLabelText("new-todo"), { target: { value: text } });
  fireEvent.click(screen.getByText("Add"));
}

test("adds multiple items and filters to active only", () => {
  render(<TodoList />);
  addTodo("buy milk");
  addTodo("walk dog");
  addTodo("write tests");

  expect(screen.getAllByRole("listitem")).toHaveLength(3);

  fireEvent.click(screen.getByText("walk dog"));
  fireEvent.click(screen.getByText("Toggle active only"));

  const active = screen.getAllByRole("listitem");
  expect(active).toHaveLength(2);
  expect(screen.queryByText("walk dog")).not.toBeInTheDocument();
});
'''


def react_sandbox_content(prompt, component_name, buggy_code, test_code, test_id):
    return {
        "prompt": prompt,
        "languages": ["javascript"],
        "starter_code": {"javascript": buggy_code},
        "time_limit_ms": 30000,
        "runtime": "sandbox",
        "sandbox_image": "mindforge/lab-node-web:22",
        "submit_path": f"/home/labuser/grade/src/{component_name}.jsx",
        "verify_files": {f"/home/labuser/grade/src/{component_name}.test.jsx": test_code},
        # The submitted component + test file already landed under
        # /home/labuser/grade/src/ before this command runs (see
        # sandboxExecutor.Run: SubmitPath and VerifyFiles are written first).
        # This merges in the scaffold's package.json/vite.config/vitest.config
        # (whose test/environment settings live under grade/, not the
        # read-only /opt/scaffold original — see
        # lab-images/lab-node-web/scaffold/vitest.config.js) plus a symlink to
        # its preinstalled node_modules, without touching src/ since the
        # scaffold ships no file of that name.
        "verify_command": (
            "cp -r /opt/scaffold/react-app/. /home/labuser/grade/ && "
            "ln -sfn /opt/scaffold/react-app/node_modules /home/labuser/grade/node_modules && "
            "cd /home/labuser/grade && "
            "npx vitest run --config vitest.config.js --reporter=junit "
            "--outputFile=/tmp/mindforge-grade-result.xml "
            f"src/{component_name}.test.jsx"
        ),
        "test_cases": [{"id": test_id, "hidden": False, "weight": 1}],
    }


def react_counter_question(category_id):
    return create_question(category_id, "coding", "Fix the Counter Button", "beginner", 10,
        ["react", "hooks", "debugging"],
        react_sandbox_content(
            "The Counter component below should increment on click, but it's wired up wrong. Fix Counter.jsx.",
            "Counter", REACT_COUNTER_BUGGY, REACT_COUNTER_TEST, "increments on click"))


def react_todolist_question(category_id):
    return create_question(category_id, "coding", "Fix the Todo List Filter", "intermediate", 20,
        ["react", "hooks", "debugging"],
        react_sandbox_content(
            "TodoList should show only incomplete items when 'active only' is toggled on, "
            "but the filter is inverted. Fix TodoList.jsx.",
            "TodoList", REACT_TODOLIST_BUGGY, REACT_TODOLIST_TEST,
            "adds multiple items and filters to active only"))


# ─── Assemble the hiring assessment ───────────────────────────────────────────

def main():
    login()

    dsa_cat = create_category("Data Structures & Algorithms")
    fastapi_cat = create_category("FastAPI Debugging")
    react_cat = create_category("React")

    dsa_reverse_string(dsa_cat)
    dsa_first_unique_char(dsa_cat)
    fastapi_id = fastapi_debug_question(fastapi_cat)

    react_ids = []
    if REACT_TIER in ("beginner", "both"):
        react_ids.append(react_counter_question(react_cat))
    if REACT_TIER in ("intermediate", "both"):
        react_ids.append(react_todolist_question(react_cat))

    assessment = api("POST", "/api/assessments", json={
        "title": "Full-Stack Engineer — Hiring Assessment",
        "description": "2 DSA problems, a FastAPI debugging exercise, and a React exercise.",
        "parent_type": "hiring",
        "duration_minutes": 90,
        "pass_percentage": 60,
        "max_attempts": 1,
        "shuffle_questions": False,
        "shuffle_options": False,
        "allow_backtrack": True,
        "show_results": True,
    })
    assessment_id = assessment["id"]
    print(f"Assessment '{assessment['title']}' -> {assessment_id}")

    # DSA questions attached via auto-select (demonstrates bulk/random pick by
    # category) — FastAPI + React attached individually (demonstrates manual pick).
    auto = api("POST", f"/api/assessments/{assessment_id}/questions/auto-select",
               json={"category_id": dsa_cat, "count": 2})
    print(f"Auto-selected {auto['added_count']} DSA question(s).")

    for qid in (fastapi_id, *react_ids):
        api("POST", f"/api/assessments/{assessment_id}/questions", json={"question_id": qid})
    print(f"Manually attached {1 + len(react_ids)} question(s).")

    api("POST", f"/api/assessments/{assessment_id}/publish")
    final = api("GET", f"/api/assessments/{assessment_id}")
    short_code = final["assessment"]["short_code"]

    print("\nAssessment published.")
    print(f"Candidate link (no login required): {BASE_URL.replace('8080', '3000')}/hire/{short_code}")
    print(f"Staff results/review view: {BASE_URL.replace('8080', '3000')}/assessments/manage")


if __name__ == "__main__":
    main()

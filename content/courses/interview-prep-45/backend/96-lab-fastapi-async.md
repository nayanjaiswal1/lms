---
kind: lab
id_key: interview-prep-45/lab-fastapi-async
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Lab: FastAPI Async — Concurrent Aggregation"
position: 96
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
lab_type: terminal
environment: mindforge/lab-python-web:3.12
preview_port: 8000
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: false
setup_script: |
    #!/bin/bash
    # The image's app-runner starts .lab/start.sh (written above) as labuser;
    # this probe just confirms readiness — the platform retries it.
    curl -sf --max-time 2 http://localhost:8000/ >/dev/null
files:
    - path: .lab/start.sh
      content: |
        cd /home/labuser/work
        exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    - path: TASKS.md
      content: |
        # FastAPI Async Lab (Roadmap Day 3 — Backend Deep Dive)

        A FastAPI app is ALREADY RUNNING on http://localhost:8000 with --reload:
        every save to main.py restarts it automatically. Try it:

            curl -s http://localhost:8000/ | jq
            curl -s http://localhost:8000/api/a | jq   # takes ~1 second

        ## Task 1 — Health endpoint
        Add `GET /health` returning `{"status": "ok"}`.

        ## Task 2 — Concurrent aggregation with asyncio.gather
        Implement `GET /aggregate`: call the three upstream endpoints
        (`/api/a`, `/api/b`, `/api/c` on localhost:8000) CONCURRENTLY with
        `httpx.AsyncClient` + `asyncio.gather`, and return:

            {"results": ["a", "b", "c"]}

        Each upstream takes ~1 s. Done concurrently the whole request takes ~1 s;
        done sequentially it takes ~3 s — the checker enforces < 2 s, so
        sequential awaits FAIL.

        Check each task with the "Check" button in the task panel.
    - path: main.py
      content: |
        """FastAPI async lab — implement the endpoints marked TASK below.

        The server runs with --reload: every save restarts it automatically.
        """
        import asyncio

        import httpx
        from fastapi import FastAPI

        app = FastAPI(title="fastapi-lab")

        UPSTREAM = "http://localhost:8000"


        @app.get("/")
        async def index():
            return {"service": "fastapi-lab", "status": "running"}


        @app.get("/api/a")
        async def upstream_a():
            await asyncio.sleep(1)
            return {"value": "a"}


        @app.get("/api/b")
        async def upstream_b():
            await asyncio.sleep(1)
            return {"value": "b"}


        @app.get("/api/c")
        async def upstream_c():
            await asyncio.sleep(1)
            return {"value": "c"}


        # TASK 1: add GET /health returning {"status": "ok"}


        # TASK 2: add GET /aggregate that fetches /api/a, /api/b and /api/c
        # CONCURRENTLY (httpx.AsyncClient + asyncio.gather) and returns
        # {"results": ["a", "b", "c"]}. Sequential awaits will take ~3s and
        # fail the < 2s check.
tasks:
    - id_key: task-health
      title: "GET /health returns {\"status\": \"ok\"}"
      points: 10
      description: |
        Add a `GET /health` endpoint to `main.py` returning `{"status": "ok"}`.
      verification_script: |
        body=$(curl -sf http://localhost:8000/health) || { echo "GET /health failed — did you add the route to main.py?"; exit 1; }
        echo "$body" | jq -e '.status == "ok"' >/dev/null || { echo "GET /health returned '$body' — expected {\"status\": \"ok\"}"; exit 1; }
      hint_context: >-
        The student must add an async def endpoint decorated with
        @app.get("/health") in main.py returning the dict {"status": "ok"}.
        FastAPI serializes dicts to JSON automatically. Common mistake:
        editing but not saving, or a syntax error that crashes the --reload
        worker (check /var/log/mindforge-lab/uvicorn.log).
      explanation_context: >-
        FastAPI turns returned dicts into JSON responses; a dedicated health
        route is the standard readiness contract for load balancers.
    - id_key: task-aggregate
      title: "GET /aggregate fans out concurrently (< 2 s)"
      points: 20
      description: |
        Implement `GET /aggregate` in `main.py`: fetch `/api/a`, `/api/b` and
        `/api/c` concurrently using `httpx.AsyncClient` and `asyncio.gather`,
        returning `{"results": ["a", "b", "c"]}`. Each upstream sleeps ~1 s, so a
        concurrent implementation answers in ~1 s — the check fails anything
        slower than 2 s (i.e. sequential awaits).
      verification_script: |
        start=$(date +%s%N)
        body=$(curl -sf --max-time 8 http://localhost:8000/aggregate) || { echo "GET /aggregate failed — is the route implemented?"; exit 1; }
        end=$(date +%s%N)
        echo "$body" | jq -e '(.results | sort) == ["a","b","c"]' >/dev/null || { echo "GET /aggregate returned '$body' — expected {\"results\": [\"a\",\"b\",\"c\"]}"; exit 1; }
        elapsed_ms=$(( (end - start) / 1000000 ))
        if [ "$elapsed_ms" -ge 2000 ]; then echo "GET /aggregate took ${elapsed_ms} ms — the three upstream calls must run concurrently (asyncio.gather), not sequentially"; exit 1; fi
      hint_context: >-
        The student must open one httpx.AsyncClient, create three coroutines
        (client.get for /api/a, /api/b, /api/c against http://localhost:8000),
        run them with asyncio.gather, and build {"results": [...]} from each
        response's json()["value"]. Common mistakes: awaiting the three calls
        one after another (takes ~3 s and fails the < 2 s check), using
        blocking requests.get inside the async endpoint, or forgetting to
        await client.get.
      explanation_context: >-
        asyncio.gather schedules all three requests on the event loop at once,
        so total latency is the max of the three (~1 s) instead of the sum
        (~3 s). This is the core benefit of async I/O that the roadmap's Day 3
        interview questions probe.
---

Hands-on lab for Day 3's backend deep dive: a FastAPI app is already running
on port 8000 with auto-reload. Add a health route, then implement a concurrent
fan-out endpoint with `asyncio.gather` — the checker measures wall-clock time,
so only a genuinely concurrent implementation passes.

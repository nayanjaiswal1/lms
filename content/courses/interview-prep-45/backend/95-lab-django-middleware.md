---
kind: lab
id_key: interview-prep-45/lab-django-middleware
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Lab: Django Middleware — Request ID & Response Time"
position: 95
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
        exec python3 manage.py runserver 0.0.0.0:8000
    - path: TASKS.md
      content: |
        # Django Middleware Lab (Roadmap Day 1 — Backend Deep Dive)

        A Django app is ALREADY RUNNING on http://localhost:8000 with auto-reload:
        every file you save is picked up automatically. Try it:

            curl -i http://localhost:8000/

        ## Task 1 — X-Request-ID middleware
        Implement `RequestIDMiddleware` in `app/middleware.py` so every response
        carries a unique `X-Request-ID` header (use `uuid.uuid4()`), then register
        it in `MIDDLEWARE` in `config/settings.py`.

        ## Task 2 — Response time middleware
        Implement `ResponseTimeMiddleware` in `app/middleware.py` so every response
        carries an `X-Response-Time-Ms` header with the elapsed milliseconds, then
        register it. `curl -i http://localhost:8000/slow/` should show ≥ 300 ms.

        ## Task 3 — Health endpoint
        Add a `health` view in `app/views.py` returning `{"status": "ok"}` and
        route it at `/health/` in `config/urls.py`.

        Check each task with the "Check" button in the task panel.
    - path: manage.py
      content: |
        #!/usr/bin/env python3
        import os
        import sys

        if __name__ == "__main__":
            os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
            from django.core.management import execute_from_command_line
            execute_from_command_line(sys.argv)
    - path: config/__init__.py
      content: ""
    - path: config/settings.py
      content: |
        import os
        from pathlib import Path

        BASE_DIR = Path(__file__).resolve().parent.parent

        SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "lab-sandbox-only-key")
        DEBUG = True
        ALLOWED_HOSTS = ["*"]

        INSTALLED_APPS = []

        MIDDLEWARE = [
            "django.middleware.common.CommonMiddleware",
            # TASK 1: register "app.middleware.RequestIDMiddleware" here
            # TASK 2: register "app.middleware.ResponseTimeMiddleware" here
        ]

        ROOT_URLCONF = "config.urls"
        DATABASES = {}
        USE_TZ = True
    - path: config/urls.py
      content: |
        from django.urls import path

        from app import views

        urlpatterns = [
            path("", views.index),
            path("slow/", views.slow),
            # TASK 3: route views.health at "health/"
        ]
    - path: app/__init__.py
      content: ""
    - path: app/views.py
      content: |
        import time

        from django.http import JsonResponse


        def index(request):
            return JsonResponse({"service": "django-lab", "status": "running"})


        def slow(request):
            time.sleep(0.3)
            return JsonResponse({"slept_ms": 300})


        # TASK 3: add a `health` view that returns JsonResponse({"status": "ok"})
    - path: app/middleware.py
      content: |
        """Implement the two middleware classes below (roadmap Day 1 backend task).

        Django middleware is a callable that takes `get_response` and returns a
        callable taking `request` and returning a response:

            class MyMiddleware:
                def __init__(self, get_response):
                    self.get_response = get_response

                def __call__(self, request):
                    response = self.get_response(request)
                    return response

        Register each class in MIDDLEWARE in config/settings.py when done —
        the dev server reloads automatically on save.
        """


        # TASK 1: RequestIDMiddleware — set response["X-Request-ID"] to a fresh
        # uuid.uuid4() string on every response.


        # TASK 2: ResponseTimeMiddleware — measure time around get_response and
        # set response["X-Response-Time-Ms"] to the elapsed milliseconds.
tasks:
    - id_key: task-request-id
      title: "Every response carries a unique X-Request-ID"
      points: 15
      description: |
        Implement `RequestIDMiddleware` in `app/middleware.py` and register it in
        `MIDDLEWARE` (`config/settings.py`). Every response from the app must
        include an `X-Request-ID` header, and two consecutive requests must get
        two different IDs.
      verification_script: |
        a=$(curl -s -o /dev/null -D - http://localhost:8000/ | tr -d '\r' | awk -F': ' 'tolower($1)=="x-request-id"{print $2}')
        b=$(curl -s -o /dev/null -D - http://localhost:8000/ | tr -d '\r' | awk -F': ' 'tolower($1)=="x-request-id"{print $2}')
        if [ -z "$a" ]; then echo "X-Request-ID header missing on GET /"; exit 1; fi
        if [ "$a" = "$b" ]; then echo "X-Request-ID must be unique per request (got '$a' twice)"; exit 1; fi
      hint_context: >-
        The student must write a class-based Django middleware in
        app/middleware.py whose __call__ sets response["X-Request-ID"] =
        str(uuid.uuid4()), and add "app.middleware.RequestIDMiddleware" to the
        MIDDLEWARE list in config/settings.py. Common mistakes: forgetting to
        register the middleware in settings, generating the UUID once at import
        time instead of per request, or setting the header on the request
        instead of the response.
      explanation_context: >-
        Class-based Django middleware wraps get_response; setting a header on
        the returned response object attaches it to every response. Generating
        uuid4 inside __call__ makes it unique per request, which is what
        request-tracing infrastructure relies on.
    - id_key: task-response-time
      title: "Every response carries X-Response-Time-Ms"
      points: 15
      description: |
        Implement `ResponseTimeMiddleware` in `app/middleware.py` and register it.
        Every response must include an `X-Response-Time-Ms` header; for
        `GET /slow/` (which sleeps 300 ms) the value must be at least 200.
      verification_script: |
        t=$(curl -s -o /dev/null -D - http://localhost:8000/slow/ | tr -d '\r' | awk -F': ' 'tolower($1)=="x-response-time-ms"{print $2}')
        if [ -z "$t" ]; then echo "X-Response-Time-Ms header missing on GET /slow/"; exit 1; fi
        if ! awk "BEGIN{exit !($t >= 200)}" 2>/dev/null; then echo "X-Response-Time-Ms is '$t' for /slow/ — expected >= 200 (the view sleeps 300 ms)"; exit 1; fi
      hint_context: >-
        The student must record time.perf_counter() before calling
        self.get_response(request), compute the elapsed milliseconds after it
        returns, and set response["X-Response-Time-Ms"]. Common mistakes:
        measuring in seconds instead of milliseconds, or timing outside
        get_response so the view's sleep isn't included.
      explanation_context: >-
        Timing around get_response captures the full downstream duration —
        view code plus any later middleware — which is why /slow/'s 300 ms
        sleep shows up in the header. This is exactly how APM middlewares work.
    - id_key: task-health-endpoint
      title: "GET /health/ returns {\"status\": \"ok\"}"
      points: 10
      description: |
        Add a `health` view in `app/views.py` returning `{"status": "ok"}` as JSON
        and route it at `/health/` in `config/urls.py`.
      verification_script: |
        body=$(curl -sf http://localhost:8000/health/) || { echo "GET /health/ failed — is the view routed in config/urls.py?"; exit 1; }
        echo "$body" | jq -e '.status == "ok"' >/dev/null || { echo "GET /health/ returned '$body' — expected {\"status\": \"ok\"}"; exit 1; }
      hint_context: >-
        The student must define `def health(request): return
        JsonResponse({"status": "ok"})` in app/views.py and add
        `path("health/", views.health)` to urlpatterns in config/urls.py.
        Common mistakes: forgetting the trailing slash in the route (Django's
        CommonMiddleware redirects, curl -sf follows nothing), or returning a
        plain HttpResponse string instead of JsonResponse.
      explanation_context: >-
        Health endpoints are the standard contract for load balancers and
        orchestrators; JsonResponse sets the application/json content type
        automatically.
---

Hands-on lab for Day 1's backend deep dive: a Django app is already running on
port 8000 with auto-reload. Implement two production-style middleware classes
and a health endpoint; use the file explorer or terminal editors to edit
`app/middleware.py`, `config/settings.py`, and friends.

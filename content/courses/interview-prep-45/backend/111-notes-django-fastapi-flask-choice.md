---
kind: lesson
id_key: interview-prep-45/note-django-fastapi-flask-choice
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Django vs FastAPI vs Flask — Framework Choice"
position: 111
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The course teaches Django and FastAPI internals in depth (Days 1-3, 22-23) and mentions Flask only as a one-line comparison point in the WSGI-vs-ASGI table (Day 3) and the dependency-injection lesson (Day 23). This note is the direct three-way comparison an interviewer asks for when the question is "which framework would you pick for X" rather than "how does FastAPI's DI work."

## The three, side by side

| | Django | Flask | FastAPI |
|---|---|---|---|
| Type | Full "batteries-included" framework | Minimal micro-framework | Modern, async-first micro-framework |
| Concurrency model | WSGI (sync) by default; ASGI via Django Channels for websockets/async views | WSGI (sync) | ASGI (async) native |
| Validation | Django Forms / DRF serializers, manual | Manual (or Flask-WTF/Marshmallow as add-ons) | Pydantic — automatic, type-hint-driven |
| ORM | Built-in (Django ORM) | None built-in — bring your own (usually SQLAlchemy) | None built-in — bring your own (usually SQLAlchemy) |
| Admin panel | Built-in, auto-generated from models | None | None |
| API docs | Manual, or DRF's browsable API | Manual, or an add-on (flasgger) | Automatic (OpenAPI/Swagger UI generated from type hints) |
| Learning curve | Steeper — more conventions to learn upfront | Shallow — minimal structure to learn | Shallow — Pydantic + type hints are the main new concept |
| Best for | Content-heavy sites, admin-driven CRUD apps, teams that want strong conventions | Small services, prototypes, teams that want to choose every piece themselves | High-concurrency APIs, I/O-bound services, teams that want type safety end-to-end |

## Django vs FastAPI — the interview answer

This course's Day 1-2 (Django ORM, request lifecycle) and Day 3 (FastAPI ASGI/async) cover each framework's internals deeply but never state the choice explicitly:

- **Pick Django** when the project needs an admin interface out of the box, a batteries-included ORM with migrations, and you're building a traditional web app (server-rendered templates, forms, sessions) rather than a pure API — Django's conventions pay off most when the team is larger and benefits from "there's one obvious way to do it."
- **Pick FastAPI** when the project is API-first, I/O-bound (many concurrent DB/HTTP calls, matching Day 3's ASGI concurrency model), and you want request/response validation and OpenAPI docs generated automatically from Python type hints rather than hand-maintained. FastAPI has no opinion on ORM or admin — you assemble those yourself (typically SQLAlchemy + Alembic).
- **The honest trade-off:** Django gives you more for free but is heavier and sync-first by default; FastAPI gives you async concurrency and automatic validation/docs but requires assembling the rest of the stack yourself. Neither is "better" — the decision hinges on whether you're building a full web application (Django) or a high-throughput API service (FastAPI).

## Flask vs FastAPI — the interview answer

Flask and FastAPI are closer in philosophy (both minimal, both "bring your own ORM") but differ on two axes that matter for the same reasons Day 3's WSGI/ASGI table lays out:

- **Concurrency:** Flask is WSGI/sync by default (thread- or process-based concurrency — more workers to handle more concurrent requests). FastAPI is ASGI/async natively — a single worker can hold many concurrent I/O-bound requests via `async`/`await`, which matters when the bottleneck is waiting on a DB or an external API, not CPU.
- **Validation and docs:** Flask has no built-in request validation — you either write manual checks or add a library (Marshmallow, Flask-WTF). FastAPI's Pydantic integration validates request bodies, query params, and path params automatically from type hints, and generates interactive OpenAPI docs (`/docs`) as a side effect of the same type hints — no separate documentation effort.
- **When Flask still wins:** a small, simple, mostly-synchronous service where you want minimal magic and full control over every middleware/extension choice, or an existing Flask codebase where a rewrite isn't justified by the async/validation gains. FastAPI's advantages compound as the API surface and concurrent-request volume grow — for a handful of simple sync endpoints, Flask's simplicity can be the pragmatic choice.

## Key takeaways

- Django is batteries-included (admin, ORM, forms) and sync-first — best for full web apps and teams that want strong conventions; FastAPI is API-first, async-native, and validates/documents automatically via Pydantic and type hints.
- Flask and FastAPI share a minimalist "bring your own ORM" philosophy but differ on concurrency model (WSGI vs ASGI) and built-in validation (none vs Pydantic) — Flask still makes sense for small, simple, mostly-synchronous services.
- The recurring decision axis across all three: how much do you want the framework to decide for you (Django highest, FastAPI middle via Pydantic conventions, Flask lowest), and is the workload I/O-bound enough that ASGI concurrency (FastAPI) actually matters.

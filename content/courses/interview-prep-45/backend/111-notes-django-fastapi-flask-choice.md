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

This course teaches Django and FastAPI internals in depth elsewhere, and mentions Flask only as a one-line comparison point when covering WSGI vs ASGI and dependency injection. This note is the direct three-way comparison an interviewer asks for when the question is "which framework would you pick for X" rather than "how does FastAPI's DI work."

## The three, side by side

| | Django | Flask | FastAPI |
|---|---|---|---|
| Type | Full "batteries-included" framework | Minimal micro-framework | Modern, async-first micro-framework |
| Concurrency model | WSGI (sync) by default; ASGI via Django Channels for websockets/async views | WSGI (sync) | ASGI (async) native |
| Validation | Django Forms / DRF serializers, manual | Manual (or Flask-WTF/Marshmallow as add-ons) | Pydantic, automatic and type-hint-driven |
| ORM | Built-in (Django ORM) | None built-in, bring your own (usually SQLAlchemy) | None built-in, bring your own (usually SQLAlchemy) |
| Admin panel | Built-in, auto-generated from models | None | None |
| API docs | Manual, or DRF's browsable API | Manual, or an add-on (flasgger) | Automatic (OpenAPI/Swagger UI generated from type hints) |
| Learning curve | Steeper, more conventions to learn upfront | Shallow, minimal structure to learn | Shallow; Pydantic plus type hints are the main new concept |
| Best for | Content-heavy sites, admin-driven CRUD apps, teams that want strong conventions | Small services, prototypes, teams that want to choose every piece themselves | High-concurrency APIs, I/O-bound services, teams that want type safety end-to-end |

## Django vs FastAPI: the interview answer

This course covers each framework's internals deeply elsewhere (Django's ORM and request lifecycle, FastAPI's ASGI/async model) but never states the choice between them explicitly:

- **Pick Django** when the project needs an admin interface out of the box, a batteries-included ORM with migrations, and you're building a traditional web app (server-rendered templates, forms, sessions) rather than a pure API. Django's conventions pay off most when the team is larger and benefits from "there's one obvious way to do it."
- **Pick FastAPI** when the project is API-first, I/O-bound (many concurrent DB/HTTP calls, which is exactly what ASGI's concurrency model is built for), and you want request/response validation and OpenAPI docs generated automatically from Python type hints rather than hand-maintained. FastAPI has no opinion on ORM or admin; you assemble those yourself, typically SQLAlchemy plus Alembic.
- **The honest trade-off:** Django gives you more for free but is heavier and sync-first by default. FastAPI gives you async concurrency and automatic validation/docs but requires assembling the rest of the stack yourself. Neither is unconditionally better; the decision hinges on whether you're building a full web application (Django) or a high-throughput API service (FastAPI).

## Flask vs FastAPI: the interview answer

Flask and FastAPI are closer in philosophy (both minimal, both "bring your own ORM") but differ on two axes that matter for the same reasons WSGI and ASGI differ in general:

- **Concurrency.** Flask is WSGI/sync by default, so it scales concurrent requests via more worker threads or processes. FastAPI is ASGI/async natively, so a single worker can hold many concurrent I/O-bound requests via `async`/`await`, which matters when the bottleneck is waiting on a DB or an external API, not CPU.
- **Validation and docs.** Flask has no built-in request validation; you either write manual checks or add a library (Marshmallow, Flask-WTF). FastAPI's Pydantic integration validates request bodies, query params, and path params automatically from type hints, and generates interactive OpenAPI docs (`/docs`) as a side effect of the same type hints, with no separate documentation effort.
- **When Flask still wins:** a small, simple, mostly-synchronous service where you want minimal magic and full control over every middleware/extension choice, or an existing Flask codebase where a rewrite isn't justified by the async/validation gains. FastAPI's advantages compound as the API surface and concurrent-request volume grow; for a handful of simple sync endpoints, Flask's simplicity can be the pragmatic choice.

The recurring decision axis across all three frameworks is how much you want the framework to decide for you (Django highest, FastAPI in the middle via Pydantic conventions, Flask lowest), combined with whether the workload is I/O-bound enough that ASGI concurrency actually pays off.

---
kind: quiz
id_key: interview-prep-45/test-backend-django
course: interview-prep-45
section: backend-django
section_title: "Django"
section_position: 7
section_group: "Backend"
title: "Practice Test: Django"
position: 5
estimated_minutes: 20
pass_percentage: 70
duration_minutes: 20
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
    - checkpoints/02-quiz-week-2.md
questions:
  - id_key: interview-prep-45/quiz-week-2/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In Django ORM, what is the difference between select_related and prefetch_related?"
    options:
      - text: "select_related uses a SQL JOIN for foreign keys; prefetch_related runs a second query for many-to-many/reverse relations"
        correct: true
      - text: "They are aliases for the same operation"
      - text: "prefetch_related joins tables; select_related runs extra queries"
      - text: "select_related only works on many-to-many fields"
    explanation: "select_related follows single-valued relations in one JOINed query; prefetch_related fetches related sets in a separate query and stitches them in Python -- both kill N+1 query problems."

  - id_key: interview-prep-45/test-backend-django/middleware-order
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "MIDDLEWARE = [A, B, C]. Which describes how a request actually flows through this chain?"
    options:
      - text: "A(B(C(view))) -- request-phase code runs A, B, C in order; response-phase code unwinds C, B, A"
        correct: true
      - text: "Django loops through the list once and runs every middleware's full code before moving to the view"
      - text: "Request phase runs in reverse order: C, B, A"
      - text: "Only the first middleware in the list actually runs"
    explanation: "Each middleware wraps the next one, so MIDDLEWARE = [A, B, C] builds A(B(C(view))). Going in you unwind top to bottom, coming back out you unwind bottom to top."

  - id_key: interview-prep-45/test-backend-django/csrf-post
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "On a session-authenticated POST request, where does the CSRF check happen relative to the view?"
    options:
      - text: "CsrfViewMiddleware validates the token before the view runs, as part of the middleware chain"
        correct: true
      - text: "Inside the view, as the very last line before returning a response"
      - text: "It only happens if the view explicitly calls a csrf_check() function"
      - text: "After the response has already been sent to the client"
    explanation: "CsrfViewMiddleware is part of the request-phase middleware chain, so it validates the CSRF token before the view ever executes. It's typically skipped for token/JWT-authenticated API clients that don't rely on cookies."

  - id_key: interview-prep-45/test-backend-django/queryset-lazy
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "`qs = Book.objects.filter(published=True)` — has this line hit the database yet?"
    options:
      - text: "No. It only builds a description of the query; the database is hit when the queryset is evaluated"
        correct: true
      - text: "Yes, filter() always runs immediately"
      - text: "Only if published=True happens to match zero rows"
      - text: "It depends on which database backend is configured"
    explanation: "Django querysets are lazy. filter() just refines a query description. Only iterating it, counting it, checking truthiness, or another terminal call actually runs it against the database."

  - id_key: interview-prep-45/test-backend-django/exists-vs-bool
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why is qs.exists() usually better than `if qs:` for an existence check?"
    options:
      - text: "exists() runs a cheap SELECT 1 ... LIMIT 1, while if qs: forces the whole queryset to evaluate and load into memory"
        correct: true
      - text: "if qs: never actually queries the database"
      - text: "exists() is only available on querysets with an ordering applied"
      - text: "There is no practical difference between the two"
    explanation: "bool(queryset) triggers a full fetch of every matching row just to check non-emptiness. exists() is built specifically to answer this question cheaply."

  - id_key: interview-prep-45/test-backend-django/bulk-create-signals
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "A model has a post_save signal that sends a notification. 200 rows are inserted with bulk_create. How many notifications fire?"
    options:
      - text: "200, exactly as if .save() were called on each"
      - text: "Zero, because bulk_create issues INSERT statements directly and never calls save(), so post_save never fires"
        correct: true
      - text: "1, fired once for the whole batch"
      - text: "It depends on batch_size"
    explanation: "bulk_create bypasses save() entirely, which means every signal wired to save() (pre_save, post_save) is skipped. Anything that must run per row needs to run explicitly."

  - id_key: interview-prep-45/test-backend-django/cache-signal-invalidation
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why is invalidating a cache from a post_save signal stronger than deleting the cache key inside one specific view?"
    options:
      - text: "A signal fires for every save of that model regardless of which code path triggered it, so there's no forgotten call site left with stale data"
        correct: true
      - text: "Signals run before the database write, so they're always faster"
      - text: "A view-level cache.delete() is not allowed in Django"
      - text: "There's no real difference between the two approaches"
    explanation: "A cache.delete() inside one view only protects that one path. A post_save signal fires no matter which code, admin, shell, a management command, saved the model."

  - id_key: interview-prep-45/test-backend-django/cache-lazy-queryset
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What must you do before passing a Django queryset to cache.set() so it actually caches useful data?"
    options:
      - text: "Nothing; querysets cache correctly as-is"
      - text: "Call list() on it first, so the materialized rows are cached instead of a lazy, unevaluated description of the query"
        correct: true
      - text: "Call .query on it first"
      - text: "Set a longer TIMEOUT value"
    explanation: "A cached, unevaluated queryset can fail to serialize or silently re-run the query on every read, which defeats the cache while looking like it works. list() forces evaluation before caching."

  - id_key: interview-prep-45/test-backend-django/functools-wraps
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A custom decorator's inner wrapper function omits @functools.wraps(func). What's the concrete symptom?"
    options:
      - text: "The decorated function raises an exception every time it's called"
      - text: "generate_report.__name__ becomes \"wrapper\", breaking introspection-based tooling like admin registration or method_decorator chains"
        correct: true
      - text: "The decorator silently stops running the wrapped function's body"
      - text: "Nothing observable changes"
    explanation: "Without functools.wraps, the wrapper function's own name and docstring replace the original function's identity, which breaks anything that inspects a function by name."

  - id_key: interview-prep-45/test-backend-django/transaction-placement
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Where should transaction.atomic() wrap a multi-table write?"
    options:
      - text: "In middleware, so every request is automatically protected"
      - text: "In the view or a service function, directly around the write, since middleware doesn't know your table-level boundaries"
        correct: true
      - text: "In settings.py as a global configuration flag"
      - text: "It doesn't matter, as long as it's somewhere in the request path"
    explanation: "Wrapping every request in a transaction at the middleware level wastes a database connection on read-only GETs that never needed one. The write's own boundary belongs around the write itself."
---
This test covers the Django request lifecycle and middleware chain, how the ORM's lazy querysets actually execute, the select_related/prefetch_related fix for N+1 queries, bulk_create's edges, and Django's own cache framework. Pass 70% to complete the section.

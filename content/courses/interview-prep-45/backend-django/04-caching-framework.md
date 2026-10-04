---
kind: lesson
id_key: interview-prep-45/note-django-cache-framework
course: interview-prep-45
section: backend-django
section_title: "Django"
section_position: 7
section_group: "Backend"
title: "Django's Cache Framework"
position: 4
estimated_minutes: 25
source:
    - interview-prep-notes.md
---

Redis itself, as a general-purpose tool you talk to directly from Python (data structures, cache-aside, invalidation, thundering-herd stampedes), belongs to its own lesson. This lesson is about the layer Django builds on top of that: its own `CACHES` framework, meaning the pluggable backend system, the four levels of granularity you can cache at, and how Django wires caching into views, templates, and HTTP headers.

## Configuration and backends

```python
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://127.0.0.1:6379/1",
        "OPTIONS": {"CLIENT_CLASS": "django_redis.client.DefaultClient"},
        "TIMEOUT": 300,       # seconds; None = never expires
        "KEY_PREFIX": "myapp", # namespacing across apps sharing one backend
    }
}
```

Django doesn't hardcode Redis. `CACHES` names a backend class, and swapping it changes where cached data actually lives without touching any of your call sites.

| Backend | Persistent | Distributed | Notes |
|---|---|---|---|
| `LocMemCache` (default) | No, process memory | No | Zero setup; dev only, never shared across processes |
| `django_redis.cache.RedisCache` | Yes | Yes | The production default; a plain Redis instance wired into Django's cache API |
| `PyMemcacheCache` | No | Yes | Fast, distributed, no complex data types |
| `DatabaseCache` | Yes | Yes | Uses a real table (`manage.py createcachetable`); slower, but needs no new infrastructure |
| `FileBasedCache` | Yes | No | Dev or low-traffic only |
| `DummyCache` | N/A | N/A | Accepts every call and does nothing; swaps caching off in a test or staging environment without touching a single call site |

> **Remember:** `CACHES["BACKEND"]` is the one setting that decides where cached data actually lives. Everything else in this lesson works the same regardless of which backend is plugged in.

```knowledge-check
{ "questions": [
    { "id": "backend-django-cache-backends-q1", "type": "mcq",
      "prompt": "You want to disable caching entirely for a staging environment, without changing any code that calls cache.get()/cache.set(). What's the cleanest way?",
      "options": [
        {"id":"a","text":"Delete every cache.get()/cache.set() call from the codebase for that environment"},
        {"id":"b","text":"Swap CACHES[\"default\"][\"BACKEND\"] to DummyCache for that environment; it accepts every call and does nothing"},
        {"id":"c","text":"Set TIMEOUT to 0 seconds everywhere"},
        {"id":"d","text":"Django cannot disable caching without code changes"}
      ],
      "correct": "b",
      "explanation": "DummyCache implements the same interface as every other backend but never actually stores anything, so every existing cache.get()/cache.set() call keeps working without a single call-site change." }
] }
```

## Four levels of granularity

```
Per-site -> Per-view -> Template fragment -> Low-level (manual)
  (all)      (one view)   (part of a page)   (any Python object)
```

**Per-view** is the one you'll reach for most:

```python
from django.views.decorators.cache import cache_page, never_cache

@cache_page(60 * 15)
def article_list(request):
    ...

@never_cache
def user_dashboard(request):  # personalized -- never cache
    ...
```

**Template fragment** caches part of a page rather than the whole response:

```django
{% load cache %}
{% cache 500 sidebar %}
    {% for item in sidebar_items %}<li>{{ item }}</li>{% endfor %}
{% endcache %}

{# vary per-user by passing an extra key #}
{% cache 500 user_sidebar request.user.id %}...{% endcache %}
```

**The low-level API** caches any Python object manually, and it's the one that maps most directly onto the general cache-aside pattern: check the cache, fall back to computing the value on a miss, then write it back.

```python
from django.core.cache import cache

cache.set("key", value, timeout=300)
value = cache.get("key", default=None)
cache.delete("key")
cache.get_or_set("key", expensive_fn, 300)   # cache-aside in one call
cache.add("key", value, timeout=10)          # sets only if NOT already present, atomic, used for locks
```

> **Remember:** per-view is the everyday default. Reach for template fragments when only part of a page is expensive, and the low-level API when you're caching something that isn't a whole HTTP response at all.

```knowledge-check
{ "questions": [
    { "id": "backend-django-cache-granularity-q1", "type": "mcq",
      "prompt": "A page is mostly cheap to render, except for one expensive sidebar widget shared by every visitor. Which caching level fits best?",
      "options": [
        {"id":"a","text":"Per-site caching"},
        {"id":"b","text":"Template fragment caching, wrapping just the sidebar block"},
        {"id":"c","text":"@never_cache on the whole view"},
        {"id":"d","text":"The low-level API, manually caching the entire rendered HTML page"}
      ],
      "correct": "b",
      "explanation": "Template fragment caching lets you cache just the expensive part of a page while the rest renders normally on every request, which is exactly the granularity this situation calls for." }
] }
```

## Invalidation: signals are Django's specific hook

The general cache-aside invalidation rule is delete-on-write: whenever the underlying data changes, delete the cached copy so the next read recomputes it. Django's specific mechanism for that is model signals, so invalidation fires automatically wherever a model is saved, not just from the one write path you remembered to update by hand.

```python
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

@receiver(post_save, sender=Article)
def invalidate_article_cache(sender, instance, **kwargs):
    cache.delete(f"article:detail:{instance.pk}")

@receiver(post_delete, sender=Article)
def invalidate_on_delete(sender, instance, **kwargs):
    cache.delete(f"article:detail:{instance.pk}")
```

This is stronger than invalidating by hand inside a view or serializer's save path. A signal fires no matter which code path triggered the save, the admin, a shell session, a management command, or a bulk operation calling `.save()` on each object individually, so there's no forgotten call site quietly leaving a stale cache entry behind.

> **Remember:** a model signal invalidates the cache no matter which code path saved the model. A manual cache.delete() inside one view only protects that one path.

```knowledge-check
{ "questions": [
    { "id": "backend-django-cache-signals-q1", "type": "mcq",
      "prompt": "Why is a post_save signal a stronger place to invalidate a cache than a cache.delete() call inside one specific view?",
      "options": [
        {"id":"a","text":"Signals run faster than a direct function call"},
        {"id":"b","text":"A signal fires no matter which code path saved the model (admin, shell, management command), so there's no forgotten call site that leaves stale data cached"},
        {"id":"c","text":"Signals are the only way to call cache.delete() in Django"},
        {"id":"d","text":"There is no real difference between the two approaches"}
      ],
      "correct": "b",
      "explanation": "A cache.delete() placed in one view only protects that one write path. A post_save signal fires for every save of that model, from any code path, closing the gap where a forgotten call site leaves stale data behind." }
] }
```

## Caching a queryset: the gotcha specific to Django

```python
def get_published_articles():
    key = "articles:published"
    articles = cache.get(key)
    if articles is None:
        articles = list(  # must evaluate -- a lazy queryset doesn't serialize
            Article.objects.filter(status="published").select_related("author")
        )
        cache.set(key, articles, 600)
    return articles
```

Django querysets are lazy, and that laziness has a specific consequence for caching: caching an unevaluated queryset either fails to serialize outright, or, worse, silently re-runs the underlying query every time the "cached" value is read back, which defeats the cache entirely while looking like it's working. Always call `list()` on the queryset before handing it to `cache.set`, exactly as above, so what's actually stored is the materialized rows, not a lazy description of how to fetch them.

> **Remember:** call `list()` on a queryset before caching it. Caching the lazy queryset itself, not its evaluated rows, silently re-runs the query on every read.

```knowledge-check
{ "questions": [
    { "id": "backend-django-cache-lazyqueryset-q1", "type": "mcq",
      "prompt": "What goes wrong if you cache.set() an unevaluated Django queryset instead of list(queryset)?",
      "options": [
        {"id":"a","text":"Nothing; querysets serialize identically to lists"},
        {"id":"b","text":"It can fail to serialize, or silently re-run the underlying query every time the cached value is read, defeating the cache while appearing to work"},
        {"id":"c","text":"Django raises a clear error immediately at cache.set() time"},
        {"id":"d","text":"The queryset caches correctly but loses its ordering"}
      ],
      "correct": "b",
      "explanation": "A queryset is a lazy description, not data. Caching it as-is either breaks serialization or, depending on the backend, re-triggers the real query on every read back, which looks like caching but provides none of the benefit." }
] }
```

## HTTP cache headers

```python
from django.views.decorators.cache import cache_control
from django.views.decorators.vary import vary_on_cookie

@cache_control(max_age=3600, public=True)   # browsers/CDN may cache
def public_page(request): ...

@cache_control(private=True, max_age=0)     # never cache in a shared proxy/CDN
def user_profile(request): ...

@vary_on_cookie                              # separate cached copy per session
@cache_page(600)
def my_view(request): ...
```

These decorators control caching in the browser and in any CDN sitting in front of Django, a separate layer from everything above. `@cache_control` and `@vary_on_cookie` never touch Django's own server-side cache backend; they only set response headers that other HTTP caches read and obey.

> **Remember:** `@cache_control`/`@vary_on_cookie` are instructions for caches outside Django (browser, CDN). They don't store anything in Django's own `CACHES` backend.

```knowledge-check
{ "questions": [
    { "id": "backend-django-cache-httpheaders-q1", "type": "mcq",
      "prompt": "Does @cache_control(max_age=3600, public=True) store anything in Django's own CACHES backend?",
      "options": [
        {"id":"a","text":"Yes, it writes an entry into whatever backend CACHES[\"default\"] points to"},
        {"id":"b","text":"No, it only sets a response header that tells the browser and any CDN in front of Django how long they may cache the response"},
        {"id":"c","text":"Yes, but only when LocMemCache is configured"},
        {"id":"d","text":"It replaces the need for CACHES entirely"}
      ],
      "correct": "b",
      "explanation": "cache_control is purely an HTTP-header instruction for caches outside Django. Django's own server-side cache, the CACHES setting, is a completely separate layer that this decorator never touches." }
] }
```

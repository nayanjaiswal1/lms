---
kind: lesson
id_key: interview-prep-45/note-django-cache-framework
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Django's Cache Framework"
position: 102
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

Day 6 covers Redis itself (data structures, cache-aside, invalidation, stampedes) as a general-purpose tool from Python. This note covers the layer on top of that: Django's own `CACHES` framework — the pluggable backend system, the four granularity levels, and how Django wires caching into views, templates, and HTTP headers.

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

| Backend | Persistent | Distributed | Notes |
|---|---|---|---|
| `LocMemCache` (default) | No — process memory | No | Zero setup; dev only, not shared across processes |
| `django_redis.cache.RedisCache` | Yes | Yes | Production default — this is Day 6's Redis, wired into Django's cache API |
| `PyMemcacheCache` | No | Yes | Fast, distributed, no complex data types |
| `DatabaseCache` | Yes | Yes | Uses a real table (`manage.py createcachetable`) — slower, no new infra |
| `FileBasedCache` | Yes | No | Dev/low-traffic only |
| `DummyCache` | — | — | Accepts calls, does nothing — disable caching in a test/staging env without touching call sites |

## Four granularity levels

```
Per-site → Per-view → Template fragment → Low-level (manual)
  (all)      (one view)   (part of a page)   (any Python object)
```

**Per-view**, the most common:

```python
from django.views.decorators.cache import cache_page, never_cache

@cache_page(60 * 15)
def article_list(request):
    ...

@never_cache
def user_dashboard(request):  # personalized — never cache
    ...
```

**Template fragment** — caches part of a page, not the whole response:

```django
{% load cache %}
{% cache 500 sidebar %}
    {% for item in sidebar_items %}<li>{{ item }}</li>{% endfor %}
{% endcache %}

{# vary per-user by passing an extra key #}
{% cache 500 user_sidebar request.user.id %}...{% endcache %}
```

**Low-level API** — manual caching of any Python object, the one that maps most directly onto Day 6's cache-aside pattern:

```python
from django.core.cache import cache

cache.set("key", value, timeout=300)
value = cache.get("key", default=None)
cache.delete("key")
cache.get_or_set("key", expensive_fn, 300)   # cache-aside in one call
cache.add("key", value, timeout=10)          # set only if NOT already present — atomic, used for locks (Day 6)
```

## Cache invalidation: signals, the Django-specific mechanism

Day 6 covers delete-on-write as the general cache-aside invalidation strategy. Django's specific hook for that is model signals, so invalidation happens automatically wherever a model is saved — not just in the one write path you remembered to update:

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

This is stronger than invalidating manually inside a view or serializer's save path — a signal fires regardless of *which* code path triggered the save (admin, shell, a management command, bulk operations that call `.save()` individually), so there's no forgotten call site.

## Caching querysets — the one gotcha specific to Django

```python
def get_published_articles():
    key = "articles:published"
    articles = cache.get(key)
    if articles is None:
        articles = list(  # must evaluate — a lazy queryset doesn't serialize
            Article.objects.filter(status="published").select_related("author")
        )
        cache.set(key, articles, 600)
    return articles
```

Day 22 covers queryset laziness in depth — the caching-specific consequence of that laziness is: caching an unevaluated queryset either fails to serialize or (worse, depending on backend) silently re-executes the query on every cache read, defeating the cache entirely. Always `list()` it first.

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

## Key takeaways

- `CACHES["default"]["BACKEND"]` swaps the storage engine without touching call sites; `django_redis.cache.RedisCache` is Day 6's Redis, wired into Django's API.
- Four levels, coarse to fine: per-site middleware, `@cache_page` per view, `{% cache %}` template fragments, and the low-level `cache.get/set/delete` API for arbitrary objects.
- Model signals (`post_save`/`post_delete`) are Django's mechanism for the delete-on-write invalidation strategy from Day 6 — they fire regardless of which code path triggered the write.
- Always `list()` a queryset before caching it — an unevaluated queryset doesn't serialize cleanly.
- `@cache_control` and `@vary_on_cookie` control browser/CDN-level caching, separate from Django's own server-side cache backend.

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

Redis itself, as a general-purpose tool used directly from Python (data structures, cache-aside, invalidation, thundering-herd stampedes), is covered elsewhere in this course. This note covers the layer on top of that: Django's own `CACHES` framework, meaning the pluggable backend system, the four granularity levels, and how Django wires caching into views, templates, and HTTP headers.

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
| `LocMemCache` (default) | No, process memory | No | Zero setup; dev only, not shared across processes |
| `django_redis.cache.RedisCache` | Yes | Yes | The production default; this is a plain Redis instance wired into Django's cache API |
| `PyMemcacheCache` | No | Yes | Fast, distributed, no complex data types |
| `DatabaseCache` | Yes | Yes | Uses a real table (`manage.py createcachetable`); slower, but needs no new infra |
| `FileBasedCache` | Yes | No | Dev/low-traffic only |
| `DummyCache` | N/A | N/A | Accepts calls, does nothing; use it to disable caching in a test/staging env without touching call sites |

## Four granularity levels

```
Per-site → Per-view → Template fragment → Low-level (manual)
  (all)      (one view)   (part of a page)   (any Python object)
```

**Per-view** is the most common:

```python
from django.views.decorators.cache import cache_page, never_cache

@cache_page(60 * 15)
def article_list(request):
    ...

@never_cache
def user_dashboard(request):  # personalized — never cache
    ...
```

**Template fragment** caches part of a page, not the whole response:

```django
{% load cache %}
{% cache 500 sidebar %}
    {% for item in sidebar_items %}<li>{{ item }}</li>{% endfor %}
{% endcache %}

{# vary per-user by passing an extra key #}
{% cache 500 user_sidebar request.user.id %}...{% endcache %}
```

**Low-level API** is manual caching of any Python object, and it's the one that maps most directly onto the general cache-aside pattern (check the cache, fall back to computing the value, then write it back):

```python
from django.core.cache import cache

cache.set("key", value, timeout=300)
value = cache.get("key", default=None)
cache.delete("key")
cache.get_or_set("key", expensive_fn, 300)   # cache-aside in one call
cache.add("key", value, timeout=10)          # set only if NOT already present, atomic, used for locks
```

## Cache invalidation: signals, the Django-specific mechanism

The general cache-aside invalidation strategy is delete-on-write: whenever the underlying data changes, delete the cached copy so the next read recomputes it. Django's specific hook for that is model signals, so invalidation happens automatically wherever a model is saved, not just in the one write path you remembered to update by hand:

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

This is stronger than invalidating manually inside a view or serializer's save path. A signal fires regardless of which code path triggered the save (the admin, a shell session, a management command, or a bulk operation that calls `.save()` on each object individually), so there's no forgotten call site that leaves a stale cache entry behind.

## Caching querysets: the one gotcha specific to Django

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

Django querysets are lazy: building one with `.filter()` doesn't hit the database, only iterating or otherwise evaluating it does. The caching-specific consequence of that laziness is that caching an unevaluated queryset either fails to serialize outright, or, worse depending on the backend, silently re-executes the underlying query every time the "cached" value is read back, which defeats the cache entirely while looking like it's working. Always call `list()` on the queryset before handing it to `cache.set`, exactly as the snippet above does, so what actually gets cached is the materialized rows, not a lazy description of how to fetch them.

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

These decorators control caching in the browser and any CDN sitting in front of Django, which is a separate layer from everything above: `@cache_control` and `@vary_on_cookie` never touch Django's own server-side cache backend, they only set response headers that other HTTP caches read and obey.

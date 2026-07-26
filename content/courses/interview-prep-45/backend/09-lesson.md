---
kind: lesson
id_key: interview-prep-45/day-09-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "REST API Design"
position: 9
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
API design questions test taste as much as knowledge — "design an API for X" is one of the most common backend interview formats because it reveals whether you think about resources, consistency, and evolvability, or just wire up whatever routes come to mind. Today: the Richardson Maturity Model, full CRUD done properly, pagination/filtering/sorting, and the POST-vs-PUT-vs-PATCH distinction cold.

## The Richardson Maturity Model

A framework for how "RESTful" an API actually is, in four levels:

- **Level 0 — The Swamp of POX**: one endpoint, everything is a POST with an action in the body (`POST /api` with `{"action": "getUser", "id": 42}`). This is RPC-over-HTTP, not REST.
- **Level 1 — Resources**: separate URLs per resource (`/users/42`, `/orders/7`), but still typically only using POST for everything.
- **Level 2 — HTTP verbs**: resources plus proper use of GET/POST/PUT/PATCH/DELETE and HTTP status codes. **This is what "RESTful API" means in practice for almost every real system**, including the one you'll build today.
- **Level 3 — HATEOAS**: responses include links to related actions/resources (`"actions": {"cancel": "/orders/7/cancel"}`), so a client can navigate the API without hardcoding URL structure. Rarely fully implemented in practice — worth knowing the term, not worth over-engineering into a take-home.

Interview answer: know that Level 2 is the practical target, and be able to name what Level 3 would add and why most teams skip it (client complexity, marginal benefit for typical internal/mobile-app API consumers).

## Full CRUD for a resource — blog system example

```python
# FastAPI example — posts, comments, likes
from fastapi import FastAPI, HTTPException, Query, status
from pydantic import BaseModel
from typing import Optional

app = FastAPI()


class PostCreate(BaseModel):
    title: str
    body: str
    author_id: int


class PostUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None


class Post(BaseModel):
    id: int
    title: str
    body: str
    author_id: int
    like_count: int
```

```
POST   /posts                  create a post
GET    /posts                  list posts (paginated, filterable, sortable)
GET    /posts/{id}              fetch one post
PATCH  /posts/{id}              partial update
PUT    /posts/{id}              full replace
DELETE /posts/{id}              delete

GET    /posts/{id}/comments     list comments on a post (nested resource)
POST   /posts/{id}/comments     create a comment on a post

POST   /posts/{id}/likes        like a post (idempotent-in-effect: liking twice = still liked)
DELETE /posts/{id}/likes/me     unlike
```

The nesting choice (`/posts/{id}/comments` vs a flat `/comments?post_id={id}`) is a judgment call worth narrating in an interview: nesting communicates ownership and gives a cleaner URL for "comments on this post," but flat resources are easier to filter/sort generically and avoid deep nesting (`/posts/{id}/comments/{id}/replies/{id}` gets ugly fast — cap nesting at one or two levels and go flat with query params beyond that).

## POST vs PUT vs PATCH

| Verb | Semantics | Idempotent? | Body |
|---|---|---|---|
| `POST` | Create a new resource (server assigns ID), or a non-idempotent action | No | Full or partial resource, or action payload |
| `PUT` | Replace a resource entirely at a known URL | Yes | Full resource — omitted fields should be cleared/defaulted |
| `PATCH` | Partially update a resource | Not guaranteed, but typically implemented as idempotent | Only the fields to change |

**Idempotent** means calling it N times has the same effect as calling it once. `PUT /posts/7` with the same body twice leaves the post in the same state both times — idempotent. `POST /posts` called twice creates two posts — not idempotent. This distinction matters operationally: idempotent methods are safe to blindly retry on a network timeout (you don't know if the first request succeeded, but retrying is harmless); non-idempotent ones need an idempotency key if you want retry-safety (see the Celery idempotency section for the same pattern applied to background jobs).

```python
@app.patch("/posts/{post_id}", response_model=Post)
async def update_post(post_id: int, patch: PostUpdate):
    post = get_post_or_404(post_id)
    update_data = patch.model_dump(exclude_unset=True)  # only fields the client actually sent
    for field, value in update_data.items():
        setattr(post, field, value)
    save_post(post)
    return post


@app.put("/posts/{post_id}", response_model=Post)
async def replace_post(post_id: int, body: PostCreate):
    post = get_post_or_404(post_id)
    post.title = body.title       # PUT sets every field from the request body —
    post.body = body.body          # there is no partial PUT; that's what PATCH is for
    post.author_id = body.author_id
    save_post(post)
    return post
```

`exclude_unset=True` on the Pydantic model is the mechanism that makes `PATCH` genuinely partial — without it, unset fields would come through as their defaults and silently overwrite existing data, turning your PATCH into an accidental PUT.

## Pagination, filtering, sorting

```python
@app.get("/posts", response_model=list[Post])
async def list_posts(
    author_id: Optional[int] = None,
    sort: str = Query("created_at", pattern="^(created_at|like_count)$"),
    order: str = Query("desc", pattern="^(asc|desc)$"),
    limit: int = Query(20, le=100),   # cap page size — never let a client ask for unbounded rows
    cursor: Optional[str] = None,      # opaque cursor, not a raw offset
):
    filters = {}
    if author_id is not None:
        filters["author_id"] = author_id

    posts, next_cursor = post_repository.list(
        filters=filters, sort=sort, order=order, limit=limit, cursor=cursor
    )
    return {"items": posts, "next_cursor": next_cursor}
```

**Offset pagination** (`?page=3&page_size=20`) is simple but degrades on large tables (`OFFSET 60000` still has to scan and discard 60,000 rows) and is inconsistent under concurrent writes (a row inserted on page 1 shifts every later page by one, causing skipped or duplicated rows for a client paging through).

**Cursor pagination** (`?cursor=<opaque token>&limit=20`) encodes the last-seen sort key (e.g. `created_at` + `id` for tie-breaking) into an opaque token, and the query becomes `WHERE (created_at, id) < (last_created_at, last_id) ORDER BY created_at DESC, id DESC LIMIT 20` — an indexed range scan instead of a skip-then-scan, and stable under concurrent inserts. For any interview question about pagination "at scale," lead with cursor pagination and explain why offset breaks down.

## Versioning strategies (preview — full depth on Day 10)

Briefly: URL versioning (`/v1/posts`), header versioning (`Accept: application/vnd.myapi.v1+json`), or query-param versioning (`?version=1`). URL versioning is the most common in practice because it's cacheable, debuggable, and visible in logs — trade-off is it's the most visible/committal choice. Day 10 covers the full decision tree including how to handle breaking changes.

## Key takeaways

- Richardson Level 2 (resources + proper HTTP verbs + status codes) is what "RESTful" means in practice — Level 3 (HATEOAS) is rarely fully built.
- `PUT` replaces a whole resource and is idempotent; `PATCH` updates only the given fields; `POST` creates or performs a non-idempotent action.
- Idempotency is what makes a method safe to retry blindly on a timeout — non-idempotent operations need an explicit idempotency key for that safety.
- `exclude_unset=True` (or the equivalent in your framework) is what makes a PATCH endpoint genuinely partial instead of silently defaulting unset fields.
- Cursor pagination scales and stays consistent under concurrent writes; offset pagination is simpler but degrades and can skip/duplicate rows at scale — know which one to reach for and why.

---
kind: lesson
id_key: interview-prep-45/note-graphql-basics
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: GraphQL Basics (REST vs GraphQL)"
position: 97
estimated_minutes: 20
source:
    - interview-prep-notes.md
---
GraphQL is a query language for APIs — the client specifies exactly which fields it needs in one request, instead of hitting multiple fixed REST endpoints and getting back whatever shape each one returns.

## Query vs mutation

- **Query** — read-only fetch. Client sends a shape, server returns data matching that exact shape (nothing more, nothing less).
- **Mutation** — a write (create/update/delete). Same shape-matching applies to the response, but it's explicitly named `mutation` so tooling/caching layers know it has side effects.

```graphql
query {
  user(id: "1") {
    name
    posts {
      title
    }
  }
}

mutation {
  createPost(title: "Hello", body: "...") {
    id
    title
  }
}
```

## Resolvers

Each field in the schema has a **resolver** — a function that knows how to fetch that specific field's value (from a DB, another service, a cache). The GraphQL server walks the query, calling the resolver for each requested field, and assembles the response tree. This is why GraphQL servers are often described as "a graph of resolvers," not a fixed set of routes.

## The N+1 problem and DataLoader

Naively, resolving `user.posts` for a list of users means one query for the users, then N separate queries — one per user — to fetch each user's posts. That's the N+1 problem, and it's GraphQL's most common performance trap because nested queries make it easy to write resolvers that don't know they're being called in a loop.

**DataLoader** fixes this by batching: within a single tick of the event loop, it collects all the individual `.load(id)` calls, then issues **one** batched query (`WHERE user_id IN (...)`) instead of N separate ones, and also caches results per-request so the same ID isn't fetched twice.

```js
const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.posts.findByUserIds(userIds); // one batched query
  return userIds.map(id => posts.filter(p => p.userId === id));
});

// resolver
posts: (user) => postLoader.load(user.id)
```

## REST vs GraphQL — the actual tradeoff

| | REST | GraphQL |
|---|---|---|
| Over/under-fetching | Common — fixed response shape per endpoint | Client asks for exactly what it needs |
| Number of round trips | Often many (one per resource) | Usually one, even for nested data |
| Caching | Free via HTTP caching (URLs are cache keys) | Harder — needs a normalized client cache (Apollo/Relay) since everything is POST to one endpoint |
| Versioning | `/v1/`, `/v2/` endpoints | Evolve the schema instead — add fields, deprecate old ones |
| Server complexity | Simple — routes map directly to handlers | Higher — resolver graph, N+1 handling, query cost limiting |

Interview framing: GraphQL isn't strictly "better" — it trades HTTP-level caching and simplicity for flexible, client-driven queries. It earns its complexity when a frontend genuinely needs to compose data from many nested/related resources in one round trip (a JD asking for "React.js + GraphQL integration" is asking whether you understand *why* you'd reach for it, not just the syntax).

## Key takeaways

- Query = read, mutation = write; both return exactly the shape the client asked for.
- Resolvers are per-field functions — GraphQL execution is a graph walk, not route matching.
- N+1 is the classic GraphQL performance bug; DataLoader batches + caches to fix it.
- Pick GraphQL when the win is fewer round trips for nested data; pick REST when HTTP caching and simplicity matter more.

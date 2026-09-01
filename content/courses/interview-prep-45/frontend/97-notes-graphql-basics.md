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
GraphQL is a query language for APIs. The client specifies exactly which fields it needs in one request, instead of hitting multiple fixed REST endpoints and getting back whatever shape each one happens to return.

## Query vs mutation

- **Query**: a read-only fetch. The client sends a shape, and the server returns data matching that exact shape, nothing more and nothing less.
- **Mutation**: a write (create/update/delete). The same shape-matching applies to the response, but it's explicitly named `mutation` so tooling and caching layers know it has side effects.

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

Each field in the schema has a **resolver**, a function that knows how to fetch that specific field's value, whether from a database, another service, or a cache. The GraphQL server walks the query, calling the resolver for each requested field, and assembles the response tree from those results. This is why GraphQL servers are often described as "a graph of resolvers" rather than a fixed set of routes.

## The N+1 problem and DataLoader

Naively, resolving `user.posts` for a list of users means one query for the users, then N separate queries, one per user, to fetch each user's posts. That's the N+1 problem. It's GraphQL's most common performance trap, because nested queries make it easy to write a resolver that has no idea it's being called in a loop.

**DataLoader** fixes this by batching. Within a single tick of the event loop, it collects every individual `.load(id)` call, then issues **one** batched query (`WHERE user_id IN (...)`) instead of N separate ones. It also caches results per request, so the same ID is never fetched twice.

```js
const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.posts.findByUserIds(userIds); // one batched query
  return userIds.map(id => posts.filter(p => p.userId === id));
});

// resolver
posts: (user) => postLoader.load(user.id)
```
Say a query resolves `posts` for 20 users. Each call to `posts: (user) => postLoader.load(user.id)` doesn't immediately hit the database; it just registers that user's ID with the loader and returns a pending promise. Once the current tick finishes, DataLoader gathers all 20 collected IDs and calls the batch function exactly once with all of them, then slices the single result set back apart per ID and resolves each of the 20 pending promises with its own slice.

## REST vs GraphQL: the actual tradeoff

| | REST | GraphQL |
|---|---|---|
| Over/under-fetching | Common, since each endpoint has a fixed response shape | The client asks for exactly the fields it needs |
| Number of round trips | Often many, roughly one per resource | Usually one, even for nested data |
| Caching | Free via HTTP caching, since URLs act as cache keys | Harder, since everything is POST to one endpoint; needs a normalized client cache like Apollo or Relay |
| Versioning | Separate `/v1/`, `/v2/` endpoints | Evolve the schema instead: add new fields, deprecate old ones |
| Server complexity | Simple, since routes map directly to handlers | Higher: a resolver graph, N+1 handling, and query cost limiting all need to be built |

Interview framing: GraphQL isn't strictly "better." It trades away HTTP-level caching and server simplicity for flexible, client-driven queries. It earns that complexity when a frontend genuinely needs to compose data from many nested or related resources in one round trip. A job description asking for "React.js + GraphQL integration" is really asking whether you understand why you'd reach for GraphQL, not just its syntax.

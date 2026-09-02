---
kind: lesson
id_key: interview-prep-45/note-graphql-basics
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "GraphQL and Modern Data Fetching"
position: 25
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
A job posting asking for "React + GraphQL" is usually really asking whether you understand why a team would reach for GraphQL at all, not whether you know its syntax. This lesson covers what GraphQL actually changes about fetching data, the performance trap almost every naive resolver falls into, and how a modern client-side query library like React Query handles caching in a way Context never will.

## Query versus mutation

GraphQL is a query language for APIs: the client specifies exactly which fields it needs in a single request, instead of hitting several fixed REST endpoints and getting back whatever shape each one happens to return. A **query** is a read-only fetch, the client sends a shape and the server returns data matching that shape exactly, nothing more. A **mutation** is a write, create, update, delete, and it's explicitly named `mutation` in the syntax so tooling and caching layers know it carries side effects.

```graphql
query {
  user(id: "1") { name posts { title } }
}
mutation {
  createPost(title: "Hello", body: "...") { id title }
}
```

## Resolvers: a graph of functions, not a set of routes

Every field in the schema has a **resolver**, a function that knows how to fetch that one field's value, from a database, another service, or a cache. The server walks the query, calling the resolver for each requested field, and assembles the response tree from the results. That's why GraphQL servers are often described as "a graph of resolvers" rather than a fixed route table.

## The N+1 problem, and the batching fix

Resolving `user.posts` for a list of users, naively, means one query for the users, then N separate queries, one per user, to fetch each user's posts. That's the N+1 problem, and it's GraphQL's most common performance trap, because nested queries make it easy to write a resolver with no idea it's being called in a loop.

**DataLoader** fixes it by batching. Within a single tick of the event loop, it collects every individual `.load(id)` call, then issues exactly one batched query (`WHERE user_id IN (...)`) instead of N separate ones, and it caches results per request so the same ID never gets fetched twice.

```js
const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.posts.findByUserIds(userIds); // one batched query
  return userIds.map(id => posts.filter(p => p.userId === id));
});

// resolver
posts: (user) => postLoader.load(user.id)
```

Say a query resolves `posts` for 20 users. Each call to `posts: (user) => postLoader.load(user.id)` doesn't hit the database immediately; it registers that user's ID with the loader and returns a pending promise. Once the current tick finishes, DataLoader gathers all 20 collected IDs, calls the batch function exactly once with all of them, then slices the single result set back apart per ID and resolves each of the 20 pending promises with its own slice.

## The actual REST-versus-GraphQL trade-off

| | REST | GraphQL |
|---|---|---|
| Over/under-fetching | Common, each endpoint has a fixed shape | Client asks for exactly the fields it needs |
| Round trips | Often many, roughly one per resource | Usually one, even for nested data |
| Caching | Free via HTTP caching, URLs act as cache keys | Harder, everything is POST to one endpoint, needs a normalized client cache (Apollo, Relay) |
| Versioning | Separate `/v1/`, `/v2/` endpoints | Evolve the schema instead, add fields, deprecate old ones |
| Server complexity | Simple, routes map to handlers | Higher: a resolver graph, N+1 handling, query cost limiting |

GraphQL isn't strictly "better." It trades away HTTP-level caching and server simplicity for flexible, client-driven queries, and it earns that trade specifically when a frontend genuinely needs to compose data from many nested or related resources in one round trip.

## React Query: caching that Context structurally can't do

`useQuery` infers its type from the fetcher's return type, so type the fetcher, not the hook call:

```ts
type Policy = { id: number; title: string; version: number };
async function fetchPolicies(): Promise<Policy[]> {
  const res = await fetch('/api/policies');
  return res.json();
}

const { data, isLoading, error } = useQuery<Policy[]>({ queryKey: ['policies'], queryFn: fetchPolicies });
// data is Policy[] | undefined; TS knows the shape before the request even resolves
```

Why reach for a query library over Context for server data: Context re-renders every consumer on any update and gives you nothing for caching, retries, or staleness, all of that would have to be hand-rolled from scratch. React Query dedupes identical in-flight requests fired from multiple components, caches by `queryKey`, retries failed requests, and refetches on window focus or reconnect, all out of the box. Context is still the right tool for low-frequency global state like theme or the current user, just not for data that came from an API in the first place.

For a large, frequently polled list, pairing this with virtualization (covered in the previous lesson) is standard: virtualize the rendering so the DOM stays small, and let the query cache's `queryKey` deduplication stop overlapping components from independently re-fetching the same data.

## Module Federation, in one more concrete example

Micro-frontends get a full lesson of their own later in this course, but the shape of a real Module Federation setup is worth seeing once here, tied to an actual feature rather than the abstract config:

```js
// remote app's webpack config — exposes one component to whoever loads it
new ModuleFederationPlugin({
  name: 'policyApp',
  filename: 'remoteEntry.js',
  exposes: { './PolicyEditor': './src/PolicyEditor' },
  shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
});

// host app — loads it like any other code-split chunk
const PolicyEditor = React.lazy(() => import('policyApp/PolicyEditor'));
```

The detail interviewers listen for hardest is `shared: { react: { singleton: true } }`. Without marking `react`/`react-dom` as singletons, the host and the remote each ship their own copy of React, which breaks hooks and Context outright: two React instances means `useContext` inside the remote can't see a `Provider` rendered by the host, since each copy tracks its own internal context state independently.

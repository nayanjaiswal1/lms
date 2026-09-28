---
kind: lesson
id_key: interview-prep-45/note-graphql-basics
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "GraphQL and Data Fetching"
position: 27
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
A job posting asking for "React plus GraphQL" is usually really asking whether you understand *why* a team would reach for GraphQL at all, not whether you know its syntax. This lesson covers what actually changes when you switch to it, the performance trap almost every new resolver falls into, and how a modern data-fetching library caches in a way plain Context never can.

## Query versus mutation

Imagine ordering at a restaurant where instead of picking from a fixed menu, you tell the kitchen exactly which ingredients you want on your plate, no more, no less. That's what GraphQL does for data: the client states exactly which fields it needs in one request, instead of hitting several fixed REST endpoints and getting back whatever shape each one happens to return.

A **query** is a read: the client describes a shape, and the server returns data matching that shape exactly. A **mutation** is a write, create, update, or delete, and it's named `mutation` specifically so tooling and caching layers know this one has side effects.

```graphql
query {
  user(id: "1") { name posts { title } }
}
mutation {
  createPost(title: "Hello", body: "...") { id title }
}
```

> **Remember:** a query never changes anything on the server. A mutation always might, and it's named that way so caches know to treat it differently.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-graphql-querymut-q1", "type": "mcq",
      "prompt": "Why does GraphQL require write operations to use the keyword mutation instead of query?",
      "options": [
        {"id":"a","text":"It's purely a stylistic convention with no functional effect"},
        {"id":"b","text":"It marks the operation as having side effects, which lets tooling and caching layers treat it differently from a safe, read-only query"},
        {"id":"c","text":"mutation runs faster than query"},
        {"id":"d","text":"query cannot accept any arguments"}
      ],
      "correct": "b",
      "explanation": "The keyword is a signal, not just syntax: caching and tooling can safely assume a query never changes server state, while a mutation might, so they're handled with different guarantees." }
] }
```

## Resolvers: a graph of functions, not a list of routes

Every field in a GraphQL schema has a **resolver**, a function that knows how to produce that one field's value, from a database, another service, or a cache. The server walks the query, calls the resolver for each requested field, and assembles the response tree from the results. That's why people describe a GraphQL server as "a graph of resolvers" rather than a fixed list of routes.

## The N+1 problem, and fixing it with batching

Picture asking a librarian for 20 books, one at a time, walking back to the front desk after each one. Resolving `user.posts` for a list of users, done naively, works the same way: one query fetches the users, then N separate queries, one per user, fetch each one's posts. That's the N+1 problem, GraphQL's single most common performance trap, because a nested query makes it easy to write a resolver with no idea it's being called in a loop.

**DataLoader** fixes it by batching. Within one tick of the event loop, it collects every `.load(id)` call, then fires exactly one query (`WHERE user_id IN (...)`) instead of N separate ones, and it caches results per request so the same ID is never fetched twice.

```js
const postLoader = new DataLoader(async (userIds) => {
  const posts = await db.posts.findByUserIds(userIds); // one batched query
  return userIds.map(id => posts.filter(p => p.userId === id));
});

// resolver
posts: (user) => postLoader.load(user.id)
```

Say a query resolves `posts` for 20 users. Each call to `posts: (user) => postLoader.load(user.id)` doesn't hit the database right away, it registers that ID and returns a pending promise. Once the current tick finishes, DataLoader gathers all 20 IDs, runs the batch function exactly once with all of them, then slices the one result set back apart and resolves each of the 20 waiting promises with its own slice.

> **Remember:** N+1 is one query for the parents, then one query per child. DataLoader collapses that second wave into exactly one batched query.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-graphql-n1-q1", "type": "mcq",
      "prompt": "A resolver for user.posts fires a separate database query for every user in the result list. What's this problem called, and what fixes it?",
      "options": [
        {"id":"a","text":"Cache invalidation, fixed by adding a TTL"},
        {"id":"b","text":"The N+1 problem, fixed by DataLoader batching every .load(id) call within one tick into a single query"},
        {"id":"c","text":"A race condition, fixed with a mutex"},
        {"id":"d","text":"Over-fetching, fixed by trimming the requested fields"}
      ],
      "correct": "b",
      "explanation": "One query for the parents plus one query per child is the textbook N+1 pattern. DataLoader collects every individual load call made in the same tick and turns them into one batched query." }
] }
```

## The real REST-versus-GraphQL trade-off

| | REST | GraphQL |
|---|---|---|
| Over/under-fetching | Common, each endpoint returns a fixed shape | The client asks for exactly the fields it needs |
| Round trips | Often several, roughly one per resource | Usually just one, even for nested data |
| Caching | Free, through normal HTTP caching, URLs act as cache keys | Harder, everything is a POST to one endpoint, needs its own normalized client cache (Apollo, Relay) |
| Versioning | Separate `/v1/`, `/v2/` endpoints | Evolve the schema instead: add fields, deprecate old ones |
| Server complexity | Simple, routes map straight to handlers | Higher: a resolver graph, N+1 handling, query cost limits |

GraphQL isn't strictly "better." It trades away free HTTP-level caching and server simplicity for a client that can shape its own queries, and that trade earns its keep specifically when a frontend genuinely needs to pull together data from many nested or related resources in one round trip.

> **Remember:** GraphQL wins when the frontend needs to compose lots of related data in one trip. REST wins when free HTTP caching matters more than that flexibility.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-graphql-tradeoff-q1", "type": "mcq",
      "prompt": "A team is deciding between REST and GraphQL for a page that only ever needs one flat list of items from one endpoint. Which is the better fit, and why?",
      "options": [
        {"id":"a","text":"GraphQL, because it's always the more modern choice"},
        {"id":"b","text":"REST — with no nested or related data to compose, REST's free HTTP caching and simpler server are a better trade than GraphQL's flexibility, which this page doesn't need"},
        {"id":"c","text":"Neither works for this use case"},
        {"id":"d","text":"GraphQL, because it's always faster than REST"}
      ],
      "correct": "b",
      "explanation": "GraphQL earns its complexity when a client composes many related resources in one request. A single flat list from one endpoint is exactly the case where REST's simplicity and free caching win." }
] }
```

## A query library: caching that Context structurally can't do

`useQuery` infers its type from the fetcher function's return type, so type the fetcher, not the hook call:

```ts
type Policy = { id: number; title: string; version: number };
async function fetchPolicies(): Promise<Policy[]> {
  const res = await fetch('/api/policies');
  return res.json();
}

const { data, isLoading, error } = useQuery<Policy[]>({ queryKey: ['policies'], queryFn: fetchPolicies });
// data is Policy[] | undefined; TypeScript knows the shape before the request even resolves
```

Why reach for a query library over Context for server data: Context re-renders every single consumer on any update, and hands you nothing for caching, retries, or staleness, all of that would have to be built by hand. A query library dedupes identical in-flight requests fired from different components, caches by `queryKey`, retries failed requests automatically, and refetches on window focus or reconnect, all out of the box. Context is still the right tool for low-frequency global values like theme or the current user, just not for data that came from an API to begin with.

For a large, frequently polled list, pairing this with virtualization (the previous lesson) is standard: virtualize the rendering to keep the DOM small, and let the query cache's own deduplication stop several parts of a dashboard from independently re-fetching the same data.

> **Remember:** Context re-renders every consumer and caches nothing. A query library dedupes, caches, and retries automatically, which is why it, not Context, is the right tool for server data.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-graphql-query-q1", "type": "mcq",
      "prompt": "Why is a query library like React Query generally preferred over plain Context for holding data fetched from an API?",
      "options": [
        {"id":"a","text":"Context can't hold objects, only primitives"},
        {"id":"b","text":"Context re-renders every consumer on any update and provides no caching, retry, or staleness handling on its own; a query library dedupes requests, caches by key, and retries automatically"},
        {"id":"c","text":"React Query is faster at rendering components"},
        {"id":"d","text":"Context is deprecated"}
      ],
      "correct": "b",
      "explanation": "Context is a plumbing mechanism, not a data-fetching solution. It has no concept of caching, retries, or deduplication, all of which a query library handles automatically." }
] }
```

## Module Federation, tied to one concrete example

Micro-frontends get their own full lesson later, but it's worth seeing what a real Module Federation setup looks like once here, tied to an actual feature rather than abstract config.

```js
// remote app's webpack config — exposes one component to whoever loads it
new ModuleFederationPlugin({
  name: 'policyApp',
  filename: 'remoteEntry.js',
  exposes: { './PolicyEditor': './src/PolicyEditor' },
  shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
});

// host app — loads it exactly like any other code-split chunk
const PolicyEditor = React.lazy(() => import('policyApp/PolicyEditor'));
```

The detail interviewers listen for hardest is `shared: { react: { singleton: true } }`. Without marking `react`/`react-dom` as singletons, the host and the remote each bundle their own separate copy of React, which breaks hooks and Context outright: with two separate React instances, `useContext` inside the remote can't see a `Provider` rendered by the host, since each copy tracks its own internal state independently.

> **Remember:** two copies of React in one page means two separate context systems that can't see each other. `singleton: true` is what prevents that.

---
kind: lesson
id_key: interview-prep-45/day-17-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "SSR and Next.js"
position: 20
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Every Next.js interview eventually asks "when do you use each rendering strategy, and why?" — a question that's really testing whether you understand the trade-off between build time, request time, and client time. Today covers the four rendering strategies, hydration (the part everyone hand-waves), streaming SSR, and edge functions.

## Next.js rendering strategies

Next.js (App Router, Next.js 13+) gives you four strategies, chosen per route/component rather than app-wide:

| Strategy | When the HTML is generated | Data freshness | Example use |
|---|---|---|---|
| **Static Site Generation (SSG)** | At build time, once | Stale until next build | Marketing pages, docs |
| **Incremental Static Regeneration (ISR)** | At build time, then regenerated in the background on a timer or on-demand | Configurable staleness | Product pages, blog posts |
| **Server-Side Rendering (SSR)** | Per request, on the server | Always fresh | Dashboards, personalized pages |
| **Client-Side Rendering (CSR)** | In the browser, after JS loads | Fresh, but blank until JS runs | Highly interactive widgets behind auth, browser-only APIs |

```tsx
// SSG (default for a Server Component with no dynamic data) — app/blog/page.tsx
async function getPosts() {
  const res = await fetch("https://api.example.com/posts", {
    next: { revalidate: false }, // never revalidate = pure static
  });
  return res.json();
}

export default async function BlogPage() {
  const posts = await getPosts();
  return <PostList posts={posts} />;
}

// ISR — revalidate every 60 seconds, background regeneration
async function getProducts() {
  const res = await fetch("https://api.example.com/products", {
    next: { revalidate: 60 },
  });
  return res.json();
}

// SSR — force fresh data on every request
async function getDashboard(userId: string) {
  const res = await fetch(`https://api.example.com/dashboard/${userId}`, {
    cache: "no-store", // opt out of caching entirely
  });
  return res.json();
}
```

Old Pages Router equivalents (`getStaticProps`, `getStaticPaths`, `getServerSideProps`) map onto the same four strategies but require you to declare the strategy per-file via an exported function; App Router infers it from how you call `fetch` (or whether you call it at all).

```tsx
// pages/products/[id].tsx — Pages Router, for comparison
export async function getStaticPaths() {
  const products = await fetchAllProductIds();
  return {
    paths: products.map((id) => ({ params: { id: String(id) } })),
    fallback: "blocking", // unknown paths render on-demand, then cache
  };
}

export async function getStaticProps({ params }: { params: { id: string } }) {
  const product = await fetchProduct(params.id);
  return { props: { product }, revalidate: 60 };
}
```

**Interview question: "You have a product catalog with 100,000 SKUs. Which strategy?"**
ISR with `fallback: "blocking"` (Pages Router) or `generateStaticParams` returning only the hottest SKUs plus dynamic rendering for the rest (App Router). Pre-building all 100,000 pages at build time is wasteful — most will never be visited. Build the popular ones statically, generate the long tail on first request, then cache it, and revalidate on a timer so prices/stock don't go permanently stale.

## Page with server-rendered data and dynamic routes

```tsx
// app/products/[id]/page.tsx
interface Product {
  id: string;
  name: string;
  price: number;
}

async function getProduct(id: string): Promise<Product> {
  const res = await fetch(`https://api.example.com/products/${id}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) throw new Error("Product not found");
  return res.json();
}

// Pre-render the top SKUs at build time; everything else is generated on first visit.
export async function generateStaticParams() {
  const topProducts = await fetch("https://api.example.com/products/top").then((r) => r.json());
  return topProducts.map((p: Product) => ({ id: p.id }));
}

export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params; // params is a Promise in Next.js 15+
  const product = await getProduct(id);
  return (
    <article>
      <h1>{product.name}</h1>
      <p>${product.price}</p>
    </article>
  );
}
```

## Hydration

Hydration is the step where React attaches event listeners and internal state to server-rendered HTML that's already sitting in the DOM, instead of throwing that markup away and building the DOM from scratch on the client.

The sequence: server renders HTML → browser paints it immediately (fast first paint, no JS required yet) → JS bundle downloads and runs → React walks the existing DOM, matching it against what a client render *would* produce, and attaches handlers.

```tsx
"use client";
import { useState, useEffect } from "react";

function Clock() {
  const [now, setNow] = useState<string | null>(null); // null on server AND on first client render

  useEffect(() => {
    setNow(new Date().toLocaleTimeString()); // only runs client-side, after hydration
  }, []);

  return <p>{now ?? "Loading..."}</p>; // must match between server HTML and first client render
}
```

**Hydration mismatch** is the classic bug: if the server-rendered HTML doesn't match what the client would produce on first render, React either warns and patches the DOM (slow, can flash) or in some cases throws away the tree and re-renders from scratch client-side, losing the point of SSR entirely. Common causes: `Date.now()` or `Math.random()` used directly in render, browser-only APIs (`window`, `localStorage`) read during render instead of in `useEffect`, and locale/timezone differences between server and client.

**Interview question: "What's a hydration mismatch and how do you avoid one?"**
It's when server HTML and the client's first render produce different output, so React's DOM reconciliation on mount doesn't line up. Avoid it by keeping first-render output deterministic and identical on both sides — defer anything environment-dependent (`Date`, `window`, random IDs) to `useEffect`, or use `suppressHydrationWarning` only for genuinely-expected, cosmetic differences like a rendered timestamp.

## Streaming SSR

Traditional SSR blocks on the *slowest* data dependency before sending any HTML. Streaming SSR (React 18+, `Suspense`) sends the shell immediately and streams in slower sections as their data resolves.

```tsx
import { Suspense } from "react";

export default function Dashboard() {
  return (
    <div>
      <Header /> {/* renders immediately, no data dependency */}
      <Suspense fallback={<SkeletonWidget />}>
        <SlowAnalyticsWidget /> {/* streams in later, doesn't block the shell */}
      </Suspense>
      <Suspense fallback={<SkeletonWidget />}>
        <SlowRecommendations />
      </Suspense>
    </div>
  );
}
```

The browser gets the `<Header>` and the loading skeletons in the first flush, then React streams additional HTML chunks (wrapped in `<template>`/script tags) as each Suspense boundary resolves, swapping the fallback for the real content in place — no client-side re-fetch, no layout jump from a full page replace.

**Interview question: "How does streaming SSR improve Time to First Byte vs traditional SSR?"**
Traditional SSR computes the entire page (including the slowest data fetch) before writing anything to the response. Streaming sends the static shell as soon as it's ready and pipes in the rest of the HTML incrementally as async boundaries resolve, so TTFB and First Contentful Paint are decoupled from your slowest dependency.

## Edge functions

Edge functions run your server code in Points of Presence close to the user, geographically distributed, rather than a single origin region — they trade a smaller, faster (V8 isolate, not a full Node process) runtime for lower latency worldwide.

```tsx
// app/api/geo/route.ts
export const runtime = "edge";

export async function GET(request: Request) {
  const country = request.headers.get("x-vercel-ip-country") ?? "unknown";
  return Response.json({ country });
}
```

Trade-offs: edge runtimes don't support the full Node.js API (no `fs`, limited `net`), have tighter memory/CPU limits, and cold starts are typically much faster than a traditional serverless function — which makes edge a good fit for auth checks, redirects, A/B routing, and geolocation, and a bad fit for heavy computation or anything needing full Node APIs.

**Interview question: "Middleware runs on every request — why does Next.js run it at the edge by default?"**
Middleware (auth redirects, locale detection, feature flag routing) needs to run before the response starts and should add minimal latency on every single request. Running it at the edge, geographically close to the user, keeps that per-request tax small; running it in a single origin region would add a network round-trip on top of every page load, everywhere in the world except near that region.

## Key takeaways

- Pick rendering strategy per data-freshness need: SSG/ISR for content that changes rarely, SSR for personalized/always-fresh data, CSR for interactive-only widgets.
- App Router infers the strategy from your `fetch` cache options (`revalidate: false`, a number, or `no-store`) instead of separate exported functions.
- Hydration mismatches come from non-deterministic first renders — defer `Date`, `Math.random`, and `window` reads to `useEffect`.
- Streaming SSR with `Suspense` decouples TTFB from your slowest data dependency by sending the shell first and streaming the rest.
- Edge functions trade full Node API support for lower, globally-distributed latency — good for middleware/auth/routing, not heavy computation.

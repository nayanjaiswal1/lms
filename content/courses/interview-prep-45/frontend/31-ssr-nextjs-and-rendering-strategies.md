---
kind: lesson
id_key: interview-prep-45/day-17-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "SSR, Next.js, and Rendering Strategies"
position: 31
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Every Next.js interview eventually asks "when do you use each rendering strategy, and why?" It's really testing whether you understand the trade-off between build time, request time, and client time. This lesson covers the four rendering strategies, hydration, the specific gap Islands Architecture closes, streaming SSR, edge functions, and, since it comes up constantly for anyone with a Django background, exactly where a traditional server-rendered backend fits once React enters the picture at all.

## Four strategies, chosen per route

Next.js's App Router picks a strategy per route or component, not app-wide.

| Strategy | HTML generated | Data freshness | Example use |
|---|---|---|---|
| Static Site Generation (SSG) | At build time, once | Stale until next build | Marketing pages, docs |
| Incremental Static Regeneration (ISR) | At build time, then refreshed in the background | Configurable staleness | Product pages, blog posts |
| Server-Side Rendering (SSR) | Per request, on the server | Always fresh | Dashboards, personalized pages |
| Client-Side Rendering (CSR) | In the browser, after JS loads | Fresh, but blank until JS runs | Highly interactive widgets behind auth |

```tsx
// SSG — a Server Component with no dynamic data, revalidate: false means "never," pure static
async function getPosts() {
  const res = await fetch("https://api.example.com/posts", { next: { revalidate: false } });
  return res.json();
}

// ISR — revalidate every 60 seconds, regenerated in the background
async function getProducts() {
  const res = await fetch("https://api.example.com/products", { next: { revalidate: 60 } });
  return res.json();
}

// SSR — cache: "no-store" opts out of caching entirely, forcing a fresh fetch every request
async function getDashboard(userId: string) {
  const res = await fetch(`https://api.example.com/dashboard/${userId}`, { cache: "no-store" });
  return res.json();
}
```

The old Pages Router (`getStaticProps`, `getStaticPaths`, `getServerSideProps`) maps onto the same four strategies, just declared per-file via an exported function; App Router infers the strategy from how, or whether, you call `fetch` at all.

Given a product catalog with 100,000 SKUs, which strategy? ISR with `generateStaticParams` returning only the hottest SKUs, plus dynamic rendering for the long tail. Pre-building all 100,000 pages at build time wastes effort on pages most of which will never be visited; build the popular ones statically, generate the rest on first request and cache it, then revalidate on a timer so prices and stock don't go permanently stale.

## Hydration: attaching behavior to markup that's already there

Hydration is the step where React attaches event listeners and internal state to server-rendered HTML already sitting in the DOM, instead of throwing that markup away and building it fresh on the client.

The sequence: the server renders HTML, the browser paints it immediately, a fast first paint with no JS required yet, the JS bundle downloads and runs, and React walks the existing DOM, matching it against what a client render *would* produce, then attaches handlers.

```tsx
"use client";
function Clock() {
  const [now, setNow] = useState<string | null>(null); // null on server AND on first client render
  useEffect(() => { setNow(new Date().toLocaleTimeString()); }, []); // only runs client-side, after hydration
  return <p>{now ?? "Loading..."}</p>; // must match between server HTML and first client render
}
```

A **hydration mismatch** is the classic bug: if server HTML doesn't match what the client would produce on its own first render, React either warns and patches the DOM, slow, can visibly flash, or in some cases discards the tree and re-renders entirely client-side, losing the point of SSR altogether. Common causes: `Date.now()` or `Math.random()` used directly during render, browser-only APIs like `window` or `localStorage` read during render instead of inside `useEffect`, and locale or timezone differences between server and client. What's a hydration mismatch, and how do you avoid one? It's server HTML and the client's first render producing different output, so React's reconciliation on mount doesn't line up. Avoid it by keeping first-render output deterministic on both sides, defer anything environment-dependent to `useEffect`, and reach for `suppressHydrationWarning` only for genuinely expected, cosmetic differences like a rendered timestamp.

## The hydration gap Islands Architecture actually closes

There's a second cost worth naming separately from the mismatch bug above: even a *correct* hydration has a window where the HTML is painted and looks interactive, but React hasn't attached any event listeners yet. A click during that window can be dropped, silently swallowed, or queued and replayed late. The default SSR/SSG/ISR approach hydrates the *entire* page in one pass, so that window scales with total page JS, not with how much of the page is actually interactive, meaning a mostly-static blog post with one comment widget still pays for hydrating the whole tree.

**Islands Architecture** is the fix: render everything as static HTML, then hydrate only the interactive "islands," a carousel, a comment form, a cart widget, independently, each with its own small JS bundle. The surrounding static content never hydrates at all, no listeners attached, no JS shipped for it, which shrinks both the hydration-gap window and the total JS payload. The cost is that each island has to be a genuinely isolated component with no assumed shared client-side state with its neighbors, cross-island communication needs an explicit mechanism, events, a shared store, or URL state, since no single client-side app tree connects them. Astro is the framework most associated with this pattern; React Server Components achieve a related goal, not shipping JS for non-interactive parts, through a different mechanism entirely, server/client component boundaries inside one unified tree, rather than physically separate islands.

## Streaming SSR

Traditional SSR blocks on the *slowest* data dependency before sending any HTML at all. Streaming SSR (React 18+, via `Suspense`) sends the shell immediately and streams in slower sections as their data resolves.

```tsx
export default function Dashboard() {
  return (
    <div>
      <Header /> {/* renders immediately, no data dependency */}
      <Suspense fallback={<SkeletonWidget />}><SlowAnalyticsWidget /></Suspense>
      <Suspense fallback={<SkeletonWidget />}><SlowRecommendations /></Suspense>
    </div>
  );
}
```

The browser gets `<Header>` and the loading skeletons in the first flush, then React streams additional HTML chunks in as each `Suspense` boundary resolves, swapping the fallback for real content in place, no client-side re-fetch, no layout jump from a full-page replace. How does streaming SSR improve Time to First Byte over traditional SSR? Traditional SSR computes the entire page, including the slowest fetch, before writing anything to the response. Streaming sends the static shell the instant it's ready and pipes in the rest incrementally as async boundaries resolve, decoupling TTFB and First Contentful Paint from whatever the slowest dependency happens to be.

## Edge functions

Edge functions run server code in points of presence close to the user, geographically distributed, rather than a single origin region, trading a smaller, faster runtime, a V8 isolate, not a full Node process, for lower latency worldwide.

```tsx
export const runtime = "edge";
export async function GET(request: Request) {
  const country = request.headers.get("x-vercel-ip-country") ?? "unknown";
  return Response.json({ country });
}
```

Edge runtimes don't support the full Node API, no `fs`, limited `net`, and have tighter memory and CPU limits, but cold starts are typically much faster than a traditional serverless function, which makes edge a good fit for auth checks, redirects, A/B routing, and geolocation, and a poor fit for heavy computation or anything genuinely needing full Node APIs. Middleware runs on every single request; why does Next.js run it at the edge by default? Because auth redirects, locale detection, and feature-flag routing need to run before the response starts and should add minimal latency on every request. Running it geographically close to the user keeps that per-request tax small; running it in one origin region would add a network round trip on top of every page load everywhere else in the world.

## Where a Django (or any traditional SSR) backend actually sits once React enters

Django's default templating, `render(request, template, context)`, is SSR in the literal sense, full HTML computed and returned per request. But it's missing everything a Next.js or Remix SSR setup assumes comes bundled with the term: no hydration step, no client-side router, no virtual DOM diffing. Every link click and form submit is a full page reload and a fresh server round trip; it's the rendering model the industry used before "SSR" needed a name to distinguish it from CSR at all.

The moment a Django backend becomes a REST or JSON API sitting behind a separate React frontend, it exits this rendering conversation entirely. It's no longer rendering anything, only serving data, and every CSR-versus-SSR-versus-SSG-versus-ISR question from this lesson applies to the React layer alone. Django's job at that point is API design, auth, and data, a backend concern, not a rendering one. This is really the same lesson as Islands Architecture from a different angle: one is about shrinking what gets hydrated on the client, the other is about recognizing the exact moment a server stops participating in rendering at all.

## Tying it together

The four strategies, hydration, streaming, and edge functions all answer the same underlying question: how much of the work can move earlier, build time, or a nearby edge location, versus how much genuinely has to wait for the request itself. An interviewer probing any one of these is usually checking whether you can place a given feature, a dashboard, a product page, an auth check, correctly on that spectrum, not just recite the API names involved.

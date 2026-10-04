---
kind: lesson
id_key: interview-prep-45/day-17-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "SSR and Next.js"
position: 30
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Every Next.js interview eventually asks "when do you use each rendering strategy, and why?" It's really testing whether you understand the trade-off between doing work at build time, at request time, or in the browser. This lesson covers the four strategies, hydration, the gap Islands Architecture closes, streaming, edge functions, and where a plain server-rendered backend like Django actually sits once React enters the picture.

## Four strategies, picked per page

Next.js's App Router picks a strategy per route or component, not for the whole app at once.

| Strategy | HTML generated | Data freshness | Example use |
|---|---|---|---|
| Static Site Generation (SSG) | At build time, once | Stale until the next build | Marketing pages, docs |
| Incremental Static Regeneration (ISR) | At build time, refreshed later in the background | However stale you configure it to be | Product pages, blog posts |
| Server-Side Rendering (SSR) | Per request, on the server | Always fresh | Dashboards, personalized pages |
| Client-Side Rendering (CSR) | In the browser, after JavaScript loads | Fresh, but blank until JS runs | Highly interactive widgets behind a login |

```tsx
// SSG — no dynamic data, revalidate: false means "never," pure static
async function getPosts() {
  const res = await fetch("https://api.example.com/posts", { next: { revalidate: false } });
  return res.json();
}

// ISR — refresh every 60 seconds, regenerated in the background
async function getProducts() {
  const res = await fetch("https://api.example.com/products", { next: { revalidate: 60 } });
  return res.json();
}

// SSR — cache: "no-store" opts out of caching entirely, forcing a fresh fetch on every request
async function getDashboard(userId: string) {
  const res = await fetch(`https://api.example.com/dashboard/${userId}`, { cache: "no-store" });
  return res.json();
}
```

Given a product catalog with 100,000 SKUs, which strategy fits? ISR with `generateStaticParams` returning only the hottest SKUs, plus dynamic rendering for the long tail. Pre-building all 100,000 pages at build time wastes effort on pages most people will never visit, build the popular ones statically, generate the rest on their first request and cache it, then refresh on a timer so prices don't go permanently stale.

> **Remember:** the question behind every rendering-strategy choice is the same one, how much of the work can happen earlier than the actual request.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-ssr-strategy-q1", "type": "mcq",
      "prompt": "A product catalog has 100,000 SKUs, but only a few hundred get most of the traffic. What's the best rendering strategy?",
      "options": [
        {"id":"a","text":"Pre-build all 100,000 pages with SSG at build time"},
        {"id":"b","text":"ISR: statically generate the popular pages ahead of time, generate the long tail on first request and cache it, then revalidate on a schedule"},
        {"id":"c","text":"Render every page fresh on every single request with SSR"},
        {"id":"d","text":"Render the entire catalog client-side with no server rendering at all"}
      ],
      "correct": "b",
      "explanation": "Pre-building all 100,000 pages wastes build time on pages almost nobody visits. ISR lets you build the hot pages ahead of time and generate the rest lazily, refreshing on a schedule so nothing goes permanently stale." }
] }
```

## Hydration: attaching behavior to markup that's already there

Hydration is the step where React attaches event listeners and internal state to HTML the server already rendered, instead of throwing that markup away and building it fresh on the client.

The sequence: the server sends HTML, the browser paints it right away, a fast first view with no JavaScript required yet, the JS bundle downloads and runs, and React walks the existing DOM, matching it against what a client render *would* have produced, then attaches its handlers.

```tsx
"use client";
function Clock() {
  const [now, setNow] = useState<string | null>(null); // null on the server AND on the first client render
  useEffect(() => { setNow(new Date().toLocaleTimeString()); }, []); // only ever runs client-side, after hydration
  return <p>{now ?? "Loading..."}</p>; // must match between server HTML and the first client render
}
```

A **hydration mismatch** is the classic bug: if the server's HTML doesn't match what the client would produce on its own first render, React either warns and patches the DOM, slow, and it can visibly flash, or discards the whole tree and re-renders it fully client-side, losing the point of SSR altogether. Common causes: `Date.now()` or `Math.random()` used directly during render, a browser-only value like `window` or `localStorage` read during render instead of inside `useEffect`, and locale or timezone differences between server and client.

What's a hydration mismatch, in one sentence? Server HTML and the client's first render produce different output, so React's mount-time comparison doesn't line up. Avoid it by keeping the very first render's output identical on both sides, push anything environment-dependent into `useEffect`, and reach for `suppressHydrationWarning` only for genuinely expected, cosmetic differences like a rendered timestamp.

> **Remember:** a hydration mismatch means the server's HTML and the client's first render disagree. Fix it by keeping the first render deterministic on both sides.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-ssr-hydration-q1", "type": "mcq",
      "prompt": "A component reads window.innerWidth directly inside its render function, and gets a hydration mismatch warning. What's the fix?",
      "options": [
        {"id":"a","text":"Read window.innerWidth inside useEffect instead, so it only runs after hydration on the client, and use a deterministic value for the very first render"},
        {"id":"b","text":"Add more CSS to hide the mismatch"},
        {"id":"c","text":"Switch the component to a class component"},
        {"id":"d","text":"Nothing can be done, this component simply can't be server-rendered"}
      ],
      "correct": "a",
      "explanation": "window doesn't exist on the server, so reading it during render produces different output server-side versus client-side. Moving that read into useEffect defers it until after the deterministic first render matches on both sides." }
] }
```

## The hydration gap Islands Architecture closes

There's a second cost, separate from the mismatch bug above: even a *correct* hydration has a window where the HTML is painted and looks ready, but React hasn't attached any listeners yet. A click during that window can get dropped or queued and replayed late. The default approach hydrates the *entire* page in one pass, so that window scales with the page's total JavaScript, not with how much of the page is actually interactive, meaning a mostly-static blog post with one comment box still pays for hydrating the whole tree.

**Islands Architecture** is the fix: render everything as plain static HTML, then hydrate only the interactive "islands," a carousel, a comment form, a cart widget, independently, each with its own small bundle. The rest of the page never hydrates at all, no listeners attached, no JS shipped for it, which shrinks both the hydration window and the total JS payload. The cost is that each island has to be a genuinely isolated component with no shared client-side state assumed between neighbors, communication between islands needs an explicit mechanism, events, a shared store, or the URL, since there's no single app tree connecting them. Astro is the framework most associated with this pattern; React Server Components reach a related goal, not shipping JS for non-interactive parts, through a different mechanism, a server/client boundary inside one unified tree, rather than physically separate islands.

> **Remember:** the default approach hydrates the whole page at once. Islands Architecture only hydrates the pieces that are actually interactive.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-ssr-islands-q1", "type": "mcq",
      "prompt": "A mostly-static blog post has one small comment widget. Under the default full-page hydration model, what does that widget cost the rest of the page?",
      "options": [
        {"id":"a","text":"Nothing, only the widget itself pays any hydration cost"},
        {"id":"b","text":"The entire page still has to hydrate as one unit, so the static content pays a hydration cost proportional to the whole page's JS, not just the widget's"},
        {"id":"c","text":"The page skips hydration entirely"},
        {"id":"d","text":"Only the images near the widget are affected"}
      ],
      "correct": "b",
      "explanation": "Standard SSR/SSG hydrates the whole page in one pass. Islands Architecture is specifically the fix for this: it hydrates only the interactive widget and leaves the static content with zero JS and no hydration at all." }
] }
```

## Streaming SSR

Traditional SSR waits for the *slowest* data dependency before sending any HTML at all. Streaming SSR (React 18 and later, through `Suspense`) sends the page shell immediately and streams in the slower sections as their data becomes ready.

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

The browser gets `<Header>` and the loading skeletons in the very first chunk, then React streams in more HTML as each `Suspense` boundary resolves, swapping the fallback for real content in place, with no client-side re-fetch and no layout jump from a full-page swap.

> **Remember:** streaming sends the shell the instant it's ready and pipes in the rest as it resolves, instead of waiting for the single slowest piece to hold up everything.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-ssr-streaming-q1", "type": "mcq",
      "prompt": "How does streaming SSR improve Time to First Byte compared to traditional SSR?",
      "options": [
        {"id":"a","text":"It makes the server's database queries run faster"},
        {"id":"b","text":"Traditional SSR waits for the entire page, including the slowest fetch, before sending anything; streaming sends the static shell immediately and pipes in the rest as each async boundary resolves"},
        {"id":"c","text":"It skips server rendering entirely and renders on the client instead"},
        {"id":"d","text":"It compresses the HTML more aggressively"}
      ],
      "correct": "b",
      "explanation": "Streaming decouples the first byte from the slowest dependency: the shell goes out right away, and slower sections arrive as separate chunks once they're actually ready." }
] }
```

## Edge functions

Edge functions run server code at points of presence physically close to the user, instead of one single origin region, trading a smaller runtime (a V8 isolate, not a full Node process) for lower latency worldwide.

```tsx
export const runtime = "edge";
export async function GET(request: Request) {
  const country = request.headers.get("x-vercel-ip-country") ?? "unknown";
  return Response.json({ country });
}
```

Edge runtimes don't support the full Node API, no `fs`, limited `net`, and they have tighter memory and CPU limits, but their cold starts are typically much faster than a regular serverless function, which makes edge a good fit for auth checks, redirects, A/B routing, and geolocation, and a poor fit for heavy computation or anything genuinely needing full Node APIs.

Middleware runs on every single request; why does Next.js run it at the edge by default? Because auth redirects, locale detection, and feature-flag routing all need to run before the response even starts, and should add almost no latency to every request. Running it physically close to the user keeps that per-request cost small; running it from one origin region would add a network round trip on top of every single page load everywhere else in the world.

> **Remember:** edge functions trade full Node capability for a much faster cold start close to the user, a good fit for small, fast, per-request checks, not heavy computation.

## Where a Django-style backend sits once React enters

Django's default templating, `render(request, template, context)`, is SSR in the literal sense: full HTML computed and returned per request. But it's missing everything a Next.js or Remix SSR setup assumes comes with the term: no hydration step, no client-side router, no virtual DOM diffing. Every link click and form submit is a full page reload and a fresh trip to the server. It's the rendering model the industry used before "SSR" needed a name to tell it apart from CSR at all.

The moment a Django backend turns into a REST or JSON API sitting behind a separate React frontend, it steps out of this whole conversation entirely. It's not rendering anything anymore, only serving data, and every CSR-versus-SSR-versus-SSG-versus-ISR question in this lesson applies to the React layer alone. Django's job at that point is API design, auth, and data, a backend concern, not a rendering one.

> **Remember:** the moment a backend only returns JSON, it has left the rendering conversation. Every rendering-strategy question from here on applies to the frontend layer, not the backend.

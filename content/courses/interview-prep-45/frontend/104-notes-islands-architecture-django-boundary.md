---
kind: lesson
id_key: interview-prep-45/note-islands-architecture-django-boundary
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Islands Architecture and Where Django Fits in the Rendering Spectrum"
position: 104
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The rendering-strategy lesson on CSR, SSR, SSG, and ISR covers hydration, hydration mismatches, and streaming SSR in depth. This note adds the two pieces that lesson doesn't: Islands Architecture, and where a Django backend actually sits once it's paired with a separate React frontend.

## The hydration gap, and how Islands avoids it

A hydration mismatch (a non-deterministic first render producing different HTML on server and client) is one cost of hydration. There's a separate cost worth naming: even a *correct* hydration has a window where the HTML is painted and looks interactive, but React hasn't attached event listeners yet. A click during that window can be dropped, silently swallowed, or queued and replayed late.

The default SSR/SSG/ISR approach hydrates the *entire* page in one pass, so that window scales with total page JS, not with how much of the page is actually interactive. A mostly-static blog post with one comment widget still pays for hydrating the whole tree.

**Islands Architecture** is the fix: render everything as static HTML, then hydrate only the interactive "islands" (a carousel, a comment form, a cart widget) independently, each with its own small JS bundle. The surrounding static content never hydrates at all: no listeners attached, no JS shipped for it. This shrinks both the hydration-gap window and the total JS payload. The cost is that each island has to be an isolated component that doesn't assume shared client-side state with its neighbors; cross-island communication needs an explicit mechanism such as events, a shared store, or URL state, since there's no single client-side app tree connecting them.

Astro is the framework most associated with this pattern. React Server Components achieve a related goal, not shipping JS for non-interactive parts, through a different mechanism: server/client component boundaries inside one unified component tree, rather than physically separate islands.

## Where Django sits in this spectrum

Django's default templating (`render(request, template, context)`) is SSR in the literal sense: full HTML computed and returned per request. But it's missing everything a Next.js/Remix SSR setup assumes comes with the term: no hydration step, no client-side router, no virtual DOM diffing. Every link click and form submit is a full page reload and a fresh server round-trip. It's the rendering model the industry used before "SSR" needed a name to distinguish it from CSR.

The moment a Django backend becomes a REST/JSON API sitting behind a separate React (or any SPA) frontend, Django exits this conversation entirely. It's no longer rendering anything, just serving data. At that point, every CSR-vs-SSR-vs-SSG-vs-ISR question applies to the React layer only, and Django's job becomes API design, auth, and data, which is a backend-section topic, not a rendering one.

Islands Architecture and this Django boundary are really the same lesson from two directions: one is about shrinking what gets hydrated on the client, the other is about recognizing when a server stops participating in rendering at all.

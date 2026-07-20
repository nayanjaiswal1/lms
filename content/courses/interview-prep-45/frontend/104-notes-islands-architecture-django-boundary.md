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

Day 17 already covers the four rendering strategies (CSR/SSR/SSG/ISR), hydration, hydration mismatches, and streaming SSR in depth — this note only adds the two pieces that lesson doesn't: Islands Architecture, and where a Django backend actually sits in this whole conversation once it's paired with a separate React frontend.

## The hydration gap, and how Islands avoids it

Day 17 covers hydration mismatches (non-deterministic first renders). There's a separate cost worth naming: even a *correct* hydration has a window — HTML is painted and looks interactive, but React hasn't attached event listeners yet. A click during that window can be dropped, silently swallowed, or queued and replayed late.

The default SSR/SSG/ISR approach hydrates the *entire* page in one pass, so that window scales with total page JS, not with how much of the page is actually interactive — a mostly-static blog post with one comment widget still pays for hydrating the whole tree.

**Islands Architecture** is the fix: render everything as static HTML, then hydrate only the interactive "islands" (a carousel, a comment form, a cart widget) independently, each with its own small JS bundle. The surrounding static content never hydrates at all — no listeners attached, no JS shipped for it. This shrinks both the hydration-gap window and the total JS payload, at the cost of each island needing to be an isolated component that doesn't assume shared client-side state with its neighbors (cross-island communication needs an explicit mechanism — events, a shared store, or URL state — since there's no single client-side app tree connecting them). Astro is the framework most associated with this pattern; RSC (Day 21) achieves a related goal (not shipping JS for non-interactive parts) through a different mechanism — server/client component boundaries in one unified tree, rather than physically separate islands.

## Where Django sits in this spectrum

Django's default templating (`render(request, template, context)`) is SSR in the literal sense — full HTML computed and returned per request — but it's missing everything Day 17 assumes comes with SSR in a Next.js/Remix context: no hydration step, no client-side router, no virtual DOM diffing. Every link click and form submit is a full page reload and a fresh server round-trip. It's the rendering model the industry used before "SSR" needed a name to distinguish it from CSR.

The moment a Django backend becomes a REST/JSON API sitting behind a separate React (or any SPA) frontend, Django exits this conversation entirely — it's no longer rendering anything, just serving data. At that point, *all* of Day 17's rendering-strategy questions (CSR vs SSR vs SSG vs ISR) apply to the React layer only, and Django's job is API design, auth, and data — covered in the backend section of this course, not here.

## Key takeaways

- Islands Architecture hydrates only the interactive parts of a page independently, instead of the whole tree at once — smaller JS payload, smaller hydration-gap window, but islands can't assume shared client state with each other.
- RSC (Day 21) solves a similar "don't ship JS for static parts" problem, but via server/client component boundaries in one tree, not physically separate islands.
- Django's built-in templating is SSR without hydration, client routing, or a virtual DOM — full reload per navigation.
- Once Django becomes a pure REST API behind a separate frontend, the CSR/SSR/SSG/ISR question moves entirely to that frontend; Django's concern becomes API design (backend section), not rendering.

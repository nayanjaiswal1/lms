---
kind: quiz
id_key: interview-prep-45/test-frontend-3
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Practice Test: Performance, Architecture and Production"
position: 38
estimated_minutes: 35
pass_percentage: 70
duration_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
questions:
    - id_key: interview-prep-45/test-frontend-3/http-nostore-vs-nocache
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "What's the practical difference between Cache-Control: no-cache and Cache-Control: no-store?"
      options:
        - text: "no-cache stores the response but always revalidates with the server before using it; no-store never saves the response anywhere at all"
          correct: true
        - text: "They mean exactly the same thing"
        - text: "no-store is just a faster version of no-cache"
        - text: "no-cache only applies to images"
      explanation: "no-cache keeps a copy but forces a check with the server on every use. no-store is the stronger setting: nothing is saved anywhere, the right choice for anything carrying auth tokens or personal data."
    - id_key: interview-prep-45/test-frontend-3/webvitals-fielddata
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A page passes Lighthouse with a perfect score, but its real Core Web Vitals in Google Search Console are poor. What explains this?"
      options:
        - text: "Lighthouse's lab data comes from one simulated device and network; field data reflects the real mix of devices and networks actual visitors use, and ranking is based on field data"
          correct: true
        - text: "Lighthouse and Search Console measure completely unrelated things with no connection at all"
        - text: "This can never actually happen"
        - text: "Search Console data is always less accurate than Lighthouse"
      explanation: "Lab data is diagnostic, from one simulated setup. A page can look perfect in that one simulation and still perform poorly for real users on slower devices or networks, which is exactly what field data captures."
    - id_key: interview-prep-45/test-frontend-3/splitting-errorboundary
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A React.lazy component's chunk fails to download because the network drops mid-fetch. What actually handles this failure?"
      options:
        - text: "Suspense's fallback UI shows an error message automatically"
        - text: "An error boundary wrapped around the Suspense boundary, since Suspense only knows how to handle the pending state, never a rejected import"
          correct: true
        - text: "React.lazy retries the download automatically forever"
        - text: "Nothing, this scenario can't be handled and always crashes the app"
      explanation: "Suspense shows its fallback while the import() promise is pending. It has no concept of failure. Only an error boundary around it can catch the rejection and show a real error state."
    - id_key: interview-prep-45/test-frontend-3/virtualization-costs
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "A list has about 150 items. Is virtualizing it worth the added complexity?"
      options:
        - text: "No — the plain DOM handles a few hundred nodes fine; virtualization pays off once the count is genuinely unbounded or already in the thousands"
          correct: true
        - text: "Yes, always virtualize any list no matter its size"
        - text: "Only if every item contains an image"
        - text: "Yes, since virtualization has no real downside"
      explanation: "Virtualization breaks native find-in-page, select-all-copy, and anchor scrolling, and adds real implementation complexity. At 150 items, none of that cost buys anything a plain rendered list wasn't already handling."
    - id_key: interview-prep-45/test-frontend-3/graphql-n1-dataloader
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A GraphQL resolver for user.posts fires one separate database query per user in the result list. What's this called, and what fixes it?"
      options:
        - text: "The N+1 problem, fixed by DataLoader batching every .load(id) call made within one event-loop tick into a single query"
          correct: true
        - text: "Over-fetching, fixed by asking the client to request fewer fields"
        - text: "A race condition, fixed with a mutex around the resolver"
        - text: "Cache penetration, fixed by caching a 'not found' result"
      explanation: "One query for the parents plus one query per child is the textbook N+1 pattern. DataLoader collects every individual load call in the same tick and turns them into one batched query instead."
    - id_key: interview-prep-45/test-frontend-3/security-csrf-token
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "An app stores its auth token in memory and attaches it manually through an Authorization header on every request, never in a cookie. Is this token exposed to a CSRF attack?"
      options:
        - text: "No — CSRF exploits the browser's automatic cookie attachment; a forged cross-site form can neither read the token nor set a custom Authorization header itself"
          correct: true
        - text: "Yes, exactly as exposed as a cookie-based token would be"
        - text: "Only if the site also uses CORS"
        - text: "Only on mobile browsers"
      explanation: "CSRF specifically relies on the browser attaching credentials for you. A manually-attached header can't be replicated by a forged form, so this setup is safe from CSRF, though it does trade that for exposure to XSS instead, since anything in memory or storage is readable by an injected script."
    - id_key: interview-prep-45/test-frontend-3/security-xss-escape
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "Does rendering {comment.text} inside JSX protect against XSS if comment.text contains an <img> tag with an onerror handler?"
      options:
        - text: "Yes — JSX escapes content rendered through {value} automatically, showing it as plain text instead of parsing it as markup"
          correct: true
        - text: "No, JSX renders any string as raw HTML by default"
        - text: "Only if the string is first passed through JSON.stringify"
        - text: "Only in production builds"
      explanation: "React's {value} interpolation escapes its content by default. The only way to render raw, unescaped HTML in React is the explicitly named dangerouslySetInnerHTML."
    - id_key: interview-prep-45/test-frontend-3/websockets-closecode
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A WebSocket client's onclose handler checks event.code === 1000 before deciding whether to reconnect. Why?"
      options:
        - text: "Code 1000 means the connection closed normally and on purpose; every other code means something unexpected happened, so only those should trigger a reconnect"
          correct: true
        - text: "Code 1000 means the server rejected the connection outright"
        - text: "This check has no real effect on reconnection behavior"
        - text: "1000 is the code for a successful message delivery, unrelated to closing"
      explanation: "Without this check, either an intentional close triggers an unwanted reconnect loop, or a genuine drop looks identical to a clean close and never gets recovered. The close code is what tells the two apart."
    - id_key: interview-prep-45/test-frontend-3/ssr-hydration-mismatch
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A component reads Math.random() directly during render to pick a background color, and gets a hydration mismatch warning. Why?"
      options:
        - text: "The server and the client each generate a different random value during their own render, so the server's HTML never matches the client's first render output"
          correct: true
        - text: "Math.random() is not allowed anywhere in a React component"
        - text: "The component needs a key prop"
        - text: "Hydration warnings are unrelated to what happens during render"
      explanation: "A hydration mismatch happens whenever the server's HTML and the client's own first render disagree. Math.random() during render is a classic cause, since the server and client each compute their own independent random value."
    - id_key: interview-prep-45/test-frontend-3/microfrontends-singleton
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A shell app and a remote app are composed with Module Federation, but neither marks react as a shared singleton. What breaks?"
      options:
        - text: "Invalid hook call errors, since the shell and the remote each ship their own separate copy of React managing what's supposed to be one component tree"
          correct: true
        - text: "Nothing, this is the normal and recommended setup"
        - text: "Only CSS styling conflicts occur"
        - text: "The build fails to compile"
      explanation: "Without singleton: true, each side bundles its own React. Two separate React instances can't correctly share one component tree, which is exactly what causes Invalid hook call errors."
    - id_key: interview-prep-45/test-frontend-3/buildtools-treeshake-cjs
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "Why does a CommonJS require() call generally defeat tree shaking, while an ES module import doesn't?"
      options:
        - text: "require() calls can be conditional or built dynamically, so a bundler can't statically prove what's actually used without running the code; import/export are readable without running anything"
          correct: true
        - text: "CommonJS modules are always larger in file size"
        - text: "require() is deprecated and produces a build error"
        - text: "Tree shaking only works on TypeScript files, never plain JavaScript"
      explanation: "Tree shaking depends on being able to prove, just by reading the code, which exports are actually used. ES module import/export statements are statically readable; a require() call can be wrapped in a condition, which a bundler can't safely reason about ahead of time."
    - id_key: interview-prep-45/test-frontend-3/accessibility-ariafirst
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "A developer builds a clickable element with <div role=\"button\" onClick={...}> instead of a real <button>. What are they still responsible for adding themselves?"
      options:
        - text: "Keyboard focusability and activation on Enter/Space, since role=\"button\" only describes the semantics, it grants none of a real button's built-in behavior"
          correct: true
        - text: "Nothing, role=\"button\" makes the div behave exactly like a real button"
        - text: "Only the visual button styling"
        - text: "A separate ARIA label, since role alone conflicts with onClick"
      explanation: "ARIA's own first rule is not to reach for ARIA when a native element already does the job. A div with role=\"button\" still needs tabIndex, a keydown handler, and focus styling added by hand to match what a real <button> gives for free."
    - id_key: interview-prep-45/test-frontend-3/errorhandling-boundary-gap
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "An unhandled promise rejection occurs from a fetch call with no .catch() anywhere. Which mechanism is responsible for catching it in a production app?"
      options:
        - text: "The nearest React error boundary in the component tree"
        - text: "A window.addEventListener(\"unhandledrejection\", ...) listener, since a rejected promise falls entirely outside what an error boundary can intercept"
          correct: true
        - text: "React's Suspense boundary"
        - text: "Nothing can catch this; it always crashes the app silently"
      explanation: "Error boundaries only catch errors thrown during rendering. An unhandled promise rejection is exactly the async gap they can't cover, which is what the unhandledrejection browser event exists to catch."
    - id_key: interview-prep-45/test-frontend-3/i18n-plural-icu
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A pluralization check written as count === 1 ? \"item\" : \"items\" works fine for English. Why does it fail for languages like Russian or Polish?"
      options:
        - text: "Those languages have more than two grammatical plural forms depending on the exact count, which a binary singular/plural check can't represent; ICU MessageFormat and Intl.PluralRules handle this correctly"
          correct: true
        - text: "Those languages don't support pluralization at all"
        - text: "The check fails only because of character encoding issues"
        - text: "This check actually works fine in every language"
      explanation: "Many languages have plural categories beyond just singular and plural, one, few, many, other. ICU MessageFormat's plural syntax and Intl.PluralRules apply the correct category for each locale automatically, where a hardcoded binary check can't generalize."
    - id_key: interview-prep-45/test-frontend-3/animation-compositor
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "Why does animating transform stay smooth even while a heavy synchronous JavaScript computation is running, but animating top does not?"
      options:
        - text: "transform can be handled entirely on the browser's compositor thread, separate from the main thread the JavaScript is running on; top requires layout and paint on the main thread on every frame"
          correct: true
        - text: "top is a deprecated CSS property with no browser support left"
        - text: "There is no real difference between the two"
        - text: "transform only works inside a requestAnimationFrame callback"
      explanation: "transform and opacity are the two properties that can skip straight to the compositor thread. Any property that affects layout, like top, forces the full style-layout-paint-composite pipeline on the main thread every frame, the same thread the heavy computation is occupying."
    - id_key: interview-prep-45/test-frontend-3/widget-polling-dedup
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A dashboard polls five independent widgets, and three of them request overlapping data. What fixes the duplicate network requests, and what separately fixes the wasted re-render cost?"
      options:
        - text: "A query library's cache, keyed by something like queryKey, dedupes the overlapping in-flight requests; avoiding a full array replacement (diffing or memoizing per-row) fixes the wasted re-renders"
          correct: true
        - text: "Both problems are fixed by the exact same technique: wrapping every widget in React.memo"
        - text: "Increasing the polling interval fixes both problems completely"
        - text: "Nothing can fix duplicate requests across independent components"
      explanation: "These are two separate problems needing two separate fixes. A query library's request deduplication (by cache key) stops the redundant network calls; avoiding a full state replacement, or memoizing what doesn't need to change, is what stops the unnecessary re-renders."
    - id_key: interview-prep-45/test-frontend-3/rerender-search-box
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A large, unrelated list re-renders on every keystroke in a search box elsewhere on the page. What's the most direct fix?"
      options:
        - text: "Move the search box's state into its own component (or memoize the list with React.memo) so a re-render caused by typing doesn't cascade into the unrelated list"
          correct: true
        - text: "Wrap the entire page in Suspense"
        - text: "Switch the search input from controlled to uncontrolled, which fixes this automatically"
        - text: "This can only be fixed by rewriting the list with a class component"
      explanation: "By default, a parent re-rendering cascades to every child. Colocating the search box's state so it doesn't live above the list, or wrapping the list in React.memo so an unrelated state change doesn't affect it, is what actually stops the cascade."
---

Covers HTTP caching, network performance and Web Vitals, code splitting, virtualization, GraphQL, web security, WebSockets, SSR and Next.js, micro-frontends, build tools, accessibility, error handling, internationalization, animation, and the diagnosis-style architecture questions that come up in a real frontend interview.

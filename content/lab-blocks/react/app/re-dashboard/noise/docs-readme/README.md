# Ops Console

The support team's internal console for the shop: orders, customers, order notes, revenue reports and
settings. React 19, Vite, plain JSX.

## Working on it

```bash
npm test                    # vitest (jsdom); tests live in tests/ and next to the code
npx vitest run tests/smoke.test.jsx
tail -f /var/log/mindforge-lab/app.log      # the dev server (Vite)
tail -f /var/log/mindforge-lab/api.log      # the mock API
```

The lab already runs the app for you on port 5173 (hot reload) with a small mock API behind `/api`
(`server/api.mjs`, state resets when it restarts). Dependencies are linked from the sandbox image:
there is no network, so no `npm install`.

## Layout

- `src/lib` the API client (`api.js`) and formatting helpers (`format.js`)
- `src/context/settings.jsx` currency and density settings shared by the pages
- `src/hooks` small reusable hooks
- `src/features/<name>` one folder per page
- `src/ext/<name>` extensions that add actions to the Orders tools (discovered by `src/ext/registry.js`)

## Conventions

- Pages fetch through `src/lib/api.js`, never with a bare `fetch`.
- Anything shared by more than one page lives in `src/components`, `src/hooks` or `src/lib`.
- Amounts are integer cents; format them with `formatMoney`.

## Testing helpers

`import { installFetch, json, deferred, trackListeners, createRenderProbe, renderProfiled } from '@mf/harness'`
gives tests a scriptable `fetch`, deferred promises, a DOM listener counter and render counters. `@/` is `src/`.

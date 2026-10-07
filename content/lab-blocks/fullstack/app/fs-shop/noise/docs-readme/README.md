# Shop Console

A small storefront and its API in one repository: a React 19 + Vite console in `src/` and a FastAPI backend in
`backend/`. Customers sign in, browse the catalog, place orders and edit their profile.

## Working on it

```bash
npx vitest run                    # frontend tests (jsdom); tests live in tests/ and next to the code
python3 -m pytest                 # backend tests (backend/tests)
tail -f /var/log/mindforge-lab/app.log      # the dev server (Vite, :5173)
tail -f /var/log/mindforge-lab/api.log      # the API (uvicorn, :8000)
```

The lab already runs both for you. The browser talks to one origin: Vite (`:5173`) proxies `/api` to the API (`:8000`).
The API keeps its data in memory and re-seeds when it restarts. Dependencies are linked from the sandbox image: there is
no network, so no `npm install` or `pip install`.

Demo account: `alice@shop.test` / `correct-horse-battery`.

## Layout

- `backend/app` the API: `main.py` builds the app, `routes.py` lists the routers, one package or module per feature
- `backend/app/ext` extensions loaded at startup (each module exposes `register(app)`)
- `src/lib` the API client (`api.js`) and formatting helpers (`format.js`)
- `src/features/<name>` one folder per page, `src/pages.js` lists them
- `src/ext/<name>` extensions that add actions to the Orders tools (discovered by `src/ext/registry.js`)

## Conventions

- Pages fetch through `src/lib/api.js`, never with a bare `fetch`.
- Amounts are integer cents; format them with `formatMoney`.
- API errors always look like `{"error": {"code", "message"}}`.

## Configuration

- `SHOP_ALLOWED_ORIGINS` comma-separated browser origins allowed to call the API cross-origin (default
  `http://localhost:5173`)
- `VITE_API_URL` build-time API base URL for the frontend; empty means same origin (`/api`)

## Testing helpers

`import { installFetch, json } from '@mf/harness'` gives tests a scriptable `fetch`. `@mf/fullstack` starts the real
backend for a test file (`useBackend()`) and puts a browser model in front of it (`createBrowser()`): cookies, CORS
and `Origin` behave as in a browser. `@/` is `src/`.

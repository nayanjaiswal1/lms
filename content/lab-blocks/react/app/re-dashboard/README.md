# re-dashboard (app block, React 19 + Vite)

The Ops Console: a support team's internal dashboard that students debug. **Slot defaults are the correct code**; a fault
block replaces slots with the broken version (block.yaml carries a description per slot).

## Layout

- `src/` scaffold (plain JSX, Vite, vitest config, mock API `server/api.mjs`, `.lab/services/{app,api}.sh`, `scripts/bootstrap.sh`).
  Dependencies are linked from the image's `/opt/scaffold/react-app/node_modules` (no network, no `npm install`).
- `history/<feature>/` overlays, one commit each: `orders`, `customers`, `notes`, `reports`, `settings` (each rewrites `src/pages.js`).
- `noise/<name>/` trivial commits (README, CSS, `engines`, `.gitignore`).
- `regression_tests/core/**` and `regression_tests/<feature>/**` (vitest, run by the grader with its own config: jsdom, shared
  setup, `@/` = workspace `src/`, `@mf/harness` = `lab-images/lab-debug/grader/js/harness.js`). Every history feature and
  every carrier has a folder; they must pass on the broken workspace too.
- `carriers/<feature>/src/ext/<feature>/index.js` ready-to-copy carrier features: Tools-menu extensions discovered by
  `src/ext/registry.js` (`order-csv`, `order-total`, `flagged-count`, `status-breakdown`, `top-customer`). Reverting a
  fault commit deletes the extension and fails its regression test.

## Slots (all `region`) and their React faults

| Slot | Fault |
|---|---|
| `hooks.elapsed.tick` | stale closure in `setInterval` |
| `orders.hook.effect` | missing effect dependency |
| `reports.hook.effect` | object dependency recreated every render (request loop) |
| `customers.search.effect` | out-of-order typeahead responses |
| `orders.flag.toggle` | optimistic update without rollback |
| `notes.panel.rows` | array index as key |
| `customers.editor.form` | props copied into state, no reset key |
| `settings.provider.value` | context value recreated every render |
| `hooks.viewport.subscribe` | window listener never removed |
| `lib.api.check-status` | HTTP errors resolve as data |
| `format.date.parse` | calendar day parsed as UTC |
| `lib.api.base-url` | env variable not exposed by Vite (`VITE_` prefix) |

JS slot markers: `// mf:slot name` ... `// mf:endslot`, and `{/* mf:slot name */}` inside JSX. Prettier (in the image) formats
the rendered files.

Probe: `check.vitest-node` (kind J, hidden tests under the fault's `grader/tests/`). Tickets: `ticket.ui-bug-report` or
`ticket.support-escalation`. Reproduce a time-zone fault with `TZ=America/Los_Angeles npx vitest run`.

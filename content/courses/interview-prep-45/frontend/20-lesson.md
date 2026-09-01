---
kind: lesson
id_key: interview-prep-45/day-20-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Build Tools and Bundling"
position: 23
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How does a bundler actually work" is a favorite senior-frontend question because most engineers use Webpack/Vite daily without ever looking inside. Being able to explain module resolution, tree shaking, and HMR from first principles signals real depth. Today builds a tiny bundler and a tiny Babel-style transform from scratch, then covers what production bundlers do differently.

## How bundlers work (Webpack, Vite, esbuild)

At its core, a bundler solves one problem: browsers historically couldn't efficiently load hundreds of separate `import`ed modules over the network (too many round trips, though HTTP/2 and native ESM have eroded this), so bundlers combine a dependency graph of modules into one (or a few) files.

The pipeline, regardless of tool:

1. **Resolve**: starting from an entry file, follow every `import`/`require` to find the actual file on disk (handling extensions, `node_modules`, path aliases).
2. **Parse**: turn each file's source into an AST (Abstract Syntax Tree).
3. **Build a dependency graph**: walk each AST for import/export statements, recursively resolving and parsing until every reachable module is accounted for.
4. **Transform**: run each module through loaders/plugins (TypeScript to JS, JSX to `React.createElement`, CSS Modules to JS objects).
5. **Generate**: concatenate/wrap modules into one or more output bundles, resolving each module's imports to a lookup in a shared module registry at runtime.

Webpack, Vite, and esbuild differ mainly in *when* this happens and what language it's written in:

- **Webpack** does the full resolve/parse/graph/bundle pipeline upfront (dev and prod), highly configurable via loaders/plugins, written in JS. Flexible, but the slowest of the three.
- **esbuild** does the same pipeline but written in Go, parsing and generating orders of magnitude faster than JS-based tools; used as the underlying transform engine inside Vite.
- **Vite** doesn't bundle at all in dev. It serves native ES modules directly to the browser, transforming each file on-demand as the browser requests it (via esbuild), and only bundles for production builds (via Rollup). This is why Vite's dev server starts near-instantly regardless of app size: it never builds a full graph upfront.

**Interview question: "Why is Vite's dev server so much faster than Webpack's for a large app?"**
Webpack must build and bundle the entire dependency graph before serving the first page, so dev-server startup time scales with app size. Vite serves unbundled native ESM in development: the browser itself resolves imports via HTTP requests, and Vite transforms each requested file on-demand (via esbuild) instead of upfront. Startup time is nearly constant regardless of app size because Vite never bundles until the production build.

## Building a simple bundler

A minimal bundler that actually resolves and concatenates CommonJS-style modules, to make the "dependency graph" idea concrete:

```ts
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

interface ModuleNode {
  id: number;
  filename: string;
  code: string;
  dependencyMap: Record<string, number>; // import specifier -> module id
}

// Extremely simplified: finds `require("./x")` calls via regex instead of a real parser.
// A production bundler uses an AST parser (acorn, babel) — this is illustrative only.
function extractDependencies(code: string): string[] {
  const requireRegex = /require\(["'](.+?)["']\)/g;
  const deps: string[] = [];
  let match: RegExpExecArray | null;
  while ((match = requireRegex.exec(code))) {
    deps.push(match[1]);
  }
  return deps;
}

function buildGraph(entryFile: string): ModuleNode[] {
  let nextId = 0;
  const graph: ModuleNode[] = [];
  const visited = new Map<string, number>();

  function visit(filename: string): number {
    if (visited.has(filename)) return visited.get(filename)!;

    const code = readFileSync(filename, "utf-8");
    const id = nextId++;
    visited.set(filename, id);

    const dependencyMap: Record<string, number> = {};
    for (const relativePath of extractDependencies(code)) {
      const absolutePath = resolve(dirname(filename), relativePath + ".js");
      dependencyMap[relativePath] = visit(absolutePath); // recurse: this IS the graph traversal
    }

    graph.push({ id, filename, code, dependencyMap });
    return id;
  }

  visit(entryFile);
  return graph;
}

// Generate: wrap each module in a function, keyed by id, with its own require() that
// looks up dependencies by the id resolved during graph traversal, not by string path.
function bundle(graph: ModuleNode[]): string {
  const modules = graph
    .map(
      (m) => `${m.id}: [
      function(require, module, exports) { ${m.code} },
      ${JSON.stringify(m.dependencyMap)}
    ]`,
    )
    .join(",\n");

  return `
(function(modules) {
  const cache = {};
  function require(id) {
    if (cache[id]) return cache[id].exports;
    const [fn, mapping] = modules[id];
    const module = { exports: {} };
    cache[id] = module;
    fn((relativePath) => require(mapping[relativePath]), module, module.exports);
    return module.exports;
  }
  require(0); // entry point is always module 0
})({ ${modules} });
`;
}
```

This is the same core idea every bundler uses under the hood: replace `require`/`import` with a lookup into an in-memory registry keyed by module id, so the runtime never touches the filesystem. The graph resolution happens once, at build time, and generates static integer references.

## Building a Babel-style transform

Babel-style transforms operate on the AST, not the source string, because regex-based string replacement breaks the moment syntax gets nested or has edge cases (a `require` inside a comment, a template literal, etc). A minimal transform: convert `const`/`let` to `var`.

```ts
interface ASTNode {
  type: string;
  [key: string]: unknown;
}

// A real implementation uses @babel/parser + @babel/traverse + @babel/generator.
// This shows the *shape* of the visitor pattern every AST transform uses.
function transform(ast: ASTNode): ASTNode {
  function visit(node: ASTNode): ASTNode {
    if (node.type === "VariableDeclaration" && (node.kind === "const" || node.kind === "let")) {
      node.kind = "var"; // the actual transformation: mutate the node in place
    }

    // Recurse into every child node — the visitor pattern every AST tool follows.
    for (const key of Object.keys(node)) {
      const value = node[key];
      if (Array.isArray(value)) {
        value.forEach((child) => {
          if (child && typeof child === "object" && "type" in child) visit(child as ASTNode);
        });
      } else if (value && typeof value === "object" && "type" in value) {
        visit(value as ASTNode);
      }
    }
    return node;
  }
  return visit(ast);
}
```

The reason JSX → `React.createElement` and TypeScript → JS both work through this same visitor pattern: parse source into an AST once, run one or more transform passes that mutate specific node types, then regenerate source from the (now-transformed) AST. Babel plugins are, structurally, just `visit` functions scoped to specific node types via a `visitor` object.

## Module resolution

Resolution is the algorithm that turns `import x from "./utils"` or `import y from "lodash"` into an actual file path. Node's (and by extension, most bundlers') resolution algorithm:

1. Relative/absolute paths (`./`, `../`, `/`) resolve directly against the current file's directory, trying the exact path, then `path.js`, `path.ts`, `path/index.js`, in extension-resolution order.
2. Bare specifiers (`"lodash"`) trigger a walk up the directory tree looking for `node_modules/lodash`, checking each parent directory in turn until found or the filesystem root is reached.
3. Package resolution then reads that package's `package.json`: the `exports` field (modern, can restrict/remap what's importable) or `main`/`module` (legacy) to find the actual entry file.

Bundlers add path aliases (`@/components` mapping to `src/components`) as a resolution-time rewrite, configured separately from Node's algorithm (`tsconfig.json` `paths`, Webpack `resolve.alias`, Vite `resolve.alias`). The bundler intercepts the specifier before falling through to standard resolution.

## Tree shaking mechanism

Tree shaking removes exported code that's never imported anywhere in the graph, and it depends specifically on ES module syntax (`import`/`export`) because those are statically analyzable. A bundler can determine, without running any code, exactly what's imported and from where.

```ts
// math.ts
export function add(a: number, b: number) { return a + b; }
export function subtract(a: number, b: number) { return a - b; } // never imported anywhere

// app.ts
import { add } from "./math";
console.log(add(2, 3));
// A production build's output contains `add` but not `subtract` —
// the bundler's static analysis proves `subtract` is unreachable from any entry point.
```

CommonJS (`require`/`module.exports`) largely defeats tree shaking, because `require` calls can be conditional or dynamic (`require(someVariable)`), so the bundler can't statically prove what's used without running the code. This is the actual reason "use ESM, not CommonJS" is standard bundler-tooling advice, not just style preference.

**Interview question: "Why doesn't tree shaking work if you import a whole library with `import * as _ from 'lodash'`?"**
Namespace imports (`import * as`) make every property access on `_` a dynamic property lookup from the bundler's static-analysis point of view. It can't prove which of lodash's hundreds of exports are actually used just by looking at `_.foo()` calls, since `foo` could theoretically be computed. Named imports (`import { debounce } from "lodash-es"`) are what actually enable dead-code elimination, because the bundler sees the exact symbol at the import statement itself.

## Hot module replacement

HMR swaps a changed module's code in the running application without a full page reload, preserving in-memory state (form inputs, component state) that a full refresh would wipe.

The mechanism: the dev server watches the filesystem; on a change, it re-transforms just the changed module, sends the new code to the browser over a WebSocket (this is why dev servers open one), and the client-side HMR runtime replaces the old module's exports with the new ones in the module registry, then re-runs anything that "accepted" the update.

```ts
// Vite/Webpack HMR API — a module opts into accepting its own updates
if (import.meta.hot) {
  import.meta.hot.accept((newModule) => {
    // re-render with the new module's exports instead of reloading the page
  });
}
```

React's Fast Refresh builds on this: it detects that only a component's render function changed (not its state-holding hooks' call order), swaps the function, and re-renders, preserving `useState` values across the edit. If the edit changes hook order or a non-component export changes, Fast Refresh falls back to a full remount (state lost) because it can no longer guarantee correctness.

**Interview question: "Why does editing a component sometimes preserve state via HMR, and sometimes reset it?"**
Fast Refresh preserves state when it can safely re-run just the function body and confirm the hooks called are the same type, count, and order as before, so the fiber's hook list stays valid. If you add/remove/reorder a hook, change what the module exports (e.g. adding a second named export), or edit a file that isn't a React component, Fast Refresh can't guarantee the existing fiber tree is still valid and falls back to a full remount, discarding state.

## Why this matters beyond trivia

None of resolve, parse, transform, tree-shake, or HMR are things you'll implement at your job. They're worth knowing because the mini-bundler and mini-transform above are the same shape of code running inside Webpack, Vite, and Babel today, just with a real parser and years of edge-case handling instead of a regex. When an interviewer asks "why doesn't tree shaking work here" or "why did HMR just do a full reload," they're really asking whether you can reason from that underlying mechanism instead of pattern-matching to a remembered answer.

---
kind: lesson
id_key: interview-prep-45/day-20-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Build Tools and Bundling"
position: 32
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How does a bundler actually work" is a favorite senior question, because most engineers run Webpack or Vite every day without ever looking inside. Explaining module resolution, tree shaking, and hot reload from first principles is a real signal of depth. This lesson builds a tiny bundler and a tiny code-transform by hand, then covers what production tools do differently.

## What a bundler is actually for

A bundler solves one problem: browsers used to be slow at loading hundreds of separately imported files over the network, too many round trips, though HTTP/2 and native ES modules have since eaten into that. So a bundler walks a dependency graph of modules and combines it into one file, or a handful of them.

The pipeline is the same shape no matter the tool. **Resolve**: starting from an entry file, follow every `import`/`require` to an actual file on disk. **Parse**: turn each file's source into a tree structure (an AST). **Build a graph**: walk each file's imports and exports, recursively resolving and parsing until every reachable module is found. **Transform**: run each file through its loaders and plugins, TypeScript to plain JS, JSX to `React.createElement`. **Generate**: combine the modules into one or more output files, wiring up each module's imports as a lookup into a shared runtime registry.

Webpack, Vite, and esbuild differ mainly in *when* this happens and what language does it. **Webpack** runs the full pipeline upfront, in both dev and production, highly configurable, written in JavaScript, flexible but the slowest of the three. **esbuild** runs the same pipeline written in Go, parsing and generating far faster than JS-based tools, and it's what Vite uses under the hood for transforms. **Vite** doesn't bundle at all in development: it serves native ES modules straight to the browser, transforming each file on demand as it's requested, and only bundles for production, through Rollup. That's why Vite's dev server starts almost instantly no matter how big the app is, it never builds a full dependency graph upfront.

> **Remember:** Webpack builds the whole graph before serving anything, even in dev. Vite serves files on demand in dev and only bundles for production.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-bundle-vite-q1", "type": "mcq",
      "prompt": "Why does Vite's dev server start almost instantly regardless of app size, while Webpack's dev server slows down as an app grows?",
      "options": [
        {"id":"a","text":"Vite is written in a faster programming language than Webpack"},
        {"id":"b","text":"Webpack builds and bundles the entire dependency graph before serving the first page; Vite serves native ES modules unbundled and transforms each file on demand as the browser requests it"},
        {"id":"c","text":"Vite skips the transform step entirely"},
        {"id":"d","text":"Webpack doesn't support hot reload"}
      ],
      "correct": "b",
      "explanation": "Webpack's dev startup time scales with total app size because it bundles everything upfront. Vite defers that work to a production build and only transforms whatever file the browser actually asks for right now." }
] }
```

## Building a minimal bundler

Enough code to make "dependency graph" a concrete thing, resolving and combining CommonJS-style modules:

```ts
function extractDependencies(code: string): string[] {
  // Illustrative only — a real bundler uses an AST parser (acorn, babel), not regex
  const requireRegex = /require\(["'](.+?)["']\)/g;
  const deps: string[] = [];
  let match: RegExpExecArray | null;
  while ((match = requireRegex.exec(code))) deps.push(match[1]);
  return deps;
}

function buildGraph(entryFile: string) {
  let nextId = 0;
  const graph: { id: number; filename: string; code: string; dependencyMap: Record<string, number> }[] = [];
  const visited = new Map<string, number>();

  function visit(filename: string): number {
    if (visited.has(filename)) return visited.get(filename)!;
    const code = readFileSync(filename, "utf-8");
    const id = nextId++;
    visited.set(filename, id);
    const dependencyMap: Record<string, number> = {};
    for (const relativePath of extractDependencies(code)) {
      dependencyMap[relativePath] = visit(resolve(dirname(filename), relativePath + ".js")); // recurse — this IS the graph traversal
    }
    graph.push({ id, filename, code, dependencyMap });
    return id;
  }
  visit(entryFile);
  return graph;
}
```

Generating output wraps each module in a function, keyed by its id, with a `require` that looks up dependencies by numeric id instead of by string path:

```ts
function bundle(graph: ReturnType<typeof buildGraph>): string {
  const modules = graph.map((m) => `${m.id}: [function(require, module, exports) { ${m.code} }, ${JSON.stringify(m.dependencyMap)}]`).join(",\n");
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
})({ ${modules} });`;
}
```

This is the same core idea every real bundler uses: replace `require`/`import` with a lookup into an in-memory registry keyed by module id, so the runtime never touches the filesystem again after resolution happens once, at build time.

> **Remember:** a bundler's runtime registry is what lets `require`/`import` become a fast numeric lookup instead of a filesystem read on every call.

## Building a code transform, the way Babel does

Transforms work on the AST, not the raw source string, because a plain string replacement breaks the moment syntax gets nested or shows up somewhere unexpected, a `require` sitting inside a comment or a template literal, for example.

```ts
interface ASTNode { type: string; [key: string]: unknown; }

// A real implementation uses @babel/parser + @babel/traverse + @babel/generator.
// This shows the *shape* of the visitor pattern every AST tool follows.
function transform(ast: ASTNode): ASTNode {
  function visit(node: ASTNode): ASTNode {
    if (node.type === "VariableDeclaration" && (node.kind === "const" || node.kind === "let")) {
      node.kind = "var"; // the actual transformation — mutate the node in place
    }
    for (const key of Object.keys(node)) {
      const value = node[key];
      if (Array.isArray(value)) value.forEach((child) => { if (child?.type) visit(child as ASTNode); });
      else if (value && typeof value === "object" && "type" in value) visit(value as ASTNode);
    }
    return node;
  }
  return visit(ast);
}
```

JSX compiling into `React.createElement`, and TypeScript compiling into plain JS, both work through this exact same visitor pattern: parse the source into an AST once, run one or more passes that mutate specific node types, then regenerate source from the transformed tree. A Babel plugin is, structurally, just a `visit` function scoped to specific node types through a `visitor` object.

> **Remember:** regex-based rewriting breaks the moment syntax nests or hides inside a string or comment. An AST-based transform doesn't, because it only sees real syntax nodes.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-bundle-ast-q1", "type": "mcq",
      "prompt": "Why do real code transforms (Babel, TypeScript's compiler) operate on an AST instead of doing regex-based find-and-replace on the source text?",
      "options": [
        {"id":"a","text":"AST-based transforms run faster in every case"},
        {"id":"b","text":"Regex breaks the moment matching syntax appears somewhere unexpected, like inside a string or comment; an AST only contains real syntax nodes, so a transform can't accidentally match the wrong thing"},
        {"id":"c","text":"Regex can't be used in JavaScript at all"},
        {"id":"d","text":"ASTs are required by the ECMAScript spec"}
      ],
      "correct": "b",
      "explanation": "A regex has no idea whether the text it matched was real code or just happened to look like it inside a string or comment. An AST parser has already separated real syntax from everything else." }
] }
```

## Module resolution

Resolution turns `import x from "./utils"` or `import y from "lodash"` into an actual file path. Node's algorithm, which most bundlers extend rather than replace, works in three steps. A relative or absolute path (`./`, `../`, `/`) resolves directly against the current file's directory, trying the exact path, then `path.js`, then `path/index.js`, in that order. A bare name (`"lodash"`) triggers a walk up the directory tree, checking `node_modules/lodash` in each parent directory until it's found or the filesystem root is reached. Package resolution then reads that package's `package.json`, its `exports` field (modern, can restrict what's importable) or `main`/`module` (older), to find the actual entry file.

Bundlers add path aliases on top of this, `@/components` mapping to `src/components`, as a resolution-time rewrite (`tsconfig.json`'s `paths`, Webpack's `resolve.alias`, Vite's `resolve.alias`), applied before falling through to Node's own algorithm.

## Tree shaking, from the bundler's own point of view

Tree shaking removes exported code that's never imported anywhere in the graph, and it depends specifically on ES module syntax, since `import`/`export` are statically readable without running any code.

```ts
// math.ts
export function add(a: number, b: number) { return a + b; }
export function subtract(a: number, b: number) { return a - b; } // never imported anywhere

// app.ts
import { add } from "./math";
// A production build contains `add` but not `subtract` —
// static analysis proves `subtract` is unreachable from any entry point.
```

CommonJS largely defeats this, since `require` calls can be conditional or dynamic, so a bundler can't statically prove what's actually used without running the code. That's the real, mechanical reason "use ES modules, not CommonJS" is standard advice, not just a style preference.

## Hot module replacement

HMR swaps a changed module's code inside the running app without a full page reload, keeping in-memory state, form inputs, component state, that a full refresh would otherwise wipe out. The dev server watches the filesystem, re-transforms just the changed file on a save, sends the new code to the browser over a WebSocket, which is why a dev server opens one at all, and the browser's own HMR runtime swaps the old module's exports for the new ones in its registry, then re-runs anything that "accepted" the update.

```ts
// Vite/Webpack HMR API — a module opts into accepting its own updates
if (import.meta.hot) {
  import.meta.hot.accept((newModule) => { /* re-render with the new exports instead of reloading */ });
}
```

React's Fast Refresh builds on this: it detects that only a component's render function changed, not its state-holding hooks' call order, swaps the function, and re-renders, keeping `useState` values intact across the edit. If the edit changes hook order or a non-component export, Fast Refresh falls back to a full remount, state lost, because it can no longer guarantee that's safe.

> **Remember:** Fast Refresh only preserves state when it can prove the same hooks still run in the same order. Change that order and it has to fall back to a full remount.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-bundle-hmr-q1", "type": "mcq",
      "prompt": "A developer edits a component and adds a new useState call before an existing one. React Fast Refresh resets the component's state instead of preserving it. Why?",
      "options": [
        {"id":"a","text":"Fast Refresh never preserves state under any circumstances"},
        {"id":"b","text":"Reordering hooks changes which call maps to which slot in the fiber's hook list, so Fast Refresh can no longer guarantee the existing state is still valid, and falls back to a full remount"},
        {"id":"c","text":"useState calls can never be added during development"},
        {"id":"d","text":"This is unrelated to Fast Refresh and is a bug"}
      ],
      "correct": "b",
      "explanation": "Fast Refresh preserves state only when it can confirm the same hooks run in the same type, count, and order as before. Adding a hook changes that order, so it can no longer safely reuse the old fiber's hook state." }
] }
```

## Why this is worth knowing beyond trivia

None of resolve, parse, transform, tree-shake, or HMR are things you'll hand-implement at your actual job. They're worth knowing because the mini-bundler and mini-transform above are the same shape of code running inside Webpack, Vite, and Babel today, just with a real parser and years of edge cases layered on top instead of a regex. When an interviewer asks why tree shaking isn't working, or why HMR just did a full reload, they're checking whether you can reason from the actual mechanism, not whether you've memorized a remembered answer.

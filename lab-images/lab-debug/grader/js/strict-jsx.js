// Vite plugin for the grader's vitest config: esbuild only WARNS on JSX it
// cannot parse cleanly (e.g. a stray ">" after a self-closing tag, which then
// renders as literal text), so a visibly broken component would still pass the
// behaviour tests. Treat every esbuild JSX warning in app/test sources as a
// build error, the way a reviewer would.
import { transform } from "esbuild";

const JSX_FILE = /\.(jsx|tsx)$/;

export default function strictJsx() {
  return {
    name: "mf-strict-jsx",
    enforce: "pre",
    async transform(code, id) {
      const file = id.split("?")[0];
      if (!JSX_FILE.test(file) || file.includes("/node_modules/")) return null;
      const { warnings } = await transform(code, {
        loader: file.endsWith(".tsx") ? "tsx" : "jsx",
        jsx: "automatic",
        sourcefile: file,
      });
      if (warnings.length > 0) {
        const w = warnings[0];
        throw new Error(`${file}:${w.location?.line ?? "?"}:${w.location?.column ?? "?"}: ${w.text}`);
      }
      return null;
    },
  };
}

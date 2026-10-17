import { defineConfig } from "vite-plus";
import { fileURLToPath } from "node:url";

export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL(".", import.meta.url)) } },
  test: {
    include: ["lib/**/*.test.ts"],
    // slim-tree.test.ts uses node:test and runs under `node --test`.
    exclude: ["lib/courses/slim-tree.test.ts", "node_modules/**"],
  },
});

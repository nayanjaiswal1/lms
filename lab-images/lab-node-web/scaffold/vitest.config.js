import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Separate from vite.config.js on purpose: interactive labs only ever run
// `npm run dev` against vite.config.js, so this file is additive and cannot
// change their behavior. Used only by hiring-assessment sandbox grading (see
// backend/internal/assessment/executor_sandbox.go), whose VerifyCommand runs
// `npx vitest run --config vitest.config.js --reporter=junit --outputFile=...`
// against the candidate's submitted component plus the question's hidden
// *.test.jsx file.
export default defineConfig({
  plugins: [react()],
  cacheDir: "/tmp/vite-cache",
  test: {
    environment: "jsdom",
    // Relative, not the /opt/scaffold absolute path: grading runs from a copy
    // of this whole directory (see executor_sandbox.go VerifyCommand
    // convention), and Vite's default fs.allow denies loading files outside
    // that copy's own root, so an absolute /opt/scaffold path 404s even
    // though the file exists on disk.
    setupFiles: ["./vitest.setup.js"],
    globals: true,
  },
});

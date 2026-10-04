// Shared vitest setup for React debug labs (root-owned, part of the lab-debug
// image). Loaded by the grader's own vitest config and by the workspace's
// vitest.config.js, so students and the grader see the same environment.
import "@testing-library/jest-dom/vitest";
import { afterEach, vi } from "vitest";
import { cleanup } from "@testing-library/react";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

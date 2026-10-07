import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Same environment the grader uses: jsdom, the shared setup (jest-dom matchers,
// cleanup between tests) and the "@/" (src) and "@mf/harness" aliases.
export default defineConfig({
  plugins: [react()],
  cacheDir: '/tmp/vite-cache-vitest',
  resolve: {
    alias: [
      { find: /^@\//, replacement: fileURLToPath(new URL('./src/', import.meta.url)) },
      { find: '@mf/harness', replacement: '/opt/mindforge/grader/js/harness.js' },
    ],
    dedupe: ['react', 'react-dom'],
  },
  test: {
    environment: 'jsdom',
    globals: true,
    css: false,
    setupFiles: ['/opt/mindforge/grader/js/setup.js'],
    include: ['tests/**/*.test.{js,jsx}', 'src/**/*.test.{js,jsx}'],
  },
});

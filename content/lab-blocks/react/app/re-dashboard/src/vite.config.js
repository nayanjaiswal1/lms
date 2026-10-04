import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // node_modules is a read-only symlink into the sandbox image, so Vite's
  // dependency cache lives somewhere writable.
  cacheDir: '/tmp/vite-cache',
  server: {
    host: true,
    port: 5173,
    allowedHosts: true,
    // The mock API (server/api.mjs, started by .lab/services/api.sh).
    proxy: { '/api': 'http://127.0.0.1:8001' },
  },
});

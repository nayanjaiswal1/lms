import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // node_modules is a read-only symlink into /opt/scaffold, so Vite's dep
  // cache (normally node_modules/.vite) must live somewhere writable.
  cacheDir: "/tmp/vite-cache",
  server: {
    host: true,
    port: 5173,
  },
});

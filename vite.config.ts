import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  // Serve index.html for client-side routes like /post/:id (deep links, T5.2).
  appType: 'spa',
  server: {
    host: '0.0.0.0',
    port: 3000,
  },
});

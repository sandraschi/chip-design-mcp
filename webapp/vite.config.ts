import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const backendProxy = {
  '/api': 'http://127.0.0.1:11022',
  '/sse': 'http://127.0.0.1:11022',
  '/mcp': 'http://127.0.0.1:11022',
  '/docs': 'http://127.0.0.1:11022',
  '/openapi.json': 'http://127.0.0.1:11022',
  '/redoc': 'http://127.0.0.1:11022',
};

export default defineConfig({
  plugins: [react()],
  server: {
    allowedHosts: ['goliath'],
    port: 11023,
    proxy: backendProxy,
  },
  preview: {
    port: 11023,
    proxy: backendProxy,
  },
});

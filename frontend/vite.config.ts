import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig(({ mode }) => {
  // The start scripts write VOICEFORGE_PORT to frontend/.env (or export it), so the
  // proxy always follows the port the FastAPI backend actually started on.
  const env = loadEnv(mode, process.cwd(), '')
  const backendPort = process.env.VOICEFORGE_PORT || env.VOICEFORGE_PORT || '8001'
  const proxy = {
    '/api': { target: `http://127.0.0.1:${backendPort}`, changeOrigin: true },
    '/ws': { target: `ws://127.0.0.1:${backendPort}`, ws: true },
  }

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    server: {
      host: '127.0.0.1',
      port: 5173,
      proxy,
    },
    preview: {
      host: '127.0.0.1',
      port: 4173,
      proxy,
    },
    build: {
      chunkSizeWarningLimit: 1200,
    },
  }
})

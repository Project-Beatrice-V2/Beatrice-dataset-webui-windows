// By default the UI talks to the backend through the Vite dev/preview proxy
// (same origin: /api and /ws are forwarded to the FastAPI server, see vite.config.ts),
// so no CORS or port juggling is needed. Set VITE_API_URL / VITE_WS_URL only when the
// backend is served from somewhere else.
const API_URL = import.meta.env.VITE_API_URL || ''
const WS_URL =
  import.meta.env.VITE_WS_URL ||
  `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}`

export { API_URL, WS_URL }

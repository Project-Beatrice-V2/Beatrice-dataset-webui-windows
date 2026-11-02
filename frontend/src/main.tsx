import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import App from './App'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, refetchOnWindowFocus: false },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
        <Toaster
          position="bottom-right"
          toastOptions={{
            style: {
              background: 'var(--bg-raised)',
              color: 'var(--text-hi)',
              border: '1px solid var(--border-subtle)',
              borderRadius: '999px',
              fontFamily: 'var(--font-sans)',
              fontSize: '14px',
              boxShadow: 'none',
            },
            success: { iconTheme: { primary: 'var(--green)', secondary: 'var(--bg-raised)' } },
            error: { iconTheme: { primary: 'var(--red)', secondary: 'var(--bg-raised)' } },
          }}
        />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
)

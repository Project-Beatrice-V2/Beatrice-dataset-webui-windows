import { useCallback, useEffect, useState } from 'react'

export type ColorMode = 'dark' | 'light'

const STORAGE_KEY = 'beatrice-dataset-color-mode'

function readStored(): ColorMode | null {
  try {
    const v = window.localStorage.getItem(STORAGE_KEY)
    return v === 'dark' || v === 'light' ? v : null
  } catch {
    return null
  }
}

function systemMode(): ColorMode {
  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

export function currentColorMode(): ColorMode {
  return document.documentElement.dataset.colorMode === 'light' ? 'light' : 'dark'
}

function apply(mode: ColorMode) {
  document.documentElement.dataset.colorMode = mode
}

/** Light/dark mode: remembers an explicit choice, otherwise follows the system. */
export function useColorMode() {
  const [mode, setMode] = useState<ColorMode>(() => readStored() ?? currentColorMode())

  useEffect(() => {
    apply(mode)
  }, [mode])

  useEffect(() => {
    if (readStored()) return
    const mq = window.matchMedia?.('(prefers-color-scheme: light)')
    if (!mq) return
    const onChange = () => {
      if (!readStored()) setMode(systemMode())
    }
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  const toggle = useCallback(() => {
    setMode((m) => {
      const next: ColorMode = m === 'dark' ? 'light' : 'dark'
      try {
        window.localStorage.setItem(STORAGE_KEY, next)
      } catch {
        /* storage unavailable: still switch for this session */
      }
      return next
    })
  }, [])

  return { mode, toggle }
}

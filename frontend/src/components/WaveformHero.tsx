import { useEffect, useRef } from 'react'
import type { UIState } from '@/store/appStore'

interface WaveformHeroProps {
  uiState: UIState
  progress: number
}

const STATE_LABEL: Record<UIState, string> = {
  idle: 'Waiting for a voice',
  previewing: 'Sources found',
  queued: 'Queued',
  searching: 'Searching',
  downloading: 'Downloading',
  processing: 'Processing',
  packaging: 'Packaging',
  done: 'Dataset ready',
  failed: 'Failed',
}

function readPalette() {
  const css = getComputedStyle(document.documentElement)
  const v = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback
  return {
    w1: v('--wave-1', '#7c8cff'),
    w2: v('--wave-2', '#a887dc'),
    w3: v('--wave-3', '#fcdbef'),
    red: v('--red', '#ff5a6e'),
  }
}

/** Animated aurora waveform; its motion follows the pipeline state. */
export function WaveformHero({ uiState, progress }: WaveformHeroProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animRef = useRef<number>(0)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')!
    const dpr = window.devicePixelRatio || 1
    const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    let palette = readPalette()

    const resize = () => {
      const w = canvas.parentElement?.offsetWidth || canvas.offsetWidth
      const h = canvas.parentElement?.offsetHeight || canvas.offsetHeight
      canvas.width = w * dpr
      canvas.height = h * dpr
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    resize()
    window.addEventListener('resize', resize)

    // Follow light/dark mode changes.
    const observer = new MutationObserver(() => {
      palette = readPalette()
    })
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-color-mode', 'data-theme'] })

    const config = (() => {
      switch (uiState) {
        case 'searching':
        case 'downloading':
          return { speed: 0.07, amplitude: 26, frequency: 3.2 }
        case 'processing':
        case 'packaging':
        case 'queued':
          return { speed: 0.04, amplitude: 32, frequency: 2.2 }
        case 'done':
          return { speed: 0.015, amplitude: 18, frequency: 1.2 }
        case 'failed':
          return { speed: 0.1, amplitude: 6, frequency: 8.0 }
        default:
          return { speed: 0.022, amplitude: 16, frequency: 1.6 }
      }
    })()

    let frame = 0

    const draw = () => {
      const w = canvas.width / dpr
      const h = canvas.height / dpr
      ctx.clearRect(0, 0, w, h)
      const centerY = h / 2

      const wave = (
        speedMult: number,
        ampMult: number,
        freqMult: number,
        phase: number,
        colors: [string, string],
        lineWidth: number,
        alpha: number,
        glow: number,
      ) => {
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.beginPath()
        if (glow > 0) {
          ctx.shadowBlur = glow
          ctx.shadowColor = colors[0]
        }
        const gradient = ctx.createLinearGradient(0, 0, w, 0)
        gradient.addColorStop(0, colors[0])
        gradient.addColorStop(0.5, colors[1])
        gradient.addColorStop(1, colors[0])
        ctx.strokeStyle = gradient
        ctx.lineWidth = lineWidth
        ctx.lineCap = 'round'
        for (let x = 0; x <= w; x += 2) {
          // Tapering envelope so the wave fades out at both edges
          const envelope = Math.pow(Math.sin((x / w) * Math.PI), 2)
          const angle = (x / w) * Math.PI * 2 * config.frequency * freqMult + frame * config.speed * speedMult + phase
          const y = centerY + Math.sin(angle) * config.amplitude * ampMult * envelope
          if (x === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
        ctx.restore()
      }

      if (uiState === 'failed') {
        wave(1, 1, 1, 0, [palette.red, palette.red], 1.75, 0.9, 0)
      } else {
        wave(0.6, 0.7, 0.8, Math.PI / 3, [palette.w3, palette.w2], 1.25, 0.45, 0)
        wave(1.2, 0.85, 1.3, -Math.PI / 4, [palette.w2, palette.w1], 1.5, 0.6, 0)
        wave(1, 1.1, 1, 0, [palette.w1, palette.w2], 2, 1, 6)
      }

      frame++
      if (!reduceMotion) animRef.current = requestAnimationFrame(draw)
    }

    draw()
    return () => {
      cancelAnimationFrame(animRef.current)
      window.removeEventListener('resize', resize)
      observer.disconnect()
    }
  }, [uiState])

  const busy = uiState !== 'idle' && uiState !== 'previewing' && uiState !== 'done' && uiState !== 'failed'
  const dot =
    uiState === 'failed' ? 'dot-bad' : uiState === 'done' ? 'dot-ok' : busy ? 'dot-accent animate-breathe' : uiState === 'previewing' ? 'dot-accent' : ''

  return (
    <div className="relative h-28 w-full overflow-hidden rounded-[12px]">
      <canvas ref={canvasRef} className="block h-full w-full" />
      <span className="eyebrow pointer-events-none absolute left-4 top-3 flex items-center gap-2">
        <span className={`dot ${dot}`} />
        {STATE_LABEL[uiState]}
      </span>
      {busy && (
        <span className="badge badge-accent absolute bottom-3 right-4 animate-fadeIn">{progress}%</span>
      )}
    </div>
  )
}

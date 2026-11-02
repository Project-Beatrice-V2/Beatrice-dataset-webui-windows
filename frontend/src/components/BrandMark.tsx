import { MARK_SVG, MARK_SMALL_SVG } from './logoPaths'

interface BrandMarkProps {
  className?: string
  /** Fine-line cut for large sizes (48 px and up); heavy-line cut otherwise. */
  detail?: boolean
}

/** The Beatrice "Sprig" logo. Inherits `currentColor` (white in dark mode, black in light). */
export function BrandMark({ className = 'h-7 w-7', detail = false }: BrandMarkProps) {
  return (
    <svg
      viewBox="0 0 64 64"
      className={className}
      aria-hidden
      strokeLinecap="round"
      strokeLinejoin="round"
      dangerouslySetInnerHTML={{ __html: detail ? MARK_SVG : MARK_SMALL_SVG }}
    />
  )
}

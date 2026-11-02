import type { ReactNode } from 'react'
import { ChevronDown } from 'lucide-react'

/** Accessible on/off switch styled as an Aurora Void pill. */
export function Switch({
  checked,
  onChange,
  label,
  description,
}: {
  checked: boolean
  onChange: (value: boolean) => void
  label: string
  description?: string
}) {
  return (
    <label className="flex cursor-pointer items-center justify-between gap-4">
      <span>
        <span className="block text-[14px] text-hi">{label}</span>
        {description && <span className="block text-[12px] text-lo">{description}</span>}
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        className="switch"
        onClick={() => onChange(!checked)}
      />
    </label>
  )
}

/** Segmented pill group for a small set of mutually exclusive options. */
export function OptionGroup<T extends string | number>({
  label,
  value,
  options,
  onChange,
  format = (v) => String(v),
}: {
  label: string
  value: T
  options: readonly T[]
  onChange: (value: T) => void
  format?: (value: T) => ReactNode
}) {
  return (
    <div className="space-y-2.5">
      <span className="eyebrow block">{label}</span>
      <div className="segmented flex-wrap" role="radiogroup" aria-label={label}>
        {options.map((opt) => (
          <button
            key={String(opt)}
            type="button"
            role="radio"
            aria-checked={value === opt}
            data-active={value === opt}
            onClick={() => onChange(opt)}
            className="segmented-item"
          >
            {format(opt)}
          </button>
        ))}
      </div>
    </div>
  )
}

/** Range slider with a mono value readout. */
export function SliderField({
  label,
  value,
  display,
  min,
  max,
  step,
  onChange,
  hint,
}: {
  label: string
  value: number
  display?: ReactNode
  min: number
  max: number
  step: number
  onChange: (value: number) => void
  hint?: string
}) {
  return (
    <div className="space-y-2.5">
      <div className="flex items-center justify-between gap-3">
        <span className="eyebrow">{label}</span>
        <span className="slider-val">{display ?? value}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(+e.target.value)}
        className="slider"
        aria-label={label}
      />
      {hint && <p className="text-[12px] text-lo">{hint}</p>}
    </div>
  )
}

/** Native select with the Aurora Void field style. */
export function SelectField<T extends string | number>({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: T
  options: { value: T; label: string }[]
  onChange: (value: T) => void
}) {
  return (
    <label className="block space-y-2.5">
      <span className="eyebrow block">{label}</span>
      <span className="relative block">
        <select
          value={value}
          onChange={(e) => {
            const raw = e.target.value
            const match = options.find((o) => String(o.value) === raw)
            if (match) onChange(match.value)
          }}
          className="input-field"
        >
          {options.map((o) => (
            <option key={String(o.value)} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-lo" />
      </span>
    </label>
  )
}

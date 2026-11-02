import { useState } from 'react'
import { ChevronDown, SlidersHorizontal } from 'lucide-react'
import { useAppStore } from '@/store/appStore'
import { OptionGroup, SliderField, Switch } from './ui'

const FORMAT_LABELS: Record<string, string> = {
  ljspeech: 'LJSpeech',
  vctk: 'VCTK',
  rvc: 'RVC',
  raw: 'Raw',
  custom: 'Custom',
}

export function AdvancedOptions() {
  const [open, setOpen] = useState(false)
  const { options, setOptions } = useAppStore()

  const similarity = options.speaker_similarity_threshold
  const similarityLabel = similarity >= 0.85 ? 'strict' : similarity >= 0.75 ? 'balanced' : 'lenient'

  return (
    <div className="card">
      <button
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-4 text-left"
      >
        <span className="flex items-center gap-3">
          <SlidersHorizontal className="h-4 w-4 text-accent" strokeWidth={1.75} />
          <span>
            <span className="block text-[15px] font-medium">Advanced options</span>
            <span className="block text-[12px] text-lo">
              {options.target_sample_rate} Hz · {options.bit_depth}-bit · {options.channels} · {FORMAT_LABELS[options.output_format]}
            </span>
          </span>
        </span>
        <ChevronDown className={`h-4 w-4 text-mid transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>

      {open && (
        <div className="hairline-t mt-6 grid gap-x-10 gap-y-7 pt-6 animate-fadeIn md:grid-cols-2">
          <SliderField
            label="Target duration"
            value={options.target_duration_minutes}
            display={`${options.target_duration_minutes} min`}
            min={10}
            max={120}
            step={5}
            onChange={(v) => setOptions({ target_duration_minutes: v })}
          />
          <SliderField
            label="Quality threshold"
            value={options.quality_threshold}
            display={`${options.quality_threshold} / 100`}
            min={0}
            max={100}
            step={5}
            onChange={(v) => setOptions({ quality_threshold: v })}
          />

          <OptionGroup
            label="Sample rate"
            value={options.target_sample_rate}
            options={[16000, 22050, 44100] as const}
            format={(v) => `${v / 1000} kHz`}
            onChange={(v) => setOptions({ target_sample_rate: v })}
          />
          <OptionGroup
            label="Bit depth"
            value={options.bit_depth}
            options={[16, 24, 32] as const}
            format={(v) => `${v}-bit`}
            onChange={(v) => setOptions({ bit_depth: v })}
          />

          <OptionGroup
            label="Channels"
            value={options.channels}
            options={['mono', 'stereo'] as const}
            format={(v) => (v === 'mono' ? 'Mono' : 'Stereo')}
            onChange={(v) => setOptions({ channels: v })}
          />
          <OptionGroup
            label="Noise removal"
            value={options.denoise_strength}
            options={['off', 'light', 'medium', 'aggressive'] as const}
            format={(v) => v.charAt(0).toUpperCase() + v.slice(1)}
            onChange={(v) => setOptions({ denoise_strength: v })}
          />

          <div className="grid grid-cols-2 gap-4">
            <label className="block space-y-2.5">
              <span className="eyebrow block">Min clip (s)</span>
              <input
                type="number" step={0.5} min={0.5} max={10}
                value={options.min_clip_duration_sec}
                onChange={(e) => setOptions({ min_clip_duration_sec: +e.target.value })}
                className="input-field font-mono"
              />
            </label>
            <label className="block space-y-2.5">
              <span className="eyebrow block">Max clip (s)</span>
              <input
                type="number" step={1} min={5} max={60}
                value={options.max_clip_duration_sec}
                onChange={(e) => setOptions({ max_clip_duration_sec: +e.target.value })}
                className="input-field font-mono"
              />
            </label>
          </div>
          <SliderField
            label="Speaker similarity"
            value={similarity}
            display={`${similarity.toFixed(2)} · ${similarityLabel}`}
            min={0.5}
            max={0.95}
            step={0.05}
            onChange={(v) => setOptions({ speaker_similarity_threshold: v })}
            hint="Higher keeps fewer clips, but they match the target voice more closely."
          />

          <OptionGroup
            label="Output format"
            value={options.output_format}
            options={['ljspeech', 'vctk', 'rvc', 'raw', 'custom'] as const}
            format={(v) => FORMAT_LABELS[v]}
            onChange={(v) => setOptions({ output_format: v })}
          />
          <OptionGroup
            label="Search strategy"
            value={options.search_strategy}
            options={['auto', 'hub_only', 'scrape_only', 'hybrid'] as const}
            format={(v) => ({ auto: 'Auto', hub_only: 'Hub only', scrape_only: 'Scrape only', hybrid: 'Hybrid' })[v]}
            onChange={(v) => setOptions({ search_strategy: v })}
          />

          <div className="space-y-4 md:col-span-2">
            <span className="eyebrow block">Pipeline stages</span>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="tile">
                <Switch
                  label="Vocal separation"
                  description="Demucs removes music and effects"
                  checked={options.use_demucs}
                  onChange={(v) => setOptions({ use_demucs: v })}
                />
              </div>
              <div className="tile">
                <Switch
                  label="Voice activity detection"
                  description="Silero VAD trims silence"
                  checked={options.use_vad}
                  onChange={(v) => setOptions({ use_vad: v })}
                />
              </div>
              <div className="tile">
                <Switch
                  label="Transcription"
                  description="Whisper writes the transcripts"
                  checked={options.transcribe}
                  onChange={(v) => setOptions({ transcribe: v })}
                />
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

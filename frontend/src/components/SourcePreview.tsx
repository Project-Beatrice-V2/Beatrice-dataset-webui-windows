import { Database, Youtube, Globe, HardDrive, Clock, Layers } from 'lucide-react'
import type { SearchPreview } from '@/lib/api'

const SOURCE_ICONS: Record<string, typeof Database> = {
  huggingface: Database,
  youtube: Youtube,
  bilibili: Globe,
  nicovideo: Globe,
  openslr: HardDrive,
}

const SOURCE_NAMES: Record<string, string> = {
  huggingface: 'Hugging Face',
  youtube: 'YouTube',
  bilibili: 'Bilibili',
  nicovideo: 'Niconico',
  openslr: 'OpenSLR',
  archive_org: 'Internet Archive',
}

const STRATEGY_NAMES: Record<string, string> = {
  hybrid: 'Hybrid',
  dataset_hub: 'Dataset hub',
  video_scrape: 'Video scrape',
}

interface SourcePreviewProps {
  preview: SearchPreview
}

export function SourcePreview({ preview }: SourcePreviewProps) {
  const info = (preview.character_info || {}) as Record<string, string>
  const facts = [
    { label: 'Voice', value: info.name },
    { label: 'Series', value: info.series },
    { label: 'JP voice', value: info.voice_actor_jp },
    { label: 'EN voice', value: info.voice_actor_en },
  ].filter((f) => f.value)

  return (
    <div className="card space-y-6 animate-slideIn">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <span className="eyebrow">Sources found</span>
          <h2 className="mt-2 text-[22px] font-semibold tracking-[-0.03em]">{info.name || 'Unknown voice'}</h2>
        </div>
        <span className="badge badge-accent">{STRATEGY_NAMES[preview.recommended_strategy] || preview.recommended_strategy}</span>
      </div>

      {facts.length > 1 && (
        <dl className="flex flex-wrap gap-x-8 gap-y-2 text-[13px]">
          {facts.slice(1).map((f) => (
            <div key={f.label} className="flex gap-2">
              <dt className="text-lo">{f.label}</dt>
              <dd className="text-hi">{f.value}</dd>
            </div>
          ))}
        </dl>
      )}

      {preview.sources_found.length === 0 ? (
        <p className="tile text-[14px] text-mid">
          No ready-made datasets or videos matched yet. The job will still search video sites when it runs.
        </p>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {preview.sources_found.map((source, i) => {
            const Icon = SOURCE_ICONS[source.type] || Database
            return (
              <div key={i} className="tile space-y-2">
                <div className="flex items-center gap-2 text-[13px] text-mid">
                  <Icon className="h-4 w-4 text-accent" strokeWidth={1.75} />
                  <span>{SOURCE_NAMES[source.type] || source.type.replace('_', ' ')}</span>
                </div>
                {source.clips != null && source.clips > 0 && (
                  <p className="text-[26px] font-semibold tracking-[-0.03em]">
                    {source.clips.toLocaleString()} <span className="text-[14px] font-normal text-mid">clips</span>
                  </p>
                )}
                {source.videos != null && source.videos > 0 && (
                  <p className="text-[26px] font-semibold tracking-[-0.03em]">
                    {source.videos} <span className="text-[14px] font-normal text-mid">videos</span>
                  </p>
                )}
                <div className="flex flex-wrap gap-x-4 gap-y-1 text-[12px] text-lo">
                  {source.size_gb != null && source.size_gb > 0 && <span className="font-mono">{source.size_gb} GB</span>}
                  {source.estimated_duration_minutes != null && source.estimated_duration_minutes > 0 && (
                    <span className="flex items-center gap-1 font-mono">
                      <Clock className="h-3 w-3" /> ~{source.estimated_duration_minutes} min
                    </span>
                  )}
                </div>
                {source.dataset && <p className="truncate font-mono text-[12px] text-lo">{source.dataset}</p>}
              </div>
            )
          })}
        </div>
      )}

      <div className="hairline-t flex flex-wrap items-center gap-x-8 gap-y-3 pt-5 text-[13px]">
        <div className="flex items-center gap-2">
          <Layers className="h-4 w-4 text-lo" strokeWidth={1.75} />
          <span className="text-mid">Estimated output</span>
          <span className="font-mono text-hi">~{preview.estimated_output_clips.toLocaleString()} clips</span>
        </div>
        <div className="flex items-center gap-2">
          <Clock className="h-4 w-4 text-lo" strokeWidth={1.75} />
          <span className="text-mid">Speech</span>
          <span className="font-mono text-hi">~{preview.estimated_duration_minutes} min</span>
        </div>
      </div>
    </div>
  )
}

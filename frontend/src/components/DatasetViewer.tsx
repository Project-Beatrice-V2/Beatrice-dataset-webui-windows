import { Download, Check } from 'lucide-react'
import type { Job } from '@/lib/api'
import { getDownloadUrl, getJobClips } from '@/lib/api'
import { QualityChart } from './QualityChart'
import { useQuery } from '@tanstack/react-query'

interface DatasetViewerProps {
  job: Job
}

const STRATEGY_LABELS: Record<string, string> = {
  hybrid: 'Hybrid',
  dataset_hub: 'Dataset hub',
  video_scrape: 'Video scrape',
  auto: 'Auto',
}

const FORMAT_LABELS: Record<string, string> = {
  ljspeech: 'LJSpeech',
  vctk: 'VCTK',
  rvc: 'RVC',
  raw: 'Raw',
  custom: 'Custom',
  wav: 'WAV',
}

export function DatasetViewer({ job }: DatasetViewerProps) {
  const isConversion = job.query_type === 'conversion'
  const durationMin = (job.total_seconds / 60).toFixed(1)
  const format = String(job.options?.output_format || (isConversion ? 'wav' : 'ljspeech'))

  const { data: clipsData } = useQuery({
    queryKey: ['job-clips', job.id],
    queryFn: () => getJobClips(job.id, 1, 200),
    enabled: !!job.id && !isConversion,
  })

  const stats = isConversion
    ? [
        { label: 'Files', value: job.total_clips.toLocaleString() },
        { label: 'Format', value: FORMAT_LABELS[format] || format },
      ]
    : [
        { label: 'Clips', value: job.total_clips.toLocaleString() },
        { label: 'Speech', value: `${durationMin} min` },
        { label: 'Strategy', value: STRATEGY_LABELS[job.strategy || ''] || job.strategy || 'Auto' },
        { label: 'Format', value: FORMAT_LABELS[format] || format },
      ]

  return (
    <div className="card space-y-7 animate-slideIn">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-start gap-3">
          <span className="mt-1 flex h-7 w-7 items-center justify-center rounded-full border border-ok/40 bg-ok/10 text-ok">
            <Check className="h-3.5 w-3.5" strokeWidth={2.5} />
          </span>
          <div>
            <span className="eyebrow">{isConversion ? 'Conversion complete' : 'Dataset ready'}</span>
            <h2 className="mt-1 text-[22px] font-semibold tracking-[-0.03em]">{job.query}</h2>
            <p className="mt-1 text-[13px] text-mid">
              {isConversion
                ? `${job.total_clips.toLocaleString()} files converted`
                : `${job.total_clips.toLocaleString()} clips · ${durationMin} minutes of speech, ready to train`}
            </p>
          </div>
        </div>
        <a href={getDownloadUrl(job.id)} className="btn-primary">
          <Download className="h-4 w-4" strokeWidth={2} />
          Download ZIP
        </a>
      </div>

      <div className={`grid gap-3 ${isConversion ? 'grid-cols-2' : 'grid-cols-2 sm:grid-cols-4'}`}>
        {stats.map((stat) => (
          <div key={stat.label} className="tile">
            <span className="eyebrow block">{stat.label}</span>
            <span className="mt-2 block truncate text-[24px] font-semibold tracking-[-0.03em]">{stat.value}</span>
          </div>
        ))}
      </div>

      {!isConversion && <QualityChart clips={clipsData?.clips || []} />}
    </div>
  )
}

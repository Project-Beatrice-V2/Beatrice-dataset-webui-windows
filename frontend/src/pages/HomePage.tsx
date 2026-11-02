import { useState, useEffect } from 'react'
import toast from 'react-hot-toast'
import { ArrowLeft, CircleAlert } from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import { useAppStore, type UIState } from '@/store/appStore'
import { searchPreview, createJob, getJob } from '@/lib/api'
import { useJobWebSocket } from '@/hooks/useJobWebSocket'
import { SearchBar } from '@/components/SearchBar'
import { SourcePreview } from '@/components/SourcePreview'
import { AdvancedOptions } from '@/components/AdvancedOptions'
import { JobProgress } from '@/components/JobProgress'
import { LiveClipFeed } from '@/components/LiveClipFeed'
import { DatasetViewer } from '@/components/DatasetViewer'

const ACTIVE_STATES: UIState[] = ['queued', 'searching', 'downloading', 'processing', 'packaging']

function errorDetail(e: unknown, fallback: string) {
  const detail = (e as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail
  return typeof detail === 'string' ? detail : fallback
}

export function HomePage() {
  const [loading, setLoading] = useState(false)
  const {
    query, queryType, language, options, uiState,
    preview, setPreview, setUiState, setCurrentJobId,
    currentJobId, reset, progress, setProgress, setCurrentStage,
  } = useAppStore()

  useJobWebSocket(currentJobId)

  const isActive = ACTIVE_STATES.includes(uiState)

  const { data: jobStatus } = useQuery({
    queryKey: ['job', currentJobId],
    queryFn: () => getJob(currentJobId!),
    enabled: !!currentJobId && isActive,
    refetchInterval: 3000,
  })

  // Polling is the source of truth for the job state; the WebSocket only makes it live.
  useEffect(() => {
    if (!jobStatus) return
    if (jobStatus.status === 'failed') {
      setUiState('failed')
      toast.error(jobStatus.error_msg || 'Job failed')
      return
    }
    if (jobStatus.status === 'done') {
      setUiState('done')
      return
    }
    if ((ACTIVE_STATES as string[]).includes(jobStatus.status)) {
      setUiState(jobStatus.status as UIState)
    }
    const last = jobStatus.stages?.[jobStatus.stages.length - 1]
    if (last) {
      if (last.progress > useAppStore.getState().progress) setProgress(last.progress)
      if (!useAppStore.getState().currentStage) setCurrentStage(last.stage)
    }
  }, [jobStatus, setUiState, setProgress, setCurrentStage])

  const { data: completedJob } = useQuery({
    queryKey: ['job-done', currentJobId],
    queryFn: () => getJob(currentJobId!),
    enabled: !!currentJobId && uiState === 'done',
  })

  const { data: failedJob } = useQuery({
    queryKey: ['job-failed', currentJobId],
    queryFn: () => getJob(currentJobId!),
    enabled: !!currentJobId && uiState === 'failed',
  })

  const handleSearch = async () => {
    if (!query.trim()) return
    setLoading(true)
    try {
      const result = await searchPreview(query, queryType, language)
      setPreview(result)
      setUiState('previewing')
    } catch (e) {
      toast.error(errorDetail(e, 'Search preview failed. Is the backend running?'))
    } finally {
      setLoading(false)
    }
  }

  const handleGenerate = async () => {
    setLoading(true)
    try {
      const result = await createJob({
        query, query_type: queryType, language, options,
      })
      setCurrentJobId(result.job_id)
      setUiState('queued')
      toast.success('Dataset job started')
    } catch (e) {
      toast.error(errorDetail(e, 'Could not start the job'))
    } finally {
      setLoading(false)
    }
  }

  const showSearch = uiState === 'idle' || uiState === 'previewing'

  return (
    <div className="shell relative max-w-4xl space-y-8 pb-12">
      {showSearch ? (
        <>
          <div aria-hidden className="aurora-glow pointer-events-none absolute left-1/2 top-0 -z-10 h-[420px] w-[720px] -translate-x-1/2" />
          <section className="pt-10 text-center sm:pt-14">
            <span className="eyebrow">Voice dataset builder</span>
            <h1 className="display mx-auto mt-5 max-w-3xl text-[40px] sm:text-[60px]">
              Any voice, <span className="text-aurora">ready to train.</span>
            </h1>
            <p className="mx-auto mt-5 max-w-xl text-[16px] leading-relaxed text-mid">
              Search a character, celebrity or voice actor. The studio finds the audio, isolates the voice,
              slices it into clean clips, transcribes them and packages a dataset for Beatrice, RVC or TTS training.
            </p>
          </section>

          <SearchBar onSearch={handleSearch} onGenerate={handleGenerate} loading={loading} />
        </>
      ) : (
        <div className="hairline-b flex items-center justify-between pb-4 pt-8">
          <button onClick={() => reset()} className="btn-secondary btn-sm">
            <ArrowLeft className="h-4 w-4" strokeWidth={1.75} /> New search
          </button>
          <span className="font-mono text-[12px] uppercase tracking-[0.08em] text-lo">
            Job {currentJobId?.slice(0, 8)}
          </span>
        </div>
      )}

      {preview && uiState === 'previewing' && (
        <>
          <SourcePreview preview={preview} />
          <AdvancedOptions />
        </>
      )}

      {isActive && (
        <>
          <JobProgress />
          <LiveClipFeed />
        </>
      )}

      {uiState === 'done' && completedJob && <DatasetViewer job={completedJob} />}

      {uiState === 'failed' && (
        <div className="card flex items-start gap-4 border-bad/30 bg-bad/5">
          <CircleAlert className="mt-0.5 h-5 w-5 shrink-0 text-bad" strokeWidth={1.75} />
          <div>
            <p className="font-medium text-bad">The job failed</p>
            <p className="mt-1 text-[14px] text-mid">
              {failedJob?.error_msg || 'Try other settings or a different search strategy.'}
            </p>
            {progress > 0 && <p className="mt-2 font-mono text-[12px] text-lo">Stopped at {progress}%</p>}
          </div>
        </div>
      )}
    </div>
  )
}

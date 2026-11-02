import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { Download, RefreshCw, Trash2, Clock, Layers, Eye, Calendar, Loader2, ArrowRight } from 'lucide-react'
import toast from 'react-hot-toast'
import { api, getHistory, type HistoryItem } from '@/lib/api'
import { useAppStore, type UIState } from '@/store/appStore'
import { BrandMark } from '@/components/BrandMark'

const ACTIVE = ['queued', 'searching', 'downloading', 'processing', 'packaging']

function statusClass(status: string) {
  if (status === 'done') return 'badge badge-ok'
  if (status === 'failed') return 'badge badge-bad'
  if (ACTIVE.includes(status)) return 'badge badge-accent'
  return 'badge'
}

function dotClass(status: string) {
  if (status === 'done') return 'dot dot-ok'
  if (status === 'failed') return 'dot dot-bad'
  if (ACTIVE.includes(status)) return 'dot dot-accent animate-breathe'
  return 'dot'
}

export function HistoryPage() {
  const navigate = useNavigate()
  const { setCurrentJobId, setUiState, setQuery, setQueryType, setLanguage } = useAppStore()

  const { data: history, refetch, isLoading, isError, isFetching } = useQuery({
    queryKey: ['history'],
    queryFn: getHistory,
    refetchInterval: 10000,
  })

  const handleViewJob = (job: HistoryItem) => {
    setCurrentJobId(job.id)
    setQuery(job.query)
    setQueryType(job.query_type)
    setLanguage(job.language || '')
    if (job.status === 'done') setUiState('done')
    else if (job.status === 'failed') setUiState('failed')
    else setUiState((ACTIVE.includes(job.status) ? job.status : 'processing') as UIState)
    navigate('/')
  }

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this job and all of its audio files?')) return
    try {
      await api.delete(`/api/jobs/${id}`)
      toast.success('Job deleted')
      refetch()
    } catch {
      toast.error('Delete failed')
    }
  }

  return (
    <div className="shell max-w-4xl space-y-8 pb-12 animate-slideIn">
      <div className="flex flex-wrap items-end justify-between gap-4 pt-10 sm:pt-14">
        <div>
          <span className="eyebrow">History</span>
          <h1 className="display mt-4 text-[36px] sm:text-[48px]">Your datasets.</h1>
          <p className="mt-3 text-[15px] text-mid">Every build and conversion, ready to download again.</p>
        </div>
        <button onClick={() => refetch()} className="btn-secondary btn-sm">
          <RefreshCw className={`h-3.5 w-3.5 ${isFetching ? 'animate-spin' : ''}`} strokeWidth={1.75} /> Refresh
        </button>
      </div>

      {isLoading ? (
        <div className="flex flex-col items-center justify-center gap-3 py-20 text-lo">
          <Loader2 className="h-6 w-6 animate-spin text-accent" />
          <span className="eyebrow">Loading history</span>
        </div>
      ) : isError ? (
        <div className="card text-center text-[14px] text-mid">
          The backend is not reachable. Start it with the start script, then refresh.
        </div>
      ) : !history?.length ? (
        <div className="card flex flex-col items-center gap-4 py-14 text-center">
          <BrandMark detail className="h-14 w-14 text-lo" />
          <p className="text-[15px] text-mid">No datasets yet.</p>
          <Link to="/" className="btn-primary btn-sm">
            Build your first dataset <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        </div>
      ) : (
        <ul className="space-y-3">
          {history.map((job) => (
            <li key={job.id} className="card card-hover flex items-center justify-between gap-4 !p-5">
              <button className="min-w-0 flex-1 space-y-2 text-left" onClick={() => handleViewJob(job)}>
                <div className="flex flex-wrap items-center gap-2.5">
                  <span className={dotClass(job.status)} />
                  <h3 className="truncate text-[16px] font-medium">{job.query}</h3>
                  <span className={statusClass(job.status)}>{job.status}</span>
                  <span className="badge">{job.query_type.replace('_', ' ')}</span>
                  {job.language && job.query_type !== 'conversion' && <span className="badge">{job.language}</span>}
                </div>
                <div className="flex flex-wrap items-center gap-x-5 gap-y-1 pl-[17px] font-mono text-[12px] text-lo">
                  <span className="flex items-center gap-1.5">
                    <Layers className="h-3.5 w-3.5" strokeWidth={1.75} />
                    {job.total_clips} {job.query_type === 'conversion' ? 'files' : 'clips'}
                  </span>
                  {job.query_type !== 'conversion' && (
                    <span className="flex items-center gap-1.5">
                      <Clock className="h-3.5 w-3.5" strokeWidth={1.75} /> {(job.total_seconds / 60).toFixed(1)} min
                    </span>
                  )}
                  <span className="flex items-center gap-1.5">
                    <Calendar className="h-3.5 w-3.5" strokeWidth={1.75} />
                    {new Date(job.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
                  </span>
                </div>
              </button>

              <div className="flex shrink-0 items-center gap-2">
                <button onClick={() => handleViewJob(job)} className="icon-btn" title="Open" aria-label={`Open ${job.query}`}>
                  <Eye className="h-4 w-4" strokeWidth={1.75} />
                </button>
                {job.download_url && (
                  <a href={job.download_url} className="icon-btn" title="Download ZIP" aria-label={`Download ${job.query}`}>
                    <Download className="h-4 w-4" strokeWidth={1.75} />
                  </a>
                )}
                <button onClick={() => handleDelete(job.id)} className="icon-btn danger" title="Delete" aria-label={`Delete ${job.query}`}>
                  <Trash2 className="h-4 w-4" strokeWidth={1.75} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

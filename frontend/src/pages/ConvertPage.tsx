import { useCallback, useState } from 'react'
import { useDropzone } from 'react-dropzone'
import { Upload, Download, Loader2, FileAudio, X, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { api } from '@/lib/api'
import { SelectField, Switch } from '@/components/ui'

export function ConvertPage() {
  const [files, setFiles] = useState<File[]>([])
  const [converting, setConverting] = useState(false)
  const [progress, setProgress] = useState(0)
  const [downloadUrl, setDownloadUrl] = useState<string | null>(null)
  const [sampleRate, setSampleRate] = useState(22050)
  const [bitDepth, setBitDepth] = useState(16)
  const [channels, setChannels] = useState('mono')
  const [normalize, setNormalize] = useState(true)

  const onDrop = useCallback((accepted: File[]) => {
    setFiles((prev) => [...prev, ...accepted])
    setDownloadUrl(null)
  }, [])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'audio/*': ['.wav', '.mp3', '.flac', '.ogg', '.opus', '.m4a', '.aac', '.aiff', '.webm'],
      'application/octet-stream': ['.parquet', '.npy', '.arrow', '.hdf5', '.h5', '.7z'],
      'application/zip': ['.zip'],
      'application/gzip': ['.tar.gz', '.tgz'],
    },
  })

  const removeFile = (idx: number) => {
    setFiles((prev) => prev.filter((_, i) => i !== idx))
  }

  const clearAll = () => {
    setFiles([])
    setDownloadUrl(null)
  }

  const totalMb = files.reduce((sum, f) => sum + f.size, 0) / (1024 * 1024)

  const handleConvert = async () => {
    if (files.length === 0) return
    setConverting(true)
    setProgress(0)

    const formData = new FormData()
    files.forEach((f) => formData.append('files', f))
    formData.append('target_format', 'wav')
    formData.append('sample_rate', String(sampleRate))
    formData.append('bit_depth', String(bitDepth))
    formData.append('channels', channels)
    formData.append('normalize', String(normalize))

    try {
      const res = await api.post('/api/convert', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: (e) => {
          if (e.total) setProgress(Math.round((e.loaded / e.total) * 100))
        },
      })
      setProgress(100)
      if (res.data.files_converted > 0) {
        setDownloadUrl(res.data.download_url)
        toast.success(`Converted ${res.data.files_converted} files`)
      } else {
        toast.error(res.data.errors?.[0] || 'Nothing could be converted')
      }
      if (res.data.errors?.length && res.data.files_converted > 0) {
        toast.error(`${res.data.errors.length} file(s) were skipped`)
      }
    } catch {
      toast.error('Conversion failed')
    } finally {
      setConverting(false)
    }
  }

  return (
    <div className="shell max-w-3xl space-y-8 pb-12 animate-slideIn">
      <section className="pt-10 text-center sm:pt-14">
        <span className="eyebrow">Universal converter</span>
        <h1 className="display mt-5 text-[36px] sm:text-[48px]">Bring your own audio.</h1>
        <p className="mx-auto mt-4 max-w-lg text-[15px] text-mid">
          Turn recordings, Hugging Face Parquet shards or whole archives into clean, training-ready WAV files.
        </p>
      </section>

      <div
        {...getRootProps()}
        className={`group cursor-pointer rounded-card border border-dashed px-6 py-14 text-center transition-colors ${
          isDragActive ? 'border-accent bg-card-active' : 'border-line-strong bg-card hover:bg-card-hover'
        }`}
      >
        <input {...getInputProps()} />
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full border border-line">
          <Upload className={`h-6 w-6 transition-colors ${isDragActive ? 'text-accent' : 'text-mid group-hover:text-hi'}`} strokeWidth={1.5} />
        </div>
        <p className="mt-5 text-[16px] font-medium">Drop files here, or click to browse</p>
        <p className="mt-2 font-mono text-[12px] text-lo">WAV · MP3 · FLAC · OGG · OPUS · M4A · Parquet · NPY · ZIP · TAR.GZ · 7Z</p>
      </div>

      {files.length > 0 && (
        <div className="card space-y-4">
          <div className="flex items-center justify-between">
            <span className="eyebrow">
              {files.length} file{files.length === 1 ? '' : 's'} · {totalMb.toFixed(1)} MB
            </span>
            <button onClick={clearAll} className="btn-danger btn-sm">
              <Trash2 className="h-3.5 w-3.5" strokeWidth={1.75} /> Clear all
            </button>
          </div>
          <ul className="max-h-56 space-y-1.5 overflow-y-auto pr-1">
            {files.map((f, i) => (
              <li key={`${f.name}-${i}`} className="tile flex items-center justify-between gap-3 !py-2.5">
                <span className="flex min-w-0 items-center gap-2.5">
                  <FileAudio className="h-4 w-4 shrink-0 text-accent" strokeWidth={1.75} />
                  <span className="truncate font-mono text-[12px] text-hi">{f.name}</span>
                  <span className="shrink-0 font-mono text-[11px] text-lo">{(f.size / (1024 * 1024)).toFixed(2)} MB</span>
                </span>
                <button onClick={() => removeFile(i)} className="icon-btn !h-7 !w-7 border-transparent" aria-label={`Remove ${f.name}`}>
                  <X className="h-3.5 w-3.5" />
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="card grid grid-cols-1 gap-6 sm:grid-cols-2">
        <SelectField
          label="Sample rate"
          value={sampleRate}
          onChange={setSampleRate}
          options={[
            { value: 16000, label: '16 kHz · speech models' },
            { value: 22050, label: '22.05 kHz · recommended' },
            { value: 44100, label: '44.1 kHz · high fidelity' },
          ]}
        />
        <SelectField
          label="Bit depth"
          value={bitDepth}
          onChange={setBitDepth}
          options={[
            { value: 16, label: '16-bit PCM' },
            { value: 24, label: '24-bit PCM' },
            { value: 32, label: '32-bit float' },
          ]}
        />
        <SelectField
          label="Channels"
          value={channels}
          onChange={setChannels}
          options={[
            { value: 'mono', label: 'Mono · recommended' },
            { value: 'stereo', label: 'Stereo' },
          ]}
        />
        <div className="flex items-end">
          <div className="tile w-full !py-2.5">
            <Switch label="Normalise loudness" description="To -20 dBFS RMS" checked={normalize} onChange={setNormalize} />
          </div>
        </div>
      </div>

      {converting && (
        <div className="space-y-2 animate-fadeIn">
          <div className="flex justify-between">
            <span className="eyebrow">{progress < 100 ? 'Uploading' : 'Converting'}</span>
            <span className="font-mono text-[12px] text-mid">{progress}%</span>
          </div>
          <div className="meter">
            <span style={{ width: `${progress}%` }} />
          </div>
        </div>
      )}

      <div className="flex flex-col gap-3 sm:flex-row">
        <button onClick={handleConvert} disabled={files.length === 0 || converting} className="btn-primary btn-lg flex-1">
          {converting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" strokeWidth={2} />}
          {files.length > 0 ? `Convert ${files.length} file${files.length === 1 ? '' : 's'}` : 'Convert'}
        </button>
        {downloadUrl && (
          <a href={downloadUrl} className="btn-secondary btn-lg">
            <Download className="h-4 w-4" strokeWidth={1.75} /> Download ZIP
          </a>
        )}
      </div>
    </div>
  )
}

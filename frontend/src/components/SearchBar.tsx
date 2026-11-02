import { Search, Play, Loader2, Tv, Star, Mic, Gamepad2, Music, Sparkles } from 'lucide-react'
import { useAppStore } from '@/store/appStore'
import { WaveformHero } from './WaveformHero'

const QUERY_TYPES = [
  { id: 'anime', label: 'Anime', icon: Tv },
  { id: 'celebrity', label: 'Celebrity', icon: Star },
  { id: 'voice_actor', label: 'Voice actor', icon: Mic },
  { id: 'game_character', label: 'Game', icon: Gamepad2 },
  { id: 'musician', label: 'Musician', icon: Music },
  { id: 'fictional', label: 'Fictional', icon: Sparkles },
]

const LANGUAGES = [
  { id: 'jp', label: 'Japanese' },
  { id: 'en', label: 'English' },
  { id: 'both', label: 'Both' },
]

const SUGGESTIONS = [
  { name: 'Satoru Gojo', type: 'anime' },
  { name: 'Hatsune Miku', type: 'musician' },
  { name: 'Eminem', type: 'celebrity' },
  { name: 'Geralt of Rivia', type: 'game_character' },
]

interface SearchBarProps {
  onSearch: () => void
  onGenerate: () => void
  loading: boolean
}

export function SearchBar({ onSearch, onGenerate, loading }: SearchBarProps) {
  const {
    query, setQuery, queryType, setQueryType,
    language, setLanguage, uiState, progress, preview,
  } = useAppStore()

  const showGenerate = preview !== null

  return (
    <div className="mx-auto max-w-4xl space-y-8 animate-slideIn">
      <div className="card !p-1.5">
        <WaveformHero uiState={uiState} progress={progress} />
      </div>

      <div className="space-y-4">
        <div className="group relative flex items-center rounded-full border border-line bg-card pl-5 pr-1.5 transition-colors focus-within:border-accent hover:border-line-strong">
          <Search className="h-5 w-5 shrink-0 text-lo transition-colors group-focus-within:text-accent" strokeWidth={1.75} />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && onSearch()}
            placeholder="Search any character, celebrity or voice actor"
            aria-label="Voice to search for"
            className="h-14 w-full min-w-0 bg-transparent px-4 text-[16px] text-hi placeholder:text-lo focus:outline-none"
          />
          <button
            onClick={showGenerate ? onGenerate : onSearch}
            disabled={!query.trim() || loading}
            className="btn-primary h-11 shrink-0 px-5"
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : showGenerate ? (
              <Play className="h-4 w-4 fill-current" />
            ) : (
              <Search className="h-4 w-4" strokeWidth={2} />
            )}
            <span>{showGenerate ? 'Build dataset' : 'Find sources'}</span>
          </button>
        </div>

        <div className="flex flex-wrap items-center justify-center gap-2">
          <span className="eyebrow mr-1">Try</span>
          {SUGGESTIONS.map((s) => (
            <button
              key={s.name}
              onClick={() => {
                setQuery(s.name)
                setQueryType(s.type)
              }}
              className="chip"
            >
              {s.name}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-4">
        <span className="eyebrow block text-center">Category</span>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-6">
          {QUERY_TYPES.map((t) => {
            const Icon = t.icon
            const isSelected = queryType === t.id
            return (
              <button
                key={t.id}
                onClick={() => setQueryType(t.id)}
                aria-pressed={isSelected}
                className={`flex flex-col items-center justify-center gap-2.5 rounded-card border px-3 py-4 text-center transition-colors ${
                  isSelected
                    ? 'border-accent bg-card-active text-hi'
                    : 'border-line bg-card text-mid hover:border-line-strong hover:text-hi'
                }`}
              >
                <Icon className={`h-5 w-5 ${isSelected ? 'text-accent' : ''}`} strokeWidth={1.75} />
                <span className="text-[13px] font-medium">{t.label}</span>
              </button>
            )
          })}
        </div>
      </div>

      {(queryType === 'anime' || queryType === 'fictional' || queryType === 'game_character') && (
        <div className="flex flex-col items-center gap-3 animate-fadeIn">
          <span className="eyebrow">Target language</span>
          <div className="segmented" role="radiogroup" aria-label="Target language">
            {LANGUAGES.map((l) => (
              <button
                key={l.id}
                role="radio"
                aria-checked={language === l.id}
                data-active={language === l.id}
                onClick={() => setLanguage(l.id)}
                className="segmented-item"
              >
                {l.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

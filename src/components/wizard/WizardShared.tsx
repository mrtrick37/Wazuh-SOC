const STEP_LABELS = ['Welcome', 'Wazuh API', 'OpenSearch', 'Analyst User', 'Complete']

export function ProgressBar({ current }: { current: number }) {
  return (
    <div className="flex items-center gap-2 mb-8">
      {STEP_LABELS.map((label, i) => (
        <div key={label} className="flex items-center gap-2 flex-1 last:flex-none">
          <div className="flex items-center gap-1.5">
            <div
              className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-semibold transition-colors ${
                i < current
                  ? 'bg-blue-600 text-white'
                  : i === current
                    ? 'bg-blue-600/30 border border-blue-500 text-blue-300'
                    : 'bg-slate-800 border border-slate-600 text-slate-500'
              }`}
            >
              {i < current ? '✓' : i + 1}
            </div>
            <span
              className={`text-xs hidden sm:block ${
                i === current ? 'text-slate-300' : 'text-slate-500'
              }`}
            >
              {label}
            </span>
          </div>
          {i < STEP_LABELS.length - 1 && (
            <div
              className={`flex-1 h-px transition-colors ${
                i < current ? 'bg-blue-600' : 'bg-slate-700'
              }`}
            />
          )}
        </div>
      ))}
    </div>
  )
}

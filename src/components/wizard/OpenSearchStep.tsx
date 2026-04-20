import { useState } from 'react'
import { ArrowRight, ArrowLeft } from 'lucide-react'
import { Spinner } from '@/components/ui/Spinner'
import type { OpenSearchFields } from './types'

interface OpenSearchStepProps {
  fields: OpenSearchFields
  onChange: (f: Partial<OpenSearchFields>) => void
  onNext: () => void
  onBack: () => void
}

export function OpenSearchStep({ fields, onChange, onNext, onBack }: OpenSearchStepProps) {
  const [testing, setTesting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleNext = async () => {
    setTesting(true)
    setError(null)
    try {
      const credentials = btoa(`${fields.username}:${fields.password}`)
      const res = await fetch(`${fields.url}/_cluster/health`, {
        headers: { Authorization: `Basic ${credentials}` },
      })
      if (!res.ok) throw new Error(`Connection failed (${res.status})`)
      onNext()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Connection failed')
    } finally {
      setTesting(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white">OpenSearch</h2>
        <p className="text-slate-400 text-sm mt-1">
          Enter the URL and credentials for your OpenSearch cluster.
        </p>
      </div>

      {error && (
        <div className="text-sm text-red-400 bg-red-900/30 border border-red-700/50 rounded-md px-3 py-2">
          {error}
        </div>
      )}

      <div className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1.5">OpenSearch URL</label>
          <input
            type="url"
            value={fields.url}
            onChange={(e) => onChange({ url: e.target.value })}
            placeholder="https://your-opensearch:9200"
            className="w-full bg-slate-900 border border-slate-600 rounded-md px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50 transition-colors"
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1.5">Username</label>
          <input
            type="text"
            value={fields.username}
            onChange={(e) => onChange({ username: e.target.value })}
            placeholder="admin"
            className="w-full bg-slate-900 border border-slate-600 rounded-md px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50 transition-colors"
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1.5">Password</label>
          <input
            type="password"
            value={fields.password}
            onChange={(e) => onChange({ password: e.target.value })}
            placeholder="••••••••"
            className="w-full bg-slate-900 border border-slate-600 rounded-md px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50 transition-colors"
          />
        </div>
      </div>

      <div className="flex justify-between pt-2">
        <button
          onClick={onBack}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-slate-400 hover:text-white text-sm transition-colors"
        >
          <ArrowLeft className="w-4 h-4" /> Back
        </button>
        <button
          onClick={() => { void handleNext() }}
          disabled={testing || !fields.url || !fields.username || !fields.password}
          className="flex items-center gap-2 bg-blue-600 hover:bg-blue-500 disabled:bg-slate-600 text-white font-semibold px-6 py-2 rounded-lg text-sm transition-colors"
        >
          {testing ? <><Spinner className="w-4 h-4" /> Testing…</> : <>Next <ArrowRight className="w-4 h-4" /></>}
        </button>
      </div>
    </div>
  )
}

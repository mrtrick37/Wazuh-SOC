import { ShieldCheck, Terminal, Wrench, Play, Pause } from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { useAuth } from '@/hooks/useAuth'
import { useState } from 'react'

export function AdminUpdatePage() {
  const { isAdmin } = useAuth()
  const [isUpdating, setIsUpdating] = useState(false)
  const [status, setStatus] = useState<'idle' | 'running' | 'success' | 'error'>('idle')
  const [logs, setLogs] = useState<string[]>([])
  const [currentJobId, setCurrentJobId] = useState<string | null>(null)
  const [skipGitPull, setSkipGitPull] = useState(false)
  const [skipBuild, setSkipBuild] = useState(false)
  const [nonInteractive, setNonInteractive] = useState(true)

  const downloadLog = () => {
    if (!currentJobId) return
    const token = sessionStorage.getItem('wazuh_jwt')
    if (!token) return

    fetch(`/api/admin/update/log/${currentJobId}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(async (res) => {
        if (!res.ok) throw new Error('Could not download log')
        const blob = await res.blob()
        const url = URL.createObjectURL(blob)
        const anchor = document.createElement('a')
        anchor.href = url
        anchor.download = `update-job-${currentJobId}.log`
        document.body.appendChild(anchor)
        anchor.click()
        anchor.remove()
        URL.revokeObjectURL(url)
      })
      .catch((err) => {
        setLogs((prev) => [...prev, `Error: ${err instanceof Error ? err.message : 'Failed to download log'}`])
      })
  }

  if (!isAdmin) {
    return (
      <div className="p-6">
        <Card>
          <CardHeader>
            <CardTitle>Admin Access Required</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-slate-300">
              You must be an admin user to view this page.
            </p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const handleStartUpdate = async () => {
    setIsUpdating(true)
    setStatus('running')
    setLogs(['Starting update...'])

    try {
      const token = sessionStorage.getItem('wazuh_jwt')
      if (!token) {
        throw new Error('Authentication token not found. Please log in again.')
      }

      // Start the job — backend returns immediately with a jobId
      const startRes = await fetch('/api/admin/update', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({ skipGitPull, skipBuild, nonInteractive }),
      })

      const startData = await startRes.json().catch(() => ({}))

      if (!startRes.ok) {
        if (startRes.status === 409 && startData.jobId) {
          setLogs((prev) => [
            ...prev,
            'Another admin update is already running. Attaching to that job...',
          ])
          setCurrentJobId(startData.jobId)
        } else {
          throw new Error(startData.message || `Failed to start update: ${startRes.status}`)
        }
      }

      const jobId = startData.jobId as string | undefined

      if (!jobId) {
        throw new Error('No update job ID received from backend')
      }

      setCurrentJobId(jobId)
      setLogs((prev) => [...prev, `Job started (${jobId}), waiting for completion...`])

      // Poll status every 2 seconds until done
      let lastOutputLen = 0
      let transientFailures = 0
      await new Promise<void>((resolve, reject) => {
        const poll = setInterval(async () => {
          try {
            const statusRes = await fetch(`/api/admin/update/status/${jobId}`, {
              headers: { 'Authorization': `Bearer ${token}` },
            })
            if (!statusRes.ok) {
              transientFailures += 1
              if (transientFailures >= 30) {
                clearInterval(poll)
                reject(new Error('Update status endpoint unavailable for too long'))
              }
              return
            }

            transientFailures = 0

            const job = await statusRes.json()

            // Append any new output lines
            const newOutput = job.output?.slice(lastOutputLen) ?? ''
            if (newOutput) {
              lastOutputLen += newOutput.length
              setLogs((prev) => [...prev, newOutput.trimEnd()])
            }

            if (job.status === 'success') {
              clearInterval(poll)
              setStatus('success')
              setLogs((prev) => [...prev, 'Update completed successfully.'])
              resolve()
            } else if (job.status === 'failed') {
              clearInterval(poll)
              const errText = job.error?.trim()
              if (errText) setLogs((prev) => [...prev, errText])
              reject(new Error(`Update failed with exit code ${job.exitCode}`))
            }
          } catch (pollErr) {
            transientFailures += 1
            if (transientFailures >= 30) {
              clearInterval(poll)
              reject(pollErr)
            }
          }
        }, 2000)
      })
    } catch (error) {
      setLogs((prev) => [
        ...prev,
        `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      ])
      setStatus('error')
    } finally {
      setIsUpdating(false)
    }
  }

  const handleClearLogs = () => {
    setLogs([])
    setStatus('idle')
    setCurrentJobId(null)
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-lg font-semibold text-white">Admin Tools</h1>
        <p className="text-sm text-slate-400 mt-0.5">
          Administrative controls for maintaining the Wazuh SOC deployment.
        </p>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-2">
            <Wrench className="w-4 h-4 text-blue-400" />
            <CardTitle>Update Wazuh SOC</CardTitle>
          </div>
        </CardHeader>
        <CardContent className="space-y-6">
          <p className="text-sm text-slate-300 leading-relaxed">
            Trigger a dashboard update from this interface. The update will pull the latest
            code, rebuild assets, and reload nginx.
          </p>

          {/* Update Options */}
          <div className="space-y-3 rounded-lg border border-slate-700 bg-slate-900/50 p-4">
            <h3 className="text-sm font-semibold text-slate-300">Update Options</h3>
            <div className="space-y-2 text-sm">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={skipGitPull}
                  onChange={(e) => setSkipGitPull(e.target.checked)}
                  disabled={isUpdating}
                  className="w-4 h-4"
                />
                <span className="text-slate-300">Skip Git Pull</span>
                <span className="text-xs text-slate-500">(use existing code)</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={skipBuild}
                  onChange={(e) => setSkipBuild(e.target.checked)}
                  disabled={isUpdating}
                  className="w-4 h-4"
                />
                <span className="text-slate-300">Skip Build</span>
                <span className="text-xs text-slate-500">(use existing dist/)</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={nonInteractive}
                  onChange={(e) => setNonInteractive(e.target.checked)}
                  disabled={isUpdating}
                  className="w-4 h-4"
                />
                <span className="text-slate-300">Non-Interactive Mode</span>
                <span className="text-xs text-slate-500">(skip confirmation prompts)</span>
              </label>
            </div>
          </div>

          {/* Control Buttons */}
          <div className="flex gap-2">
            <button
              onClick={handleStartUpdate}
              disabled={isUpdating}
              className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 disabled:bg-slate-600 text-white text-sm font-semibold transition-colors"
            >
              {isUpdating ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
              {isUpdating ? 'Updating...' : 'Start Update'}
            </button>
            <button
              onClick={handleClearLogs}
              disabled={isUpdating}
              className="px-4 py-2 rounded-lg bg-slate-700 hover:bg-slate-600 disabled:bg-slate-800 text-slate-300 text-sm transition-colors"
            >
              Clear Logs
            </button>
            <button
              onClick={downloadLog}
              disabled={!currentJobId}
              className="px-4 py-2 rounded-lg bg-slate-700 hover:bg-slate-600 disabled:bg-slate-800 text-slate-300 text-sm transition-colors"
            >
              Download Log
            </button>
          </div>

          {/* Status Indicator */}
          {status !== 'idle' && (
            <div
              className={`rounded-lg p-3 text-sm font-semibold flex items-center gap-2 ${
                status === 'running'
                  ? 'bg-blue-900/30 text-blue-300'
                  : status === 'success'
                    ? 'bg-green-900/30 text-green-300'
                    : 'bg-red-900/30 text-red-300'
              }`}
            >
              <div className={`w-2 h-2 rounded-full ${status === 'running' ? 'animate-pulse' : ''}`} />
              {status === 'running' && 'Update in progress...'}
              {status === 'success' && 'Update completed successfully'}
              {status === 'error' && 'Update failed'}
            </div>
          )}

          {/* Logs Display */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-slate-400 uppercase">Update Log</label>
            <div className="rounded-lg border border-slate-700 bg-slate-950 p-3 font-mono text-xs text-slate-300 max-h-64 overflow-y-auto space-y-1">
              {logs.length === 0 ? (
                <div className="text-slate-500">No logs yet. Start an update to see progress.</div>
              ) : (
                logs.map((log, idx) => (
                  <div key={idx} className="text-slate-400">
                    {'> '} {log}
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="rounded-lg border border-slate-700 bg-slate-900/70 p-3 text-xs text-slate-400 space-y-2">
            <p className="flex items-center gap-2">
              <ShieldCheck className="w-3.5 h-3.5 text-slate-500" />
              This control is visible only to authenticated admin users.
            </p>
            <p className="flex items-center gap-2">
              <Terminal className="w-3.5 h-3.5 text-slate-500" />
              Requires: Backend API at <code className="bg-slate-800 px-1 rounded">/api/admin/update</code>
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

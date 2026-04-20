/**
 * Setup wizard root container.
 * Shown on first run; re-accessible via Sidebar Settings.
 */

import { useState } from 'react'
import { ArrowRight, CheckCircle2, Database, ExternalLink, Server, ShieldAlert } from 'lucide-react'
import { saveConfig, loadConfig } from '@/lib/config'
import { loginWithUrl } from '@/api/client'
import type { AnalystUserFields, OpenSearchFields, WazuhFields } from './types'
import { ProgressBar } from './WizardShared'
import { WelcomeStep } from './WelcomeStep'
import { WazuhApiStep } from './WazuhApiStep'
import { OpenSearchStep } from './OpenSearchStep'
import { AnalystUserStep } from './AnalystUserStep'

interface SetupWizardProps {
  onComplete: () => void
}

function CompleteStep({
  wazuh,
  opensearch,
  analyst,
  onFinish,
}: {
  wazuh: WazuhFields
  opensearch: OpenSearchFields
  analyst: AnalystUserFields
  onFinish: () => Promise<void>
}) {
  return (
    <div className="text-center space-y-6">
      <div className="flex justify-center">
        <div className="w-20 h-20 rounded-2xl bg-green-600/20 border border-green-500/30 flex items-center justify-center">
          <CheckCircle2 className="w-10 h-10 text-green-400" />
        </div>
      </div>

      <div>
        <h2 className="text-2xl font-bold text-white">All set!</h2>
        <p className="text-slate-400 mt-2">
          Your dashboard is connected and ready to use.
        </p>
      </div>

      <div className="text-left bg-slate-800/60 rounded-xl border border-slate-700 divide-y divide-slate-700">
        <div className="px-5 py-4">
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-3">Configuration Summary</p>
          <div className="space-y-3">
            {[
              { icon: Server, label: 'Wazuh API', value: wazuh.url, sub: `User: ${wazuh.username}` },
              { icon: Database, label: 'OpenSearch', value: opensearch.url, sub: `User: ${opensearch.username}` },
              { icon: ShieldAlert, label: 'Analyst User', value: analyst.username, sub: 'Authenticated for dashboard sign-in' },
            ].map(({ icon: Icon, label, value, sub }) => (
              <div key={label} className="flex items-center gap-3">
                <Icon className="w-4 h-4 text-slate-500 shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-slate-400">{label}</p>
                  <p className="text-sm text-slate-200 font-mono truncate">{value}</p>
                  <p className="text-xs text-slate-500">{sub}</p>
                </div>
                <CheckCircle2 className="w-4 h-4 text-green-500 shrink-0" />
              </div>
            ))}
          </div>
        </div>
        <div className="px-5 py-3">
          <p className="text-xs text-slate-500 flex items-center gap-1.5">
            <ExternalLink className="w-3 h-3" />
            Credentials are stored locally in your browser's localStorage. To change settings, use the gear icon in the sidebar.
          </p>
        </div>
      </div>

      <button
        onClick={() => {
          void onFinish()
        }}
        className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold px-8 py-3 rounded-xl transition-colors text-sm"
      >
        Go to Dashboard <ArrowRight className="w-4 h-4" />
      </button>
    </div>
  )
}

export function SetupWizard({ onComplete }: SetupWizardProps) {
  const existing = loadConfig()
  const [step, setStep] = useState(0)
  const [wazuh, setWazuh] = useState<WazuhFields>({
    url: existing.wazuhApiUrl,
    username: existing.wazuhUser,
    password: existing.wazuhPass,
  })
  const [opensearch, setOpensearch] = useState<OpenSearchFields>({
    url: existing.openSearchUrl,
    username: existing.openSearchUser,
    password: existing.openSearchPass,
  })
  const [analyst, setAnalyst] = useState<AnalystUserFields>({
    username: '',
    password: '',
  })

  const handleFinish = async () => {
    // Always establish runtime API token with the integration account from step 2.
    await loginWithUrl(wazuh.url, wazuh.username, wazuh.password)

    saveConfig({
      wazuhApiUrl: wazuh.url,
      wazuhUser: wazuh.username,
      wazuhPass: wazuh.password,
      openSearchUrl: opensearch.url,
      openSearchUser: opensearch.username,
      openSearchPass: opensearch.password,
      configured: true,
    })

    onComplete()
  }

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-6">
      <div className="w-full max-w-2xl">
        <div className="flex items-center gap-2 mb-8">
          <ShieldAlert className="w-5 h-5 text-blue-400" />
          <span className="text-sm font-semibold text-slate-400">Wazuh SOC · Setup</span>
        </div>

        <ProgressBar current={step} />

        <div className="bg-slate-800/50 border border-slate-700 rounded-2xl p-8">
          {step === 0 && <WelcomeStep onNext={() => setStep(1)} />}
          {step === 1 && (
            <WazuhApiStep
              fields={wazuh}
              onChange={(f) => setWazuh((prev) => ({ ...prev, ...f }))}
              onNext={() => setStep(2)}
              onBack={() => setStep(0)}
            />
          )}
          {step === 2 && (
            <OpenSearchStep
              fields={opensearch}
              onChange={(f) => setOpensearch((prev) => ({ ...prev, ...f }))}
              onNext={() => setStep(3)}
              onBack={() => setStep(1)}
            />
          )}
          {step === 3 && (
            <AnalystUserStep
              apiUrl={wazuh.url}
              openSearchUrl={opensearch.url}
              fields={analyst}
              onChange={(f) => setAnalyst((prev) => ({ ...prev, ...f }))}
              onNext={() => setStep(4)}
              onBack={() => setStep(2)}
            />
          )}
          {step === 4 && (
            <CompleteStep
              wazuh={wazuh}
              opensearch={opensearch}
              analyst={analyst}
              onFinish={handleFinish}
            />
          )}
        </div>
      </div>
    </div>
  )
}

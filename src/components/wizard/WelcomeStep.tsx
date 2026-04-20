import { ShieldAlert, ArrowRight } from 'lucide-react'

export function WelcomeStep({ onNext }: { onNext: () => void }) {
  return (
    <div className="text-center space-y-6">
      <div className="flex justify-center">
        <div className="w-20 h-20 rounded-2xl bg-blue-600/20 border border-blue-500/30 flex items-center justify-center">
          <ShieldAlert className="w-10 h-10 text-blue-400" />
        </div>
      </div>

      <div>
        <h2 className="text-2xl font-bold text-white">Welcome to Wazuh SOC</h2>
        <p className="text-slate-400 mt-2 max-w-md mx-auto">
          This wizard will help you connect the dashboard to your Wazuh and OpenSearch instances.
          You'll need your API credentials ready.
        </p>
      </div>

      <div className="text-left bg-slate-900/50 rounded-xl border border-slate-700 p-4 space-y-2 text-sm text-slate-400">
        <p className="font-semibold text-slate-300">You will need:</p>
        <ul className="space-y-1 list-disc list-inside">
          <li>Wazuh API URL and credentials</li>
          <li>OpenSearch URL and credentials</li>
          <li>An analyst username and password for dashboard login</li>
        </ul>
      </div>

      <button
        onClick={onNext}
        className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold px-8 py-3 rounded-xl transition-colors text-sm"
      >
        Get Started <ArrowRight className="w-4 h-4" />
      </button>
    </div>
  )
}

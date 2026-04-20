import { useState } from 'react'
import { loadConfig } from '@/lib/config'
import { SetupWizard } from '@/components/wizard/SetupWizard'
import { LoginPage } from '@/pages/LoginPage'
import { AdminUpdatePage } from '@/pages/AdminUpdatePage'
import { useAuth } from '@/hooks/useAuth'

export function App() {
  const [configured, setConfigured] = useState(() => loadConfig().configured)
  const { isAuthenticated } = useAuth()

  if (!configured) {
    return <SetupWizard onComplete={() => setConfigured(true)} />
  }

  if (!isAuthenticated) {
    return <LoginPage />
  }

  return <AdminUpdatePage />
}

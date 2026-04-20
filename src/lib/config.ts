export interface AppConfig {
  wazuhApiUrl: string
  wazuhUser: string
  wazuhPass: string
  openSearchUrl: string
  openSearchUser: string
  openSearchPass: string
  configured: boolean
}

const STORAGE_KEY = 'wazuh_soc_config'

const defaults: AppConfig = {
  wazuhApiUrl: '',
  wazuhUser: '',
  wazuhPass: '',
  openSearchUrl: '',
  openSearchUser: '',
  openSearchPass: '',
  configured: false,
}

export function loadConfig(): AppConfig {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? { ...defaults, ...JSON.parse(raw) } : { ...defaults }
  } catch {
    return { ...defaults }
  }
}

export function saveConfig(config: Partial<AppConfig>): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...loadConfig(), ...config }))
}

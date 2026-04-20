import { createContext, useContext, useState, useCallback, type ReactNode, createElement } from 'react'
import { loadConfig } from '@/lib/config'
import { loginWithUrl, clearToken, getToken } from '@/api/client'

interface AuthState {
  isAuthenticated: boolean
  isAdmin: boolean
  isLoading: boolean
  error: string | null
  login: (username: string, password: string) => Promise<void>
  logout: () => void
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    return JSON.parse(atob(token.split('.')[1])) as Record<string, unknown>
  } catch {
    return {}
  }
}

function tokenIsAdmin(token: string | null): boolean {
  if (!token) return false
  const payload = decodeJwtPayload(token)
  const roles = payload['rbac_roles']
  return Array.isArray(roles) && (roles as number[]).includes(1)
}

const AuthContext = createContext<AuthState>({
  isAuthenticated: false,
  isAdmin: false,
  isLoading: false,
  error: null,
  login: async () => {},
  logout: () => {},
})

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(getToken)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const login = useCallback(async (username: string, password: string) => {
    setIsLoading(true)
    setError(null)
    try {
      const { wazuhApiUrl } = loadConfig()
      const t = await loginWithUrl(wazuhApiUrl, username, password)
      setToken(t)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed')
    } finally {
      setIsLoading(false)
    }
  }, [])

  const logout = useCallback(() => {
    clearToken()
    setToken(null)
  }, [])

  return createElement(AuthContext.Provider, {
    value: {
      isAuthenticated: !!token,
      isAdmin: tokenIsAdmin(token),
      isLoading,
      error,
      login,
      logout,
    },
    children,
  })
}

export function useAuth(): AuthState {
  return useContext(AuthContext)
}

const TOKEN_KEY = 'wazuh_jwt'

export async function loginWithUrl(baseUrl: string, username: string, password: string): Promise<string> {
  const credentials = btoa(`${username}:${password}`)
  const res = await fetch(`${baseUrl}/security/user/authenticate`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/json',
    },
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { message?: string }
    throw new Error(body.message ?? `Authentication failed (${res.status})`)
  }
  const data = await res.json() as { data?: { token?: string } }
  const token = data?.data?.token
  if (!token) throw new Error('No token received from Wazuh API')
  sessionStorage.setItem(TOKEN_KEY, token)
  return token
}

export function getToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEY)
}

export function clearToken(): void {
  sessionStorage.removeItem(TOKEN_KEY)
}

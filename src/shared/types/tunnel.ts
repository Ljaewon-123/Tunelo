export interface TunnelConfig {
  id: string
  alias?: string
  host: string
  port: number
  username?: string
  identityFile?: string
  localPort: number
  remoteHost: string
  remotePort: number
  useBackground: boolean
  lastConnectedAt?: string
  createdAt: string
  updatedAt: string
}

export interface TunnelStatus {
  id: string
  connected: boolean
  pid?: number
  connectedAt?: string
  error?: string
}

export interface AppSettings {
  exitToTray: boolean
}

export interface ExternalTunnel {
  id: string // `ext-${pid}`
  source: 'external'
  alias?: string
  pid: number
  localPort: number
  remoteHost: string
  remotePort: number
  sshHost: string
  sshUser?: string
  commandLine: string
}

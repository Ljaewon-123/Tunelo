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

export interface TunnelWithStatus extends TunnelConfig {
  status: TunnelStatus
}

export interface AppSettings {
  exitToTray: boolean
}

/// <reference types="vite/client" />

import type { TunnelConfig, TunnelStatus, AppSettings } from './shared/types/tunnel'

declare global {
  interface Window {
    tunnelAPI: {
      getAll: () => Promise<TunnelConfig[]>
      add: (
        config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>
      ) => Promise<TunnelConfig>
      update: (id: string, patch: Partial<TunnelConfig>) => Promise<TunnelConfig>
      remove: (id: string) => Promise<void>
      connect: (id: string) => Promise<TunnelStatus>
      disconnect: (id: string) => Promise<void>
      disconnectAll: () => Promise<void>
      getStatuses: () => Promise<TunnelStatus[]>
      onStatusChanged: (cb: (status: TunnelStatus) => void) => () => void
      openMainWindow: () => Promise<void>
      showOverlay: () => Promise<void>
      getSettings: () => Promise<AppSettings>
      updateSettings: (patch: Partial<AppSettings>) => Promise<AppSettings>
      setOverlayHeight: (height: number) => void
    }
  }
}

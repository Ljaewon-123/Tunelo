import type { TunnelConfig, TunnelStatus, AppSettings } from '../types/tunnel'

const api = window.tunnelAPI

export const tunnelAPI = {
  getAll: (): Promise<TunnelConfig[]> => api.getAll(),
  add: (config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>): Promise<TunnelConfig> =>
    api.add(config),
  update: (id: string, config: Partial<TunnelConfig>): Promise<TunnelConfig> =>
    api.update(id, config),
  remove: (id: string): Promise<void> => api.remove(id),
  connect: (id: string): Promise<TunnelStatus> => api.connect(id),
  disconnect: (id: string): Promise<void> => api.disconnect(id),
  disconnectAll: (): Promise<void> => api.disconnectAll(),
  getStatuses: (): Promise<TunnelStatus[]> => api.getStatuses(),
  onStatusChanged: (cb: (status: TunnelStatus) => void): (() => void) =>
    api.onStatusChanged(cb),
  openMainWindow: (): Promise<void> => api.openMainWindow(),
  showOverlay: (): Promise<void> => api.showOverlay(),
  getSettings: (): Promise<AppSettings> => api.getSettings(),
  updateSettings: (settings: Partial<AppSettings>): Promise<AppSettings> =>
    api.updateSettings(settings),
  setOverlayHeight: (height: number): void => api.setOverlayHeight(height)
}

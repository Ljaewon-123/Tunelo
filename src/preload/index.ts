import { contextBridge, ipcRenderer } from 'electron'
import { electronAPI } from '@electron-toolkit/preload'
import type { TunnelConfig, TunnelStatus, AppSettings } from '../shared/types/tunnel'

const tunnelAPI = {
  // Tunnel CRUD
  getAll: (): Promise<TunnelConfig[]> => ipcRenderer.invoke('tunnel:getAll'),
  add: (
    config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<TunnelConfig> => ipcRenderer.invoke('tunnel:add', config),
  update: (id: string, patch: Partial<TunnelConfig>): Promise<TunnelConfig> =>
    ipcRenderer.invoke('tunnel:update', id, patch),
  remove: (id: string): Promise<void> => ipcRenderer.invoke('tunnel:remove', id),

  // 연결 / 해제
  connect: (id: string): Promise<TunnelStatus> => ipcRenderer.invoke('tunnel:connect', id),
  disconnect: (id: string): Promise<void> => ipcRenderer.invoke('tunnel:disconnect', id),
  disconnectAll: (): Promise<void> => ipcRenderer.invoke('tunnel:disconnectAll'),
  getStatuses: (): Promise<TunnelStatus[]> => ipcRenderer.invoke('tunnel:getStatuses'),

  // 실시간 상태 변경 구독 (unsubscribe 함수 반환)
  onStatusChanged: (cb: (status: TunnelStatus) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, status: TunnelStatus): void => cb(status)
    ipcRenderer.on('tunnel:statusChanged', handler)
    return () => ipcRenderer.removeListener('tunnel:statusChanged', handler)
  },

  // 앱
  openMainWindow: (): Promise<void> => ipcRenderer.invoke('app:openMainWindow'),
  showOverlay: (): Promise<void> => ipcRenderer.invoke('app:showOverlay'),

  // 설정
  getSettings: (): Promise<AppSettings> => ipcRenderer.invoke('settings:get'),
  updateSettings: (patch: Partial<AppSettings>): Promise<AppSettings> =>
    ipcRenderer.invoke('settings:update', patch),

  // 오버레이 창 크기 조정
  setOverlayHeight: (height: number): void => ipcRenderer.send('overlay:setHeight', height)
}

if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld('electron', electronAPI)
    contextBridge.exposeInMainWorld('tunnelAPI', tunnelAPI)
  } catch (error) {
    console.error(error)
  }
} else {
  // @ts-ignore (define in dts)
  window.electron = electronAPI
  // @ts-ignore (define in dts)
  window.tunnelAPI = tunnelAPI
}

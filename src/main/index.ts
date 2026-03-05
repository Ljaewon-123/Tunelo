import { app, shell, BrowserWindow, ipcMain, Tray, Menu, nativeImage } from 'electron'
import { join } from 'path'
import { existsSync } from 'fs'
import { electronApp, optimizer, is } from '@electron-toolkit/utils'
import { tunnelManager } from './tunnel/manager'
import * as tunnelStore from './tunnel/store'
import type { TunnelConfig, TunnelStatus, AppSettings, ExternalTunnel } from '../shared/types/tunnel'

let mainWindow: BrowserWindow | null = null
let overlayWindow: BrowserWindow | null = null
let tray: Tray | null = null
let isQuitting = false
const externalAliases = new Map<string, string>()

// --- 렌더러 로딩 헬퍼 ---

function loadRenderer(win: BrowserWindow, hash = ''): void {
  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    win.loadURL(process.env['ELECTRON_RENDERER_URL'] + (hash ? `#${hash}` : ''))
  } else {
    win.loadFile(join(__dirname, '../renderer/index.html'), hash ? { hash } : undefined)
  }
}

// --- 창 생성 ---

function createOverlayWindow(): BrowserWindow {
  const win = new BrowserWindow({
    width: 280,
    height: 44,
    x: 16,
    y: 64,
    show: false,
    frame: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: true,
    backgroundColor: '#111827',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false
    }
  })

  win.on('close', (event) => {
    if (!isQuitting) event.preventDefault()
  })

  loadRenderer(win, '/overlay')
  return win
}

function createMainWindow(): BrowserWindow {
  const win = new BrowserWindow({
    width: 960,
    height: 680,
    show: false,
    autoHideMenuBar: true,
    backgroundColor: '#111827',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false
    }
  })

  win.on('ready-to-show', () => win.show())

  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  win.on('close', (event) => {
    if (isQuitting) return
    // 닫기 버튼 → 항상 완전 종료
    event.preventDefault()
    isQuitting = true
    app.quit()
  })

  loadRenderer(win)
  return win
}

function createTray(): Tray {
  const iconPath = join(__dirname, '../../resources/icon.png')
  const icon = existsSync(iconPath)
    ? nativeImage.createFromPath(iconPath)
    : nativeImage.createEmpty()

  const t = new Tray(icon)
  t.setToolTip('Tunelo')

  const menu = Menu.buildFromTemplate([
    { label: 'Open Tunelo', click: showMainWindow },
    { type: 'separator' },
    {
      label: 'Exit',
      click: () => {
        isQuitting = true
        app.quit()
      }
    }
  ])
  t.setContextMenu(menu)
  t.on('double-click', showMainWindow)

  return t
}

// --- 창 관리 ---

function showMainWindow(): void {
  // 오버레이 숨기고 메인 창 표시
  overlayWindow?.hide()
  if (!mainWindow || mainWindow.isDestroyed()) {
    mainWindow = createMainWindow()
  } else {
    mainWindow.show()
    mainWindow.focus()
    mainWindow.webContents.send('tunnel:refreshRequest')
  }
}

function showOverlay(): void {
  // 메인 창 숨기고 오버레이 표시
  mainWindow?.hide()
  if (!overlayWindow || overlayWindow.isDestroyed()) {
    overlayWindow = createOverlayWindow()
    overlayWindow.once('ready-to-show', () => overlayWindow?.show())
  } else {
    overlayWindow.show()
    overlayWindow.webContents.send('tunnel:refreshRequest')
  }
}

function broadcastStatus(status: TunnelStatus): void {
  BrowserWindow.getAllWindows().forEach((win) => {
    if (!win.isDestroyed()) {
      win.webContents.send('tunnel:statusChanged', status)
    }
  })
}

function applyAliases(tunnels: ExternalTunnel[]): ExternalTunnel[] {
  return tunnels.map((t) => ({ ...t, alias: externalAliases.get(t.id) ?? t.alias }))
}

function broadcastExternalUpdate(tunnels: ExternalTunnel[]): void {
  const withAliases = applyAliases(tunnels)
  BrowserWindow.getAllWindows().forEach((win) => {
    if (!win.isDestroyed()) {
      win.webContents.send('tunnel:externalUpdated', withAliases)
    }
  })
}

// --- IPC 핸들러 등록 ---

function registerIpcHandlers(): void {
  // Tunnel CRUD
  ipcMain.handle('tunnel:getAll', () => tunnelStore.getAllTunnels())

  ipcMain.handle(
    'tunnel:add',
    (_, config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>) =>
      tunnelStore.addTunnel(config)
  )

  ipcMain.handle('tunnel:update', (_, id: string, patch: Partial<TunnelConfig>) =>
    tunnelStore.updateTunnel(id, patch)
  )

  ipcMain.handle('tunnel:remove', (_, id: string) => {
    tunnelManager.disconnect(id)
    tunnelStore.removeTunnel(id)
  })

  // 연결 / 해제
  ipcMain.handle('tunnel:connect', async (_, id: string) => {
    const config = tunnelStore.getAllTunnels().find((t) => t.id === id)
    if (!config) throw new Error(`Tunnel ${id} not found`)

    const status = await tunnelManager.connect(config)
    if (status.connected) {
      tunnelStore.updateTunnel(id, { lastConnectedAt: new Date().toISOString() })
    }
    return status
  })

  ipcMain.handle('tunnel:disconnect', (_, id: string) => tunnelManager.disconnect(id))
  ipcMain.handle('tunnel:disconnectAll', () => tunnelManager.disconnectAll())
  ipcMain.handle('tunnel:getStatuses', () => tunnelManager.getAllStatuses())

  // 앱
  ipcMain.handle('app:openMainWindow', () => showMainWindow())
  ipcMain.handle('app:showOverlay', () => showOverlay())

  // 설정
  ipcMain.handle('settings:get', () => tunnelStore.getSettings())
  ipcMain.handle('settings:update', (_, patch: Partial<AppSettings>) =>
    tunnelStore.updateSettings(patch)
  )

  // 외부 터널 조회
  ipcMain.handle('tunnel:getExternal', () => applyAliases(tunnelManager.getExternalTunnels()))

  // 외부 터널 별칭 저장 (모든 창에서 공유, 파일에 영속화)
  ipcMain.handle('external:setAlias', (_, id: string, alias: string) => {
    if (alias) {
      externalAliases.set(id, alias)
    } else {
      externalAliases.delete(id)
    }
    tunnelStore.saveExternalAlias(id, alias)
  })

  // 외부 터널 프로세스 종료
  ipcMain.handle('tunnel:killExternal', (_, pid: number) => {
    process.kill(pid)
  })

  // 오버레이 높이 동적 조정
  ipcMain.on('overlay:setHeight', (event, height: number) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    if (win && !win.isDestroyed()) {
      const [w] = win.getContentSize()
      win.setContentSize(w, Math.max(44, Math.min(height, 400)))
    }
  })
}

// --- 앱 라이프사이클 ---

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.tunelo.app')

  // 저장된 외부 터널 별칭 로드
  for (const [id, alias] of Object.entries(tunnelStore.getExternalAliases())) {
    externalAliases.set(id, alias)
  }

  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window)
  })

  tunnelManager.on('statusChanged', broadcastStatus)
  tunnelManager.on('externalTunnelsUpdated', broadcastExternalUpdate)
  tunnelManager.startScanning(5000)

  registerIpcHandlers()

  tray = createTray()
  overlayWindow = createOverlayWindow()
  mainWindow = createMainWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      mainWindow = createMainWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('before-quit', () => {
  isQuitting = true
  tunnelManager.cleanup()
  tray?.destroy()
  tray = null
  overlayWindow?.destroy()
  overlayWindow = null
})

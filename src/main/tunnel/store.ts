import { app } from 'electron'
import { join } from 'path'
import { readFileSync, writeFileSync, existsSync } from 'fs'
import { randomUUID } from 'crypto'
import { defu } from 'defu'
import { destr } from 'destr'
import type { TunnelConfig, AppSettings } from '../../shared/types/tunnel'

const tunnelsPath = (): string => join(app.getPath('userData'), 'tunnels.json')
const settingsPath = (): string => join(app.getPath('userData'), 'settings.json')

function readJSON<T>(filePath: string, fallback: T): T {
  if (!existsSync(filePath)) return fallback
  return destr<T>(readFileSync(filePath, 'utf-8')) ?? fallback
}

function writeJSON(filePath: string, data: unknown): void {
  writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8')
}

// --- Tunnel CRUD ---

export function getAllTunnels(): TunnelConfig[] {
  return readJSON<TunnelConfig[]>(tunnelsPath(), [])
}

export function addTunnel(
  config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>
): TunnelConfig {
  const tunnels = getAllTunnels()
  const now = new Date().toISOString()
  const newTunnel: TunnelConfig = { ...config, id: randomUUID(), createdAt: now, updatedAt: now }
  tunnels.push(newTunnel)
  writeJSON(tunnelsPath(), tunnels)
  return newTunnel
}

export function updateTunnel(id: string, patch: Partial<TunnelConfig>): TunnelConfig {
  const tunnels = getAllTunnels()
  const idx = tunnels.findIndex((t) => t.id === id)
  if (idx === -1) throw new Error(`Tunnel ${id} not found`)
  const updated: TunnelConfig = { ...tunnels[idx], ...patch, id, updatedAt: new Date().toISOString() }
  tunnels[idx] = updated
  writeJSON(tunnelsPath(), tunnels)
  return updated
}

export function removeTunnel(id: string): void {
  const tunnels = getAllTunnels().filter((t) => t.id !== id)
  writeJSON(tunnelsPath(), tunnels)
}

// --- App Settings ---

const defaultSettings: AppSettings = { exitToTray: true }

export function getSettings(): AppSettings {
  const saved = readJSON<Partial<AppSettings>>(settingsPath(), {})
  return defu(saved, defaultSettings)
}

export function updateSettings(patch: Partial<AppSettings>): AppSettings {
  const updated = defu(patch, getSettings())
  writeJSON(settingsPath(), updated)
  return updated
}

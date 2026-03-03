import { spawn } from 'child_process'
import type { ChildProcess } from 'child_process'
import { EventEmitter } from 'events'
import type { TunnelConfig, TunnelStatus, ExternalTunnel } from '../../shared/types/tunnel'
import { scanExternalTunnels } from './scanner'

function buildSSHArgs(config: TunnelConfig): string[] {
  const args = [
    '-N',
    '-L',
    `${config.localPort}:${config.remoteHost}:${config.remotePort}`,
    '-o',
    'BatchMode=yes',
    '-o',
    'StrictHostKeyChecking=accept-new',
    '-o',
    'ConnectTimeout=10'
  ]

  if (config.port !== 22) args.push('-p', String(config.port))
  if (config.identityFile) args.push('-i', config.identityFile)

  const target = config.username ? `${config.username}@${config.host}` : config.host
  args.push(target)

  return args
}

class TunnelManager extends EventEmitter {
  private processes = new Map<string, ChildProcess>()
  private statuses = new Map<string, TunnelStatus>()
  private externalTunnels: ExternalTunnel[] = []
  private scanInterval: NodeJS.Timeout | null = null
  private isScanning = false

  getStatus(id: string): TunnelStatus {
    return this.statuses.get(id) ?? { id, connected: false }
  }

  getAllStatuses(): TunnelStatus[] {
    return [...this.statuses.values()]
  }

  getExternalTunnels(): ExternalTunnel[] {
    return this.externalTunnels
  }

  private getManagedPids(): Set<number> {
    const pids = new Set<number>()
    for (const [id] of this.processes) {
      const status = this.statuses.get(id)
      if (status?.pid) pids.add(status.pid)
    }
    return pids
  }

  startScanning(intervalMs = 5000): void {
    if (this.scanInterval) return
    this.runScan()
    this.scanInterval = setInterval(() => this.runScan(), intervalMs)
  }

  private async runScan(): Promise<void> {
    if (this.isScanning) return
    this.isScanning = true
    try {
      const found = await scanExternalTunnels(this.getManagedPids())
      this.externalTunnels = found
      this.emit('externalTunnelsUpdated', found)
    } finally {
      this.isScanning = false
    }
  }

  stopScanning(): void {
    if (this.scanInterval) {
      clearInterval(this.scanInterval)
      this.scanInterval = null
    }
  }

  connect(config: TunnelConfig): Promise<TunnelStatus> {
    const existing = this.statuses.get(config.id)
    if (existing?.connected) return Promise.resolve(existing)

    return new Promise((resolve, reject) => {
      const args = buildSSHArgs(config)
      const proc = spawn('ssh', args, { stdio: ['ignore', 'ignore', 'pipe'] })

      let settled = false
      let stderr = ''

      // 즉시 등록해 두어야 3초 대기 중 disconnect()가 proc을 찾아 kill할 수 있음
      this.processes.set(config.id, proc)

      proc.stderr?.on('data', (chunk: Buffer) => {
        stderr += chunk.toString()
      })

      proc.on('error', (err) => {
        if (!settled) {
          settled = true
          this.processes.delete(config.id)
          reject(err)
        }
      })

      proc.on('exit', (code) => {
        if (!settled) {
          // 3초 이전에 종료 (연결 실패 또는 대기 중 kill)
          settled = true
          this.processes.delete(config.id)
          reject(new Error(stderr.trim() || `SSH exited with code ${code}`))
          return
        }
        // 연결 성공 후 예기치 않게 종료된 경우 — 이미 disconnect()가 호출됐으면 무시
        if (this.processes.has(config.id)) {
          this.processes.delete(config.id)
          const status: TunnelStatus = {
            id: config.id,
            connected: false,
            error: `Process exited (code ${code})`
          }
          this.statuses.set(config.id, status)
          this.emit('statusChanged', status)
        }
      })

      // 3초 후에도 프로세스가 살아 있으면 연결 성공으로 간주
      setTimeout(() => {
        if (settled) return
        // 3초 대기 중 disconnect()가 호출됐으면 processes에서 이미 제거됨
        if (!this.processes.has(config.id)) {
          settled = true
          reject(new Error('Connection was cancelled'))
          return
        }
        settled = true
        const status: TunnelStatus = {
          id: config.id,
          connected: true,
          pid: proc.pid,
          connectedAt: new Date().toISOString()
        }
        this.statuses.set(config.id, status)
        this.emit('statusChanged', status)
        resolve(status)
      }, 3000)
    })
  }

  disconnect(id: string): void {
    const proc = this.processes.get(id)
    if (proc) {
      proc.kill()
      this.processes.delete(id)
    }
    const status: TunnelStatus = { id, connected: false }
    this.statuses.delete(id)
    this.emit('statusChanged', status)
  }

  disconnectAll(): void {
    for (const id of [...this.processes.keys()]) {
      this.disconnect(id)
    }
  }

  cleanup(): void {
    this.stopScanning()
    this.disconnectAll()
  }
}

export const tunnelManager = new TunnelManager()

import { execFile } from 'child_process'
import { promisify } from 'util'
import type { ExternalTunnel } from '../../shared/types/tunnel'

const execFileAsync = promisify(execFile)

interface WmiProcess {
  CommandLine: string | null
  ProcessId: number
}

const PS_COMMAND =
  "Get-CimInstance Win32_Process -Filter \"name='ssh.exe'\" | Select-Object CommandLine, ProcessId | ConvertTo-Json -Compress"

function parseLFlag(cmdLine: string): { localPort: number; remoteHost: string; remotePort: number } | null {
  const match = cmdLine.match(/-L\s*(\d+):([^:\s]+):(\d+)/)
  if (!match) return null
  return {
    localPort: parseInt(match[1], 10),
    remoteHost: match[2],
    remotePort: parseInt(match[3], 10)
  }
}

function parseSSHTarget(cmdLine: string): { sshHost: string; sshUser?: string } {
  const userAtHost = cmdLine.match(/\b([A-Za-z0-9._-]+)@([A-Za-z0-9._-]+)\b/)
  if (userAtHost) return { sshHost: userAtHost[2], sshUser: userAtHost[1] }

  // -l user 형식
  const lFlag = cmdLine.match(/-l\s+([A-Za-z0-9._-]+)/)
  const hostMatch = cmdLine.match(/(?:^|\s)([A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z]{2,})(?:\s|$)/)
  return {
    sshHost: hostMatch ? hostMatch[1] : 'unknown',
    sshUser: lFlag ? lFlag[1] : undefined
  }
}

export async function scanExternalTunnels(appManagedPids: Set<number>): Promise<ExternalTunnel[]> {
  let raw: string
  try {
    const { stdout } = await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', PS_COMMAND],
      { timeout: 5000 }
    )
    raw = stdout.trim()
  } catch {
    return []
  }

  if (!raw || raw === 'null') return []

  let entries: WmiProcess[]
  try {
    const parsed: unknown = JSON.parse(raw)
    entries = Array.isArray(parsed) ? (parsed as WmiProcess[]) : [parsed as WmiProcess]
  } catch {
    return []
  }

  const results: ExternalTunnel[] = []
  for (const entry of entries) {
    if (!entry.CommandLine) continue
    if (appManagedPids.has(entry.ProcessId)) continue

    const lFlag = parseLFlag(entry.CommandLine)
    if (!lFlag) continue

    const { sshHost, sshUser } = parseSSHTarget(entry.CommandLine)
    results.push({
      id: `ext-${entry.ProcessId}`,
      source: 'external',
      pid: entry.ProcessId,
      localPort: lFlag.localPort,
      remoteHost: lFlag.remoteHost,
      remotePort: lFlag.remotePort,
      sshHost,
      sshUser,
      commandLine: entry.CommandLine
    })
  }
  return results
}

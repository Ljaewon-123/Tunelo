export interface ParsedSSHCommand {
  localPort?: number
  remoteHost?: string
  remotePort?: number
  sshHost?: string
  sshPort?: number
  sshUser?: string
  identityFile?: string
  valid: boolean
  errors: string[]
}

// 지원 형식:
//   ssh -L 3306:db-server:3306 user@server.com
//   ssh -L 3306:db-server:3306 -p 2222 user@server.com -i ~/.ssh/id_rsa
//   -L 3306:db:3306 user@server.com
//   ssh -N -f -L 3306:localhost:3306 user@host
export function parseSSHCommand(input: string): ParsedSSHCommand {
  const result: ParsedSSHCommand = { valid: false, errors: [] }
  const trimmed = input.trim()
  if (!trimmed) return result

  let tokens = trimmed.split(/\s+/)

  // 'ssh' 키워드 제거
  if (tokens[0].toLowerCase() === 'ssh') tokens = tokens.slice(1)

  // 무시할 플래그
  const ignoreFlags = new Set(['-N', '-f', '-T', '-v', '-vv', '-vvv', '-q', '-C'])

  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i]

    if (ignoreFlags.has(tok)) continue

    if (tok === '-L' && tokens[i + 1]) {
      const lVal = tokens[++i]
      const parts = lVal.split(':')
      if (parts.length === 3) {
        result.localPort = parseInt(parts[0], 10)
        result.remoteHost = parts[1]
        result.remotePort = parseInt(parts[2], 10)
      }
    } else if (tok.startsWith('-L') && tok.length > 2) {
      // -L3306:host:3306 (공백 없음)
      const parts = tok.slice(2).split(':')
      if (parts.length === 3) {
        result.localPort = parseInt(parts[0], 10)
        result.remoteHost = parts[1]
        result.remotePort = parseInt(parts[2], 10)
      }
    } else if (tok === '-p' && tokens[i + 1]) {
      result.sshPort = parseInt(tokens[++i], 10)
    } else if (tok === '-l' && tokens[i + 1]) {
      result.sshUser = tokens[++i]
    } else if (tok === '-i' && tokens[i + 1]) {
      result.identityFile = tokens[++i]
    } else if (!tok.startsWith('-')) {
      // positional: user@host 또는 bare host
      if (tok.includes('@')) {
        const atIdx = tok.indexOf('@')
        result.sshUser = tok.slice(0, atIdx)
        result.sshHost = tok.slice(atIdx + 1)
      } else if (!result.sshHost) {
        result.sshHost = tok
      }
    }
  }

  // 유효성 검사
  if (!result.localPort) result.errors.push('로컬 포트가 없습니다 (-L localPort:...)')
  if (!result.remoteHost) result.errors.push('원격 호스트가 없습니다 (-L ...:remoteHost:...)')
  if (!result.remotePort) result.errors.push('원격 포트가 없습니다 (-L ...:...:remotePort)')
  if (!result.sshHost) result.errors.push('SSH 호스트가 없습니다 (user@host 또는 bare host)')

  result.valid = result.errors.length === 0
  return result
}

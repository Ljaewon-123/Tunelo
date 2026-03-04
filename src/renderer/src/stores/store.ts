import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { tunnelAPI } from '@renderer/shared/api/ipc'
import type { TunnelConfig, TunnelStatus, TunnelWithStatus, ExternalTunnel } from '@renderer/shared/types/tunnel'

export const useTunnelStore = defineStore('tunnel', () => {
  const configs = ref<TunnelConfig[]>([])
  const statuses = ref<Map<string, TunnelStatus>>(new Map())
  const connecting = ref<Set<string>>(new Set())
  const isLoading = ref(false)
  const externalTunnels = ref<ExternalTunnel[]>([])
  let unsubscribeStatus: (() => void) | null = null
  let unsubscribeExternal: (() => void) | null = null
  let initialized = false

  const tunnelsWithStatus = computed<TunnelWithStatus[]>(() =>
    configs.value.map((c) => ({
      ...c,
      status: statuses.value.get(c.id) ?? { id: c.id, connected: false }
    }))
  )

  const allTunnels = computed<(TunnelWithStatus | ExternalTunnel)[]>(() => [
    ...tunnelsWithStatus.value,
    ...externalTunnels.value
  ])

  const connectedTunnels = computed<(TunnelWithStatus | ExternalTunnel)[]>(() =>
    allTunnels.value.filter((t) => {
      if ('source' in t && t.source === 'external') return true
      return (t as TunnelWithStatus).status.connected
    })
  )

  const recentTunnels = computed(() =>
    [...configs.value]
      .filter((t) => t.lastConnectedAt)
      .sort(
        (a, b) =>
          new Date(b.lastConnectedAt!).getTime() - new Date(a.lastConnectedAt!).getTime()
      )
      .slice(0, 5)
  )

  async function refresh(): Promise<void> {
    const [allConfigs, allStatuses, allExternal] = await Promise.all([
      tunnelAPI.getAll(),
      tunnelAPI.getStatuses(),
      tunnelAPI.getExternal()
    ])
    configs.value = allConfigs
    statuses.value = new Map(allStatuses.map((s) => [s.id, s]))
    externalTunnels.value = allExternal
  }

  async function init(): Promise<void> {
    if (initialized) {
      await refresh()
      return
    }
    isLoading.value = true
    try {
      const [allConfigs, allStatuses, allExternal] = await Promise.all([
        tunnelAPI.getAll(),
        tunnelAPI.getStatuses(),
        tunnelAPI.getExternal()
      ])
      configs.value = allConfigs
      statuses.value = new Map(allStatuses.map((s) => [s.id, s]))
      externalTunnels.value = allExternal

      unsubscribeStatus?.()
      unsubscribeStatus = tunnelAPI.onStatusChanged((status) => {
        statuses.value = new Map([...statuses.value, [status.id, status]])
      })

      unsubscribeExternal?.()
      unsubscribeExternal = tunnelAPI.onExternalUpdated((tunnels) => {
        externalTunnels.value = tunnels
      })

      initialized = true
    } finally {
      isLoading.value = false
    }
  }

  async function addTunnel(
    config: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<TunnelConfig> {
    const newTunnel = await tunnelAPI.add(config)
    configs.value = [...configs.value, newTunnel]
    return newTunnel
  }

  async function updateTunnel(id: string, patch: Partial<TunnelConfig>): Promise<TunnelConfig> {
    const updated = await tunnelAPI.update(id, patch)
    configs.value = configs.value.map((t) => (t.id === id ? updated : t))
    return updated
  }

  async function removeTunnel(id: string): Promise<void> {
    await tunnelAPI.remove(id)
    configs.value = configs.value.filter((t) => t.id !== id)
    const next = new Map(statuses.value)
    next.delete(id)
    statuses.value = next
  }

  async function connectTunnel(id: string): Promise<TunnelStatus> {
    connecting.value = new Set([...connecting.value, id])
    try {
      const status = await tunnelAPI.connect(id)
      statuses.value = new Map([...statuses.value, [id, status]])
      // lastConnectedAt 갱신을 위해 configs 재로드
      configs.value = await tunnelAPI.getAll()
      return status
    } finally {
      const next = new Set(connecting.value)
      next.delete(id)
      connecting.value = next
    }
  }

  async function disconnectTunnel(id: string): Promise<void> {
    await tunnelAPI.disconnect(id)
    statuses.value = new Map([...statuses.value, [id, { id, connected: false }]])
  }

  async function disconnectAll(): Promise<void> {
    await tunnelAPI.disconnectAll()
    const next = new Map<string, TunnelStatus>()
    for (const [id] of statuses.value) {
      next.set(id, { id, connected: false })
    }
    statuses.value = next
  }

  async function killExternalTunnel(pid: number): Promise<void> {
    await tunnelAPI.killExternal(pid)
    externalTunnels.value = externalTunnels.value.filter((t) => t.pid !== pid)
  }

  return {
    configs,
    statuses,
    connecting,
    isLoading,
    externalTunnels,
    tunnelsWithStatus,
    allTunnels,
    connectedTunnels,
    recentTunnels,
    init,
    refresh,
    addTunnel,
    updateTunnel,
    removeTunnel,
    connectTunnel,
    disconnectTunnel,
    disconnectAll,
    killExternalTunnel
  }
})

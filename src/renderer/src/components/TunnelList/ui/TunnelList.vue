<script setup lang="ts">
import { computed } from 'vue'
import { useTunnelStore } from '@renderer/stores/store'
import TunnelCard from '@renderer/components/TunnelCard.vue'
import ListTransition from '@renderer/shared/ui/ListTransition.vue'
import type { TunnelWithStatus, ExternalTunnel } from '@renderer/shared/types/tunnel'

const emit = defineEmits<{
  edit: [id: string]
}>()

const store = useTunnelStore()

const connected = computed(() =>
  store.allTunnels.filter((t) => {
    if ('source' in t && t.source === 'external') return true
    return (t as TunnelWithStatus).status.connected
  })
)

const disconnected = computed(() =>
  store.allTunnels.filter((t) => {
    if ('source' in t && (t as ExternalTunnel).source === 'external') return false
    return !(t as TunnelWithStatus).status.connected
  })
)

async function handleConnect(id: string): Promise<void> {
  try {
    await store.connectTunnel(id)
  } catch (e) {
    console.error('Connect failed:', e)
  }
}

async function handleDelete(id: string): Promise<void> {
  if (!confirm('이 터널을 삭제하시겠습니까?')) return
  await store.removeTunnel(id)
}

async function handleRename(id: string, alias: string): Promise<void> {
  await store.updateTunnel(id, { alias: alias || undefined })
}

async function handleKillExternal(pid: number): Promise<void> {
  if (!confirm('외부 SSH 프로세스를 종료하시겠습니까?')) return
  await store.killExternalTunnel(pid)
}
</script>

<template>
  <div class="space-y-6">
    <!-- 연결된 터널 섹션 -->
    <section v-if="connected.length > 0">
      <h2 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
        연결됨 ({{ connected.length }})
      </h2>
      <ListTransition tag="div" class="space-y-2 relative">
        <TunnelCard
          v-for="tunnel in connected"
          :key="tunnel.id"
          :tunnel="tunnel"
          :is-connecting="store.connecting.has(tunnel.id)"
          @connect="handleConnect"
          @disconnect="store.disconnectTunnel"
          @edit="emit('edit', $event)"
          @delete="handleDelete"
          @rename="handleRename"
          @kill-external="handleKillExternal"
        />
      </ListTransition>
    </section>

    <!-- 연결되지 않은 터널 섹션 -->
    <section v-if="disconnected.length > 0">
      <h2 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
        미연결 ({{ disconnected.length }})
      </h2>
      <ListTransition tag="div" class="space-y-2 relative">
        <TunnelCard
          v-for="tunnel in disconnected"
          :key="tunnel.id"
          :tunnel="tunnel"
          :is-connecting="store.connecting.has(tunnel.id)"
          @connect="handleConnect"
          @disconnect="store.disconnectTunnel"
          @edit="emit('edit', $event)"
          @delete="handleDelete"
          @rename="handleRename"
          @kill-external="handleKillExternal"
        />
      </ListTransition>
    </section>

    <!-- 빈 상태 -->
    <div
      v-if="store.allTunnels.length === 0"
      class="text-center py-16 text-gray-500"
    >
      <p class="text-4xl mb-3">🔌</p>
      <p class="text-sm">활성 터널이 없습니다.</p>
      <p class="text-xs mt-1">아래 입력창에 SSH 명령어를 입력하거나, 외부에서 터널을 연결하세요.</p>
    </div>
  </div>
</template>

<style scoped>
</style>

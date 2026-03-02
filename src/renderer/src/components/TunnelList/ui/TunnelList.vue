<script setup lang="ts">
import { computed } from 'vue'
import { useTunnelStore } from '@renderer/stores/store'
import TunnelCard from '@renderer/entities/tunnel/ui/TunnelCard.vue'

const emit = defineEmits<{
  edit: [id: string]
}>()

const store = useTunnelStore()

const connected = computed(() => store.tunnelsWithStatus.filter((t) => t.status.connected))
const disconnected = computed(() => store.tunnelsWithStatus.filter((t) => !t.status.connected))

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
</script>

<template>
  <div class="space-y-6">
    <!-- 연결된 터널 섹션 -->
    <section v-if="connected.length > 0">
      <h2 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
        연결됨 ({{ connected.length }})
      </h2>
      <div class="space-y-2">
        <TunnelCard
          v-for="tunnel in connected"
          :key="tunnel.id"
          :tunnel="tunnel"
          :is-connecting="store.connecting.has(tunnel.id)"
          @connect="handleConnect"
          @disconnect="store.disconnectTunnel"
          @edit="emit('edit', $event)"
          @delete="handleDelete"
        />
      </div>
    </section>

    <!-- 연결되지 않은 터널 섹션 -->
    <section v-if="disconnected.length > 0">
      <h2 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
        미연결 ({{ disconnected.length }})
      </h2>
      <div class="space-y-2">
        <TunnelCard
          v-for="tunnel in disconnected"
          :key="tunnel.id"
          :tunnel="tunnel"
          :is-connecting="store.connecting.has(tunnel.id)"
          @connect="handleConnect"
          @disconnect="store.disconnectTunnel"
          @edit="emit('edit', $event)"
          @delete="handleDelete"
        />
      </div>
    </section>

    <!-- 빈 상태 -->
    <div
      v-if="store.tunnelsWithStatus.length === 0"
      class="text-center py-16 text-gray-500"
    >
      <p class="text-4xl mb-3">🔌</p>
      <p class="text-sm">등록된 터널이 없습니다.</p>
      <p class="text-xs mt-1">위 "+ 터널 추가" 버튼으로 시작하세요.</p>
    </div>
  </div>
</template>

<style scoped>
</style>

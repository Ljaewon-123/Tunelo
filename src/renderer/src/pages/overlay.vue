<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import AppIcon from '@renderer/shared/ui/AppIcon.vue'
import ListTransition from '@renderer/shared/ui/ListTransition.vue'
import { useTunnelStore } from '@renderer/stores/store'
import { tunnelAPI } from '@renderer/shared/api/ipc'
import type { TunnelWithStatus, ExternalTunnel } from '@renderer/shared/types/tunnel'

const store = useTunnelStore()
const isRefreshing = ref(false)

async function handleRefresh(): Promise<void> {
  if (isRefreshing.value) return
  isRefreshing.value = true
  try {
    await store.refresh()
  } finally {
    isRefreshing.value = false
  }
}

let unsubRefresh: (() => void) | null = null

onMounted(() => {
  store.init()
  unsubRefresh = tunnelAPI.onRefreshRequest(() => store.refresh())
})

onUnmounted(() => {
  unsubRefresh?.()
})

const displayName = (tunnel: TunnelWithStatus | ExternalTunnel): string => {
  if ('source' in tunnel && tunnel.source === 'external') {
    return (tunnel as ExternalTunnel).sshUser
      ? `${(tunnel as ExternalTunnel).sshUser}@${(tunnel as ExternalTunnel).sshHost}:${tunnel.localPort}`
      : `${(tunnel as ExternalTunnel).sshHost}:${tunnel.localPort}`
  }
  const t = tunnel as TunnelWithStatus
  return t.alias || `${t.host}:${t.localPort}`
}

// 동적 높이 계산: 헤더(44) + 터널 항목당 40px + 여백
const targetHeight = computed(() => {
  const itemCount = store.connectedTunnels.length
  const listHeight = itemCount > 0 ? itemCount * 40 + 8 : 36
  return 44 + listHeight + 8
})

watch(
  targetHeight,
  (h) => tunnelAPI.setOverlayHeight(h),
  { immediate: true }
)

function openMainWindow(): void {
  tunnelAPI.openMainWindow()
}
</script>

<template>
  <div class="flex flex-col bg-gray-900/80 backdrop-blur-md text-white select-none overflow-hidden">
    <!-- 헤더 (드래그 핸들) -->
    <div
      class="drag-handle flex items-center justify-between px-3 h-11 shrink-0 border-b border-gray-700/50"
    >
      <div class="flex items-center gap-2 no-drag">
        <span class="size-2 rounded-full bg-blue-500" />
        <span class="text-xs font-semibold text-gray-300">Tunelo</span>
        <span
          v-if="store.connectedTunnels.length > 0"
          class="text-xs bg-green-700 text-green-200 px-1.5 py-0.5 rounded-full"
        >
          {{ store.connectedTunnels.length }}
        </span>
      </div>

      <div class="flex items-center gap-1 no-drag">
        <!-- 새로고침 -->
        <button
          class="p-1 text-gray-400 hover:text-white hover:animate-spin rounded transition-colors"
          :class="{ 'animate-spin': isRefreshing }"
          title="새로고침"
          @click="handleRefresh"
        >
          <AppIcon name="refresh" class="size-3" />
        </button>
        <!-- 메인 창 열기 -->
        <div class="relative group">
          <button
            class="p-1 text-gray-400 hover:text-white rounded transition-colors"
            @click="openMainWindow"
          >
            <AppIcon name="expand" class="size-3" />
          </button>
          <span class="pointer-events-none absolute right-0 top-full mt-1.5 whitespace-nowrap rounded bg-gray-800 px-2 py-1 text-xs text-gray-200 opacity-0 transition-opacity group-hover:opacity-100">
            메인 창 열기
          </span>
        </div>
      </div>
    </div>

    <!-- 터널 목록 -->
    <div class="px-3 py-1.5 bg-white/5">
      <!-- 연결된 터널 -->
      <ListTransition v-if="store.connectedTunnels.length > 0" tag="div" class="space-y-1 relative">
        <div
          v-for="tunnel in store.connectedTunnels"
          :key="tunnel.id"
          class="flex items-center gap-2 py-1"
        >
          <span class="size-1.5 rounded-full bg-green-400 shrink-0" />
          <span class="text-xs text-gray-200 truncate">
            {{ displayName(tunnel) }}
          </span>
          <span class="ml-auto text-xs text-gray-500 shrink-0">
            :{{ tunnel.localPort }}
          </span>
        </div>
      </ListTransition>

      <!-- 연결 없음 -->
      <div v-else class="py-1.5 text-xs text-gray-500 text-center">
        활성 터널 없음
      </div>
    </div>
  </div>
</template>

<style scoped>
.drag-handle {
  -webkit-app-region: drag;
  cursor: move;
}

.no-drag {
  -webkit-app-region: no-drag;
}
</style>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useTunnelStore } from '@renderer/entities/tunnel/model/store'
import { tunnelAPI } from '@renderer/shared/api/ipc'

const store = useTunnelStore()
const isCollapsed = ref(false)

onMounted(() => store.init())

const displayName = (alias?: string, host?: string, localPort?: number): string =>
  alias || `${host}:${localPort}`

// 동적 높이 계산: 헤더(44) + 터널 항목당 40px + 여백
const targetHeight = computed(() => {
  if (isCollapsed.value) return 44
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
  <div class="h-full flex flex-col bg-gray-900 text-white select-none overflow-hidden">
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
        <!-- 펼치기/접기 -->
        <button
          class="p-1 text-gray-400 hover:text-white rounded transition-colors text-xs"
          :title="isCollapsed ? '펼치기' : '접기'"
          @click="isCollapsed = !isCollapsed"
        >
          {{ isCollapsed ? '▼' : '▲' }}
        </button>
        <!-- 메인 창 열기 -->
        <button
          class="p-1 text-gray-400 hover:text-white rounded transition-colors text-xs"
          title="메인 창 열기"
          @click="openMainWindow"
        >
          ⊞
        </button>
      </div>
    </div>

    <!-- 터널 목록 -->
    <div v-if="!isCollapsed" class="flex-1 overflow-y-auto px-3 py-1.5">
      <!-- 연결된 터널 -->
      <div v-if="store.connectedTunnels.length > 0" class="space-y-1">
        <div
          v-for="tunnel in store.connectedTunnels"
          :key="tunnel.id"
          class="flex items-center gap-2 py-1"
        >
          <span class="size-1.5 rounded-full bg-green-400 shrink-0" />
          <span class="text-xs text-gray-200 truncate">
            {{ displayName(tunnel.alias, tunnel.host, tunnel.localPort) }}
          </span>
          <span class="ml-auto text-xs text-gray-500 shrink-0">
            :{{ tunnel.localPort }}
          </span>
        </div>
      </div>

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

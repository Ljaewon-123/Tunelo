<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTunnelStore } from '@renderer/stores/store'
import { tunnelAPI } from '@renderer/shared/api/ipc'
import TunnelList from '@renderer/components/TunnelList/ui/TunnelList.vue'
import TunnelForm from '@renderer/components/TunnelForm/ui/TunnelForm.vue'
import TunnelCLI from '@renderer/components/TunnelCLI/ui/TunnelCLI.vue'
import AppIcon from '@renderer/shared/ui/AppIcon.vue'

const router = useRouter()
const store = useTunnelStore()

const editingId = ref<string | null>(null)
const showEditForm = ref(false)
const isRefreshing = ref(false)

// 최근 연결했지만 현재 미연결 상태인 터널 (최대 3개)
const recentDisconnected = computed(() =>
  store.recentTunnels
    .filter((t) => !store.statuses.get(t.id)?.connected)
    .slice(0, 3)
)

async function quickConnect(id: string): Promise<void> {
  try {
    await store.connectTunnel(id)
  } catch {
    // 에러는 TunnelCard에서 표시
  }
}

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

function openEditForm(id: string): void {
  editingId.value = id
  showEditForm.value = true
}

function closeForm(): void {
  showEditForm.value = false
  editingId.value = null
}

async function handleDisconnectAll(): Promise<void> {
  if (!store.connectedTunnels.length) return
  await store.disconnectAll()
}
</script>

<template>
  <div class="h-full flex flex-col bg-gray-900 text-white">
    <!-- 헤더 -->
    <header class="flex items-center justify-between px-5 py-3.5 border-b border-gray-700 shrink-0">
      <div class="flex items-center gap-2">
        <span class="size-2.5 rounded-full bg-blue-500" />
        <h1 class="text-base font-bold tracking-tight">Tunelo</h1>
      </div>
      <div class="flex items-center gap-2">
        <!-- 새로고침 -->
        <button
          class="p-1.5 text-gray-400 hover:text-white hover:animate-spin rounded transition-colors"
          :class="{ 'animate-spin': isRefreshing }"
          title="새로고침"
          @click="handleRefresh"
        >
          <AppIcon name="refresh" class="size-4" />
        </button>
        <!-- 오버레이 모드로 전환 -->
        <div class="relative group">
          <button
            class="p-1.5 text-gray-400 hover:text-white rounded transition-colors"
            @click="tunnelAPI.showOverlay()"
          >
            <AppIcon name="overlay" class="size-4" />
          </button>
          <span class="pointer-events-none absolute right-0 top-full mt-1.5 whitespace-nowrap rounded bg-gray-800 px-2 py-1 text-xs text-gray-200 opacity-0 transition-opacity group-hover:opacity-100">
            오버레이로 전환
          </span>
        </div>
        <button
          class="text-sm text-gray-400 hover:text-white transition-colors"
          @click="router.push('/settings')"
        >
          설정 ⚙
        </button>
      </div>
    </header>

    <!-- 툴바 -->
    <div class="flex items-center gap-2 px-5 py-3 border-b border-gray-700/50 shrink-0">
      <button
        :disabled="store.connectedTunnels.length === 0"
        class="px-3 py-1.5 text-sm rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed text-white transition-colors"
        @click="handleDisconnectAll"
      >
        전체 끊기
      </button>
      <span class="ml-auto text-xs text-gray-500">
        {{ store.connectedTunnels.length }} / {{ store.allTunnels.length }} 연결됨
      </span>
    </div>

    <!-- 터널 목록 -->
    <main class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
      <!-- 로딩 -->
      <div v-if="store.isLoading" class="flex items-center justify-center py-16 text-gray-500">
        <span class="text-sm">불러오는 중…</span>
      </div>
      <template v-else>
        <!-- CLI 입력 -->
        <TunnelCLI />

        <!-- 최근 연결 터널 (미연결 상태인 것만) -->
        <div v-if="recentDisconnected.length > 0">
          <p class="text-xs text-gray-500 mb-2">최근 연결</p>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="t in recentDisconnected"
              :key="t.id"
              :disabled="store.connecting.has(t.id)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-full bg-gray-800 border border-gray-700 hover:border-gray-500 hover:text-white text-gray-300 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              @click="quickConnect(t.id)"
            >
              <span
                class="size-1.5 rounded-full shrink-0"
                :class="store.connecting.has(t.id) ? 'bg-yellow-400 animate-pulse' : 'bg-gray-600'"
              />
              {{ t.alias || `${t.host}:${t.localPort}` }}
            </button>
          </div>
        </div>

        <!-- 터널 목록 -->
        <TunnelList @edit="openEditForm" />
      </template>
    </main>

    <!-- 터널 수정 모달 -->
    <TunnelForm
      v-if="showEditForm"
      :tunnel-id="editingId"
      @close="closeForm"
    />
  </div>
</template>

<style scoped>
</style>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTunnelStore } from '@renderer/stores/store'
import { tunnelAPI } from '@renderer/shared/api/ipc'
import TunnelList from '@renderer/components/TunnelList/ui/TunnelList.vue'
import TunnelForm from '@renderer/components/TunnelForm/ui/TunnelForm.vue'
import TunnelCLI from '@renderer/components/TunnelCLI/ui/TunnelCLI.vue'

const router = useRouter()
const store = useTunnelStore()

const editingId = ref<string | null>(null)
const showEditForm = ref(false)
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
          class="p-1.5 text-gray-400 hover:text-white rounded transition-colors"
          :class="{ 'animate-spin': isRefreshing }"
          title="새로고침"
          @click="handleRefresh"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>
            <path d="M21 3v5h-5"/>
            <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/>
            <path d="M8 16H3v5"/>
          </svg>
        </button>
        <!-- 오버레이 모드로 전환 -->
        <button
          class="px-2.5 py-1 text-xs rounded-md text-gray-400 hover:text-white hover:bg-gray-700 transition-colors"
          title="오버레이로 전환"
          @click="tunnelAPI.showOverlay()"
        >
          오버레이 ▢
        </button>
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

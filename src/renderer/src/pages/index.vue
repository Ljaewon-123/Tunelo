<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTunnelStore } from '@renderer/entities/tunnel/model/store'
import { tunnelAPI } from '@renderer/shared/api/ipc'
import TunnelList from '@renderer/widgets/TunnelList/ui/TunnelList.vue'
import TunnelForm from '@renderer/widgets/TunnelForm/ui/TunnelForm.vue'

const router = useRouter()
const store = useTunnelStore()

const showForm = ref(false)
const editingId = ref<string | null>(null)

onMounted(() => store.init())

function openAddForm(): void {
  editingId.value = null
  showForm.value = true
}

function openEditForm(id: string): void {
  editingId.value = id
  showForm.value = true
}

function closeForm(): void {
  showForm.value = false
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
        class="px-3 py-1.5 text-sm rounded-lg bg-blue-600 hover:bg-blue-700 text-white font-medium transition-colors"
        @click="openAddForm"
      >
        + 터널 추가
      </button>
      <button
        :disabled="store.connectedTunnels.length === 0"
        class="px-3 py-1.5 text-sm rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed text-white transition-colors"
        @click="handleDisconnectAll"
      >
        전체 끊기
      </button>
      <span class="ml-auto text-xs text-gray-500">
        {{ store.connectedTunnels.length }} / {{ store.tunnelsWithStatus.length }} 연결됨
      </span>
    </div>

    <!-- 터널 목록 -->
    <main class="flex-1 overflow-y-auto px-5 py-4">
      <!-- 로딩 -->
      <div v-if="store.isLoading" class="flex items-center justify-center py-16 text-gray-500">
        <span class="text-sm">불러오는 중…</span>
      </div>
      <TunnelList v-else @edit="openEditForm" />
    </main>

    <!-- 터널 추가/수정 모달 -->
    <TunnelForm
      v-if="showForm"
      :tunnel-id="editingId"
      @close="closeForm"
    />
  </div>
</template>

<style scoped>
</style>

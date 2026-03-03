<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useTunnelStore } from '@renderer/stores/store'
import { parseSSHCommand } from '@renderer/shared/lib/sshParser'

const store = useTunnelStore()

const commandText = ref('')
const aliasText = ref('')
const isConnecting = ref(false)
const actionError = ref('')

let debounceTimer: ReturnType<typeof setTimeout> | null = null
const parsed = ref(parseSSHCommand(''))

watch(commandText, (val) => {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    parsed.value = parseSSHCommand(val)
  }, 200)
})

const showPreview = computed(() => commandText.value.trim().length > 0)

function reset(): void {
  commandText.value = ''
  aliasText.value = ''
  actionError.value = ''
  parsed.value = parseSSHCommand('')
}

async function handleConnect(): Promise<void> {
  if (!parsed.value.valid || isConnecting.value) return
  isConnecting.value = true
  actionError.value = ''
  try {
    const tunnel = await store.addTunnel({
      alias: aliasText.value.trim() || undefined,
      host: parsed.value.sshHost!,
      port: parsed.value.sshPort ?? 22,
      username: parsed.value.sshUser,
      identityFile: parsed.value.identityFile,
      localPort: parsed.value.localPort!,
      remoteHost: parsed.value.remoteHost!,
      remotePort: parsed.value.remotePort!,
      useBackground: false
    })
    await store.connectTunnel(tunnel.id)
    reset()
  } catch (e) {
    actionError.value = e instanceof Error ? e.message : '연결 실패'
  } finally {
    isConnecting.value = false
  }
}

async function handleSaveOnly(): Promise<void> {
  if (!parsed.value.valid || isConnecting.value) return
  isConnecting.value = true
  actionError.value = ''
  try {
    await store.addTunnel({
      alias: aliasText.value.trim() || undefined,
      host: parsed.value.sshHost!,
      port: parsed.value.sshPort ?? 22,
      username: parsed.value.sshUser,
      identityFile: parsed.value.identityFile,
      localPort: parsed.value.localPort!,
      remoteHost: parsed.value.remoteHost!,
      remotePort: parsed.value.remotePort!,
      useBackground: false
    })
    reset()
  } catch (e) {
    actionError.value = e instanceof Error ? e.message : '저장 실패'
  } finally {
    isConnecting.value = false
  }
}

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && parsed.value.valid && !isConnecting.value) {
    handleConnect()
  }
}
</script>

<template>
  <div class="rounded-lg border border-gray-700 bg-gray-850 overflow-hidden" style="background-color: #0d1117">
    <!-- 입력 줄 -->
    <div class="flex items-center gap-2 px-3 py-2.5 border-b border-gray-700/60">
      <span class="text-green-400 font-mono text-sm shrink-0 select-none">›</span>
      <input
        v-model="commandText"
        type="text"
        class="flex-1 bg-transparent font-mono text-sm text-gray-100 placeholder-gray-600 outline-none"
        placeholder="ssh -L 3306:db-server:3306 user@server.com"
        :disabled="isConnecting"
        spellcheck="false"
        autocomplete="off"
        @keydown="handleKeydown"
      />
      <div class="flex items-center gap-1.5 shrink-0">
        <button
          :disabled="!parsed.valid || isConnecting"
          class="px-3 py-1 text-xs rounded bg-blue-600 hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed text-white transition-colors font-medium"
          @click="handleConnect"
        >
          {{ isConnecting ? '연결 중…' : '연결' }}
        </button>
        <button
          :disabled="!parsed.valid || isConnecting"
          class="px-3 py-1 text-xs rounded bg-gray-700 hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed text-gray-300 transition-colors"
          @click="handleSaveOnly"
        >
          저장만
        </button>
        <button
          v-if="commandText.trim()"
          class="px-2 py-1 text-xs rounded text-gray-500 hover:text-gray-300 hover:bg-gray-700 transition-colors"
          title="초기화"
          @click="reset"
        >
          ✕
        </button>
      </div>
    </div>

    <!-- 파싱 결과 프리뷰 -->
    <div v-if="showPreview" class="px-3 py-2 text-xs font-mono">
      <!-- 유효한 경우 -->
      <div v-if="parsed.valid" class="space-y-1.5">
        <div class="flex items-center gap-3 text-gray-300">
          <span class="text-green-400">✓</span>
          <span>
            <span class="text-blue-300">localhost:{{ parsed.localPort }}</span>
            <span class="text-gray-500"> → </span>
            <span class="text-yellow-300">{{ parsed.remoteHost }}:{{ parsed.remotePort }}</span>
            <span class="text-gray-500"> via </span>
            <span class="text-green-300">
              {{ parsed.sshUser ? `${parsed.sshUser}@` : '' }}{{ parsed.sshHost }}{{ parsed.sshPort && parsed.sshPort !== 22 ? `:${parsed.sshPort}` : '' }}
            </span>
            <span v-if="parsed.identityFile" class="text-gray-500"> ({{ parsed.identityFile }})</span>
          </span>
        </div>
        <div class="flex items-center gap-2">
          <span class="text-gray-600">별칭:</span>
          <input
            v-model="aliasText"
            type="text"
            class="bg-transparent text-gray-300 placeholder-gray-600 outline-none border-b border-gray-700 focus:border-gray-500 transition-colors w-48"
            placeholder="선택 입력"
          />
        </div>
      </div>

      <!-- 에러 (입력이 있을 때만 표시) -->
      <div v-else class="space-y-0.5">
        <div v-for="err in parsed.errors" :key="err" class="flex items-center gap-2 text-red-400">
          <span>✗</span>
          <span>{{ err }}</span>
        </div>
      </div>
    </div>

    <!-- 액션 에러 -->
    <div v-if="actionError" class="px-3 py-1.5 text-xs text-red-400 bg-red-950/30 border-t border-red-900/30">
      {{ actionError }}
      <span class="ml-1 text-red-600 text-xs">SSH 키 또는 ssh-agent를 사용하세요 (비밀번호 인증 미지원)</span>
    </div>
  </div>
</template>

<style scoped>
</style>

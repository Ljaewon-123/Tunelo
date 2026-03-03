<script setup lang="ts">
import type { TunnelWithStatus, ExternalTunnel } from '@renderer/shared/types/tunnel'

type Tunnel = TunnelWithStatus | ExternalTunnel

const props = defineProps<{
  tunnel: Tunnel
  isConnecting: boolean
}>()

const emit = defineEmits<{
  connect: [id: string]
  disconnect: [id: string]
  edit: [id: string]
  delete: [id: string]
}>()

const isExternal = (t: Tunnel): t is ExternalTunnel =>
  'source' in t && t.source === 'external'

const displayName = (t: Tunnel): string => {
  if (isExternal(t)) return t.sshUser ? `${t.sshUser}@${t.sshHost}` : t.sshHost
  return t.alias || `${t.host}:${t.localPort}`
}

const portMapping = (t: Tunnel): string =>
  `localhost:${t.localPort} → ${t.remoteHost}:${t.remotePort}`

const connectedSince = (iso?: string): string => {
  if (!iso) return ''
  return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })
}

const lastConnected = (iso?: string): string => {
  if (!iso) return ''
  const d = new Date(iso)
  const now = new Date()
  const diffMs = now.getTime() - d.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin < 1) return '방금 전'
  if (diffMin < 60) return `${diffMin}분 전`
  const diffH = Math.floor(diffMin / 60)
  if (diffH < 24) return `${diffH}시간 전`
  return `${Math.floor(diffH / 24)}일 전`
}
</script>

<template>
  <div
    class="bg-gray-800 rounded-lg p-4 border transition-colors"
    :class="
      isExternal(props.tunnel)
        ? 'border-blue-700'
        : (props.tunnel as TunnelWithStatus).status.connected
          ? 'border-green-700'
          : 'border-gray-700'
    "
  >
    <!-- 상단: 이름 + 상태 + 버튼 -->
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2 min-w-0">
        <!-- 상태 인디케이터 -->
        <span
          class="shrink-0 size-2.5 rounded-full"
          :class="
            isExternal(props.tunnel)
              ? 'bg-green-400'
              : props.isConnecting
                ? 'bg-yellow-400 animate-pulse'
                : (props.tunnel as TunnelWithStatus).status.connected
                  ? 'bg-green-400'
                  : 'bg-gray-600'
          "
        />
        <span class="font-medium text-white truncate">{{ displayName(props.tunnel) }}</span>

        <!-- 외부 터널 배지 -->
        <span
          v-if="isExternal(props.tunnel)"
          class="text-xs bg-blue-900 text-blue-300 px-1.5 py-0.5 rounded-full shrink-0"
          title="이 앱 외부에서 연결된 터널입니다"
        >
          외부 PID {{ (props.tunnel as ExternalTunnel).pid }}
        </span>

        <!-- 앱 터널 PID -->
        <span
          v-else-if="(props.tunnel as TunnelWithStatus).status.pid"
          class="text-xs text-gray-500"
        >
          PID {{ (props.tunnel as TunnelWithStatus).status.pid }}
        </span>
      </div>

      <!-- 액션 버튼 (앱 터널만) -->
      <div v-if="!isExternal(props.tunnel)" class="flex items-center gap-1.5 shrink-0">
        <button
          v-if="!(props.tunnel as TunnelWithStatus).status.connected"
          :disabled="props.isConnecting"
          class="px-3 py-1 text-sm rounded bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white transition-colors"
          @click="emit('connect', props.tunnel.id)"
        >
          {{ props.isConnecting ? '연결 중…' : '연결' }}
        </button>
        <button
          v-else
          class="px-3 py-1 text-sm rounded bg-gray-700 hover:bg-gray-600 text-white transition-colors"
          @click="emit('disconnect', props.tunnel.id)"
        >
          끊기
        </button>

        <button
          class="px-2 py-1 text-sm rounded text-gray-400 hover:text-white hover:bg-gray-700 transition-colors"
          title="수정"
          @click="emit('edit', props.tunnel.id)"
        >
          ✎
        </button>
        <button
          class="px-2 py-1 text-sm rounded text-gray-400 hover:text-red-400 hover:bg-gray-700 transition-colors"
          title="삭제"
          @click="emit('delete', props.tunnel.id)"
        >
          ✕
        </button>
      </div>
    </div>

    <!-- 하단: 포트 매핑 + 연결 정보 -->
    <div class="mt-2 flex items-center justify-between text-xs text-gray-400">
      <span>{{ portMapping(props.tunnel) }}</span>
      <span v-if="isExternal(props.tunnel)">외부 프로세스 연결됨</span>
      <span
        v-else-if="(props.tunnel as TunnelWithStatus).status.connected && (props.tunnel as TunnelWithStatus).status.connectedAt"
      >
        {{ connectedSince((props.tunnel as TunnelWithStatus).status.connectedAt) }} 부터 연결됨
      </span>
      <span v-else-if="(props.tunnel as TunnelWithStatus).lastConnectedAt">
        {{ lastConnected((props.tunnel as TunnelWithStatus).lastConnectedAt) }}에 마지막 연결
      </span>
    </div>

    <!-- 에러 메시지 (앱 터널만) -->
    <p
      v-if="!isExternal(props.tunnel) && (props.tunnel as TunnelWithStatus).status.error"
      class="mt-1.5 text-xs text-red-400"
    >
      {{ (props.tunnel as TunnelWithStatus).status.error }}
    </p>
  </div>
</template>

<style scoped>
</style>

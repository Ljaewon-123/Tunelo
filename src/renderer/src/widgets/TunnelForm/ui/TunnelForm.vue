<script setup lang="ts">
import { reactive, watch } from 'vue'
import { useTunnelStore } from '@renderer/entities/tunnel/model/store'
import type { TunnelConfig } from '@renderer/shared/types/tunnel'

const props = defineProps<{
  tunnelId?: string | null
}>()

const emit = defineEmits<{
  close: []
}>()

const store = useTunnelStore()

interface FormState {
  alias: string
  host: string
  port: number
  username: string
  identityFile: string
  localPort: number
  remoteHost: string
  remotePort: number
  useBackground: boolean
}

const defaultForm = (): FormState => ({
  alias: '',
  host: '',
  port: 22,
  username: '',
  identityFile: '',
  localPort: 0,
  remoteHost: '',
  remotePort: 0,
  useBackground: false
})

const form = reactive<FormState>(defaultForm())
const errors = reactive<Partial<Record<keyof FormState, string>>>({})

// 수정 모드면 기존 값으로 채우기
watch(
  () => props.tunnelId,
  (id) => {
    if (id) {
      const tunnel = store.configs.find((t) => t.id === id)
      if (tunnel) {
        form.alias = tunnel.alias ?? ''
        form.host = tunnel.host
        form.port = tunnel.port
        form.username = tunnel.username ?? ''
        form.identityFile = tunnel.identityFile ?? ''
        form.localPort = tunnel.localPort
        form.remoteHost = tunnel.remoteHost
        form.remotePort = tunnel.remotePort
        form.useBackground = tunnel.useBackground
      }
    } else {
      Object.assign(form, defaultForm())
    }
  },
  { immediate: true }
)

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k as keyof FormState])

  if (!form.host.trim()) errors.host = '호스트를 입력하세요.'
  if (!form.port || form.port < 1 || form.port > 65535)
    errors.port = '포트는 1~65535 사이여야 합니다.'
  if (!form.localPort || form.localPort < 1 || form.localPort > 65535)
    errors.localPort = '로컬 포트는 1~65535 사이여야 합니다.'
  if (!form.remoteHost.trim()) errors.remoteHost = '원격 호스트를 입력하세요.'
  if (!form.remotePort || form.remotePort < 1 || form.remotePort > 65535)
    errors.remotePort = '원격 포트는 1~65535 사이여야 합니다.'

  return Object.keys(errors).length === 0
}

async function handleSubmit(): Promise<void> {
  if (!validate()) return

  const payload: Omit<TunnelConfig, 'id' | 'createdAt' | 'updatedAt'> = {
    alias: form.alias.trim() || undefined,
    host: form.host.trim(),
    port: Number(form.port),
    username: form.username.trim() || undefined,
    identityFile: form.identityFile.trim() || undefined,
    localPort: Number(form.localPort),
    remoteHost: form.remoteHost.trim(),
    remotePort: Number(form.remotePort),
    useBackground: form.useBackground
  }

  if (props.tunnelId) {
    await store.updateTunnel(props.tunnelId, payload)
  } else {
    await store.addTunnel(payload)
  }

  emit('close')
}
</script>

<template>
  <!-- 모달 배경 -->
  <div
    class="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
    @click.self="emit('close')"
  >
    <div class="bg-gray-800 rounded-xl w-full max-w-lg mx-4 p-6 shadow-2xl">
      <!-- 헤더 -->
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-lg font-semibold text-white">
          {{ props.tunnelId ? '터널 수정' : '터널 추가' }}
        </h2>
        <button
          class="text-gray-400 hover:text-white transition-colors text-xl leading-none"
          @click="emit('close')"
        >
          ✕
        </button>
      </div>

      <!-- 폼 -->
      <form class="space-y-4" @submit.prevent="handleSubmit">
        <!-- 별칭 -->
        <div>
          <label class="block text-sm text-gray-400 mb-1">별칭 (선택)</label>
          <input
            v-model="form.alias"
            type="text"
            placeholder="예: 개발서버"
            class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500"
          />
        </div>

        <!-- SSH 서버 -->
        <div class="grid grid-cols-3 gap-3">
          <div class="col-span-2">
            <label class="block text-sm text-gray-400 mb-1">SSH 호스트 *</label>
            <input
              v-model="form.host"
              type="text"
              placeholder="192.168.1.100"
              class="w-full bg-gray-900 border rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500 transition-colors"
              :class="errors.host ? 'border-red-500' : 'border-gray-700'"
            />
            <p v-if="errors.host" class="mt-1 text-xs text-red-400">{{ errors.host }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-400 mb-1">SSH 포트 *</label>
            <input
              v-model.number="form.port"
              type="number"
              min="1"
              max="65535"
              class="w-full bg-gray-900 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-blue-500 transition-colors"
              :class="errors.port ? 'border-red-500' : 'border-gray-700'"
            />
            <p v-if="errors.port" class="mt-1 text-xs text-red-400">{{ errors.port }}</p>
          </div>
        </div>

        <!-- 인증 -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-sm text-gray-400 mb-1">사용자명 (선택)</label>
            <input
              v-model="form.username"
              type="text"
              placeholder="ubuntu"
              class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm text-gray-400 mb-1">SSH 키 경로 (선택)</label>
            <input
              v-model="form.identityFile"
              type="text"
              placeholder="C:\Users\me\.ssh\id_rsa"
              class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500"
            />
          </div>
        </div>

        <!-- 포트 포워딩 -->
        <div class="grid grid-cols-3 gap-3">
          <div>
            <label class="block text-sm text-gray-400 mb-1">로컬 포트 *</label>
            <input
              v-model.number="form.localPort"
              type="number"
              min="1"
              max="65535"
              placeholder="8080"
              class="w-full bg-gray-900 border rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500 transition-colors"
              :class="errors.localPort ? 'border-red-500' : 'border-gray-700'"
            />
            <p v-if="errors.localPort" class="mt-1 text-xs text-red-400">{{ errors.localPort }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-400 mb-1">원격 호스트 *</label>
            <input
              v-model="form.remoteHost"
              type="text"
              placeholder="localhost"
              class="w-full bg-gray-900 border rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500 transition-colors"
              :class="errors.remoteHost ? 'border-red-500' : 'border-gray-700'"
            />
            <p v-if="errors.remoteHost" class="mt-1 text-xs text-red-400">{{ errors.remoteHost }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-400 mb-1">원격 포트 *</label>
            <input
              v-model.number="form.remotePort"
              type="number"
              min="1"
              max="65535"
              placeholder="5432"
              class="w-full bg-gray-900 border rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-blue-500 transition-colors"
              :class="errors.remotePort ? 'border-red-500' : 'border-gray-700'"
            />
            <p v-if="errors.remotePort" class="mt-1 text-xs text-red-400">{{ errors.remotePort }}</p>
          </div>
        </div>

        <!-- 버튼 -->
        <div class="flex justify-end gap-3 pt-2">
          <button
            type="button"
            class="px-4 py-2 text-sm rounded-lg text-gray-400 hover:text-white hover:bg-gray-700 transition-colors"
            @click="emit('close')"
          >
            취소
          </button>
          <button
            type="submit"
            class="px-4 py-2 text-sm rounded-lg bg-blue-600 hover:bg-blue-700 text-white font-medium transition-colors"
          >
            {{ props.tunnelId ? '저장' : '추가' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
</style>

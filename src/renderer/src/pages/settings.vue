<script setup lang="ts">
import { useRouter } from 'vue-router'

const router = useRouter()
</script>

<template>
  <div class="h-full flex flex-col bg-gray-900 text-white">
    <!-- 헤더 -->
    <header class="flex items-center gap-3 px-5 py-3.5 border-b border-gray-700 shrink-0">
      <button
        class="text-gray-400 hover:text-white transition-colors text-lg leading-none"
        @click="router.push('/')"
      >
        ←
      </button>
      <h1 class="text-base font-bold">설정</h1>
    </header>

    <!-- 앱 동작 안내 -->
    <main class="flex-1 px-5 py-4 space-y-2">
      <div class="bg-gray-800 rounded-lg p-4 space-y-2 text-sm text-gray-400">
        <p class="font-medium text-white">앱 동작 방식</p>
        <ul class="space-y-1.5 text-xs leading-relaxed">
          <li>• 메인 창 <span class="text-gray-300">닫기(✕)</span> → 앱 완전 종료 및 모든 터널 해제</li>
          <li>• 메인 창 <span class="text-gray-300">오버레이 ▢</span> → 오버레이 위젯으로 전환</li>
          <li>• 오버레이 <span class="text-gray-300">⊞</span> → 메인 창으로 복귀</li>
          <li>• 트레이 아이콘 더블클릭 → 메인 창 열기</li>
        </ul>
      </div>
    </main>
  </div>
</template>

<style scoped>
</style>

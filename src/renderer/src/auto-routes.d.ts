import type { RouteRecordRaw } from 'vue-router'

// unplugin-vue-router virtual module에 routes export 타입 추가
declare module 'vue-router/auto-routes' {
  export const routes: RouteRecordRaw[]
}

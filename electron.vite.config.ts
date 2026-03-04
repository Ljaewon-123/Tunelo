import { resolve } from 'path'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import vue from '@vitejs/plugin-vue'
import VueRouter from 'unplugin-vue-router/vite'
import tailwindcss from '@tailwindcss/vite'
import VueDevTools from 'vite-plugin-vue-devtools'

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()]
  },
  preload: {
    plugins: [externalizeDepsPlugin()]
  },
  renderer: {
    resolve: {
      alias: {
        '@renderer': resolve('src/renderer/src')
      }
    },
    plugins: [
      VueRouter({
        routesFolder: 'src/renderer/src/pages',
        dts: 'src/renderer/src/typed-router.d.ts'
      }),
      vue(),
      tailwindcss(),
      VueDevTools()
    ]
  }
})

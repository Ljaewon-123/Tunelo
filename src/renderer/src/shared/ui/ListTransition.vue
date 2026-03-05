<script setup lang="ts">
defineProps<{ tag?: string }>()
</script>

<template>
  <TransitionGroup
    :tag="tag ?? 'div'"
    name="tunnel-list"
    v-bind="$attrs"
  >
    <slot />
  </TransitionGroup>
</template>

<style>
.tunnel-list-move,
.tunnel-list-enter-active,
.tunnel-list-leave-active {
  transition: all 0.25s ease;
}

.tunnel-list-enter-from,
.tunnel-list-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

.tunnel-list-leave-active {
  position: absolute;
  width: 100%;
}
</style>

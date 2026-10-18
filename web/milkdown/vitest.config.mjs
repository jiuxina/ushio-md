import { defineConfig } from 'vite';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/__tests__/**/*.test.mjs'],
  },
});

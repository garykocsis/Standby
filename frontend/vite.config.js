import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The frontend reads its ABIs from the Foundry build output in `../out`, so the interface it calls can
// never drift from the deployed bytecode. That directory is outside the Vite root, so the dev server is
// told it may serve from the repository root.
export default defineConfig({
  plugins: [react()],
  server: {
    fs: { allow: ['..'] },
  },
})

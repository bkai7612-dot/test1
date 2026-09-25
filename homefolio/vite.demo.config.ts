import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

/**
 * Clickable prototype: the real app with an in-browser mock backend
 * (src/demo/supabase.ts), bundled into one self-contained HTML file.
 */
export default defineConfig({
  plugins: [react(), tailwindcss(), viteSingleFile()],
  define: { 'import.meta.env.VITE_DEMO': JSON.stringify('1') },
  resolve: {
    alias: [
      { find: /^@\/lib\/supabase$/, replacement: fileURLToPath(new URL('./src/demo/supabase.ts', import.meta.url)) },
      { find: '@', replacement: fileURLToPath(new URL('./src', import.meta.url)) },
    ],
  },
  build: { outDir: 'dist-demo', emptyOutDir: true },
});

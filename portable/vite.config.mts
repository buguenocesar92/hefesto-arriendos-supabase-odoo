import {defineConfig} from 'vite';
import {resolve} from 'node:path';
export default defineConfig({root:resolve(import.meta.dirname,'frontend'),build:{outDir:resolve(import.meta.dirname,'dist'),emptyOutDir:true},esbuild:{jsx:'automatic'}});

const esbuild = require('esbuild');
const path = require('path');
const fs = require('fs');

// Criar diretório de saída
const outDir = path.join(__dirname, '../dist-electron');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Criar diretório electron se não existir
const electronDir = path.join(__dirname, '../electron');
if (!fs.existsSync(electronDir)) {
  fs.mkdirSync(electronDir, { recursive: true });
}

// Copiar renderer.html para dist-electron/electron (para electron-builder)
const electronDirInDist = path.join(outDir, '../electron');
if (!fs.existsSync(electronDirInDist)) {
  fs.mkdirSync(electronDirInDist, { recursive: true });
}
fs.copyFileSync(
  path.join(__dirname, '../electron/renderer.html'),
  path.join(electronDirInDist, 'renderer.html')
);

// Build do renderer.ts
esbuild.build({
  entryPoints: [path.join(__dirname, '../electron/renderer.ts')],
  bundle: true,
  outfile: path.join(outDir, 'renderer.js'),
  platform: 'browser',
  target: 'es2020',
  format: 'iife',
  sourcemap: true,
  external: ['electron'],
}).then(() => {
  console.log('Electron build completed!');
}).catch((error) => {
  console.error('Build error:', error);
  process.exit(1);
});

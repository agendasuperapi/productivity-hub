const esbuild = require('esbuild');
const path = require('path');
const fs = require('fs');

// Criar diretório de saída
const outDir = path.join(__dirname, '../dist-electron');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Criar package.json em dist-electron para definir type: "module"
const packageJsonPath = path.join(outDir, 'package.json');
fs.writeFileSync(packageJsonPath, JSON.stringify({ type: 'module' }, null, 2));

// Criar diretório electron se não existir
const electronDir = path.join(__dirname, '../electron');
if (!fs.existsSync(electronDir)) {
  fs.mkdirSync(electronDir, { recursive: true });
}

// Copiar renderer.html para dist-electron (para desenvolvimento)
fs.copyFileSync(
  path.join(__dirname, '../electron/renderer.html'),
  path.join(outDir, 'renderer.html')
);

// Copiar floating-window.html para dist-electron
fs.copyFileSync(
  path.join(__dirname, '../electron/floating-window.html'),
  path.join(outDir, 'floating-window.html')
);

// Copiar renderer.html para dist-electron/electron (para electron-builder)
const electronDirInDist = path.join(outDir, '../electron');
if (!fs.existsSync(electronDirInDist)) {
  fs.mkdirSync(electronDirInDist, { recursive: true });
}
fs.copyFileSync(
  path.join(__dirname, '../electron/renderer.html'),
  path.join(electronDirInDist, 'renderer.html')
);

// Copiar floating-window.html para electron (para electron-builder)
fs.copyFileSync(
  path.join(__dirname, '../electron/floating-window.html'),
  path.join(electronDirInDist, 'floating-window.html')
);

// Remover preload.js se existir (para evitar conflito com TypeScript)
const preloadPath = path.join(outDir, 'preload.js');
if (fs.existsSync(preloadPath)) {
  fs.unlinkSync(preloadPath);
}

// Build do preload.ts
esbuild.build({
  entryPoints: [path.join(__dirname, '../electron/preload.ts')],
  bundle: true,
  outfile: path.join(outDir, 'preload.js'),
  platform: 'node',
  target: 'es2020',
  format: 'iife',
  sourcemap: true,
  external: ['electron'],
}).then(() => {
  // Build do floating-preload.ts
  return esbuild.build({
    entryPoints: [path.join(__dirname, '../electron/floating-preload.ts')],
    bundle: true,
    outfile: path.join(outDir, 'floating-preload.js'),
    platform: 'node',
    target: 'es2020',
    format: 'iife',
    sourcemap: true,
    external: ['electron'],
  });
}).then(() => {
  // Build do renderer.ts
  return esbuild.build({
    entryPoints: [path.join(__dirname, '../electron/renderer.ts')],
    bundle: true,
    outfile: path.join(outDir, 'renderer.js'),
    platform: 'browser',
    target: 'es2020',
    format: 'iife',
    sourcemap: true,
    external: ['electron'],
  });
}).then(() => {
  console.log('Electron build completed!');
}).catch((error) => {
  console.error('Build error:', error);
  process.exit(1);
});

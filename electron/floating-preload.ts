// Preload script para janelas flutuantes - CommonJS puro
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { contextBridge, ipcRenderer } = require('electron');

interface FloatingWindowConfig {
  tabId: string;
  name: string;
  url: string;
  zoom: number;
  shortcutScript: string;
}

// Armazenar config para caso chegue antes do listener ser registrado
let pendingConfig: FloatingWindowConfig | null = null;
let configCallback: ((config: FloatingWindowConfig) => void) | null = null;

// Escutar o evento imediatamente
ipcRenderer.on('floating:init', (_: unknown, config: FloatingWindowConfig) => {
  console.log('[FloatingPreload] Received floating:init', config);
  if (configCallback) {
    configCallback(config);
  } else {
    pendingConfig = config;
  }
});

const floatingAPI = {
  // Receber configuração inicial
  onInit: (callback: (config: FloatingWindowConfig) => void) => {
    console.log('[FloatingPreload] Registering onInit listener');
    configCallback = callback;
    // Se já recebeu a config, chamar o callback imediatamente
    if (pendingConfig) {
      console.log('[FloatingPreload] Using pending config');
      callback(pendingConfig);
      pendingConfig = null;
    }
  },
  
  // Notificar mudança de zoom
  zoomChanged: (zoom: number) => {
    ipcRenderer.send('floating:zoomChanged', zoom);
  },
  
  // Abrir URL externa
  openExternal: (url: string) => {
    ipcRenderer.send('floating:openExternal', url);
  },
};

contextBridge.exposeInMainWorld('floatingAPI', floatingAPI);

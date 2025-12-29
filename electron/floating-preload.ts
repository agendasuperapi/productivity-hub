// Preload script para janelas flutuantes - CommonJS puro
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { contextBridge, ipcRenderer } = require('electron');

interface FloatingWindowConfig {
  tabId: string;
  name: string;
  url: string;
  zoom: number;
  shortcutScript: string;
  captureToken?: boolean;
  captureTokenHeader?: string;
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
  
  // Salvar posição e zoom no banco de dados
  savePosition: () => ipcRenderer.invoke('floating:savePosition'),
  
  // Abrir URL externa no navegador padrão
  openExternal: (url: string) => {
    ipcRenderer.send('floating:openExternal', url);
  },
  
  // Abrir URL em nova janela flutuante
  openInFloatingWindow: (url: string, name?: string) => {
    ipcRenderer.send('floating:openInFloatingWindow', url, name);
  },
  
  // Enviar token capturado para salvar no Supabase
  saveToken: (data: { tabId: string; domain: string; tokenName: string; tokenValue: string }) => {
    return ipcRenderer.invoke('floating:saveToken', data);
  },
  
  // Credenciais - salvar
  saveCredential: (data: { url: string; username: string; password: string; siteName?: string }) => {
    return ipcRenderer.invoke('floating:saveCredential', data);
  },
  
  // Credenciais - buscar para auto-fill
  getCredentials: (url: string) => {
    return ipcRenderer.invoke('floating:getCredentials', url);
  },
  
  // Controles de janela
  minimizeWindow: () => ipcRenderer.invoke('floatingWindow:minimize'),
  maximizeWindow: () => ipcRenderer.invoke('floatingWindow:maximize'),
  closeWindow: () => ipcRenderer.invoke('floatingWindow:close'),
  isMaximized: () => ipcRenderer.invoke('floatingWindow:isMaximized'),
  onMaximizeChange: (callback: (isMaximized: boolean) => void) => {
    ipcRenderer.on('floatingWindow:maximizeChange', (_: unknown, isMax: boolean) => callback(isMax));
  },
};

contextBridge.exposeInMainWorld('floatingAPI', floatingAPI);

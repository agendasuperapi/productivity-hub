import { contextBridge, ipcRenderer } from 'electron';

interface FloatingWindowConfig {
  tabId: string;
  url: string;
  zoom: number;
  shortcutScript: string;
}

const floatingAPI = {
  // Receber configuração inicial
  onInit: (callback: (config: FloatingWindowConfig) => void) => {
    ipcRenderer.on('floating:init', (_, config) => callback(config));
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

// Tipos globais
declare global {
  interface Window {
    floatingAPI: typeof floatingAPI;
  }
}

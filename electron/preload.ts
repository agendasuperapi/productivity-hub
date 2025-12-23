import { contextBridge, ipcRenderer } from 'electron';

// Tipos para a API exposta
export interface ElectronAPI {
  // Autenticação
  login: (email: string, password: string) => Promise<any>;
  logout: () => Promise<any>;
  getSession: () => Promise<any>;
  
  // Configurações
  fetchConfig: () => Promise<any>;
  getConfig: () => Promise<any>;
  
  // Janelas
  createWindow: (tab: any) => Promise<any>;
  
  // Atalhos
  registerShortcut: (shortcut: string, tabId: string) => Promise<any>;
  unregisterShortcut: (shortcut: string) => Promise<any>;
  unregisterAllShortcuts: () => Promise<any>;
  
  // Eventos
  onAuthStateChanged: (callback: (data: any) => void) => void;
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  removeAllListeners: (channel: string) => void;
}

const electronAPI: ElectronAPI = {
  // Autenticação
  login: (email: string, password: string) => 
    ipcRenderer.invoke('auth:login', email, password),
  
  logout: () => 
    ipcRenderer.invoke('auth:logout'),
  
  getSession: () => 
    ipcRenderer.invoke('auth:getSession'),

  // Configurações
  fetchConfig: () => 
    ipcRenderer.invoke('config:fetch'),
  
  getConfig: () => 
    ipcRenderer.invoke('config:get'),

  // Janelas
  createWindow: (tab: any) => 
    ipcRenderer.invoke('window:create', tab),

  // Atalhos
  registerShortcut: (shortcut: string, tabId: string) => 
    ipcRenderer.invoke('shortcut:register', shortcut, tabId),
  
  unregisterShortcut: (shortcut: string) => 
    ipcRenderer.invoke('shortcut:unregister', shortcut),
  
  unregisterAllShortcuts: () => 
    ipcRenderer.invoke('shortcut:unregisterAll'),

  // Eventos
  onAuthStateChanged: (callback: (data: any) => void) => {
    ipcRenderer.on('auth:stateChanged', (_, data) => callback(data));
  },
  
  onShortcutTriggered: (callback: (tabId: string) => void) => {
    ipcRenderer.on('shortcut:triggered', (_, tabId) => callback(tabId));
  },
  
  removeAllListeners: (channel: string) => {
    ipcRenderer.removeAllListeners(channel);
  },
};

// Expor API de forma segura
contextBridge.exposeInMainWorld('electronAPI', electronAPI);

// Declaração de tipos globais
declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}


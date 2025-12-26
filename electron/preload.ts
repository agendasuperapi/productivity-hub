import { contextBridge, ipcRenderer } from 'electron';

// Tipos para a API exposta
export interface TextShortcutData {
  command: string;
  expanded_text: string;
}

export interface KeywordData {
  key: string;
  value: string;
}

export interface TabData {
  id: string;
  name: string;
  url: string;
  urls?: string[];
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  zoom?: number;
  layout_type?: string;
  group_id?: string;
  position?: number;
  open_as_window?: boolean;
  window_x?: number;
  window_y?: number;
  window_width?: number;
  window_height?: number;
  // Dados para injeção de scripts
  textShortcuts?: TextShortcutData[];
  keywords?: KeywordData[];
}

export interface WindowPositionData {
  tabId: string;
  x: number;
  y: number;
}

export interface WindowSizeData {
  tabId: string;
  width: number;
  height: number;
}

export interface WindowBoundsData {
  tabId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zoom: number;
}

export interface SavedWindowState {
  tabId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zoom: number;
}

export interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  user_id: string;
}

export interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
  user_id: string;
}

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
  user: {
    id: string;
    email?: string;
    user_metadata?: {
      full_name?: string;
      name?: string;
    };
  };
}

export interface ElectronAPI {
  // Auth - Sessão persistente
  getSession: () => Promise<AuthSession | null>;
  setSession: (session: AuthSession) => Promise<boolean>;
  clearSession: () => Promise<boolean>;
  
  // Session restore - Janelas flutuantes
  getFloatingWindowsSession: () => Promise<SavedWindowState[] | null>;
  clearFloatingWindowsSession: () => Promise<boolean>;
  
  // Clipboard
  writeToClipboard: (text: string) => Promise<{ success: boolean; error?: string }>;
  
  // Janelas
  createWindow: (tab: TabData) => Promise<{ success: boolean; windowId?: string; error?: string }>;
  closeWindow: (tabId: string) => Promise<{ success: boolean }>;
  openExternal: (url: string) => Promise<{ success: boolean; error?: string }>;
  
  // Atalhos de teclado globais
  registerShortcut: (shortcut: string, tabId: string) => Promise<{ success: boolean; error?: string }>;
  unregisterShortcut: (shortcut: string) => Promise<{ success: boolean; error?: string }>;
  unregisterAllShortcuts: () => Promise<{ success: boolean; error?: string }>;
  
  // Eventos
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  onWindowPositionChanged: (callback: (data: WindowPositionData) => void) => void;
  onWindowSizeChanged: (callback: (data: WindowSizeData) => void) => void;
  onWindowBoundsChanged: (callback: (data: WindowBoundsData) => void) => void;
  removeAllListeners: (channel: string) => void;
}

const electronAPI: ElectronAPI = {
  // Auth - Sessão persistente
  getSession: () => ipcRenderer.invoke('auth:getSession'),
  setSession: (session) => ipcRenderer.invoke('auth:setSession', session),
  clearSession: () => ipcRenderer.invoke('auth:clearSession'),

  // Session restore - Janelas flutuantes
  getFloatingWindowsSession: () => ipcRenderer.invoke('session:getFloatingWindows'),
  clearFloatingWindowsSession: () => ipcRenderer.invoke('session:clearFloatingWindows'),

  // Clipboard
  writeToClipboard: (text) => ipcRenderer.invoke('clipboard:write', text),

  // Janelas
  createWindow: (tab) => ipcRenderer.invoke('window:create', tab),
  closeWindow: (tabId) => ipcRenderer.invoke('window:close', tabId),
  openExternal: (url) => ipcRenderer.invoke('window:openExternal', url),

  // Atalhos de teclado
  registerShortcut: (shortcut, tabId) => ipcRenderer.invoke('keyboard:register', shortcut, tabId),
  unregisterShortcut: (shortcut) => ipcRenderer.invoke('keyboard:unregister', shortcut),
  unregisterAllShortcuts: () => ipcRenderer.invoke('keyboard:unregisterAll'),

  // Eventos
  onShortcutTriggered: (callback) => {
    ipcRenderer.on('keyboard:triggered', (_, tabId) => callback(tabId));
  },
  
  onWindowPositionChanged: (callback) => {
    ipcRenderer.on('window:positionChanged', (_, data) => callback(data));
  },
  
  onWindowSizeChanged: (callback) => {
    ipcRenderer.on('window:sizeChanged', (_, data) => callback(data));
  },
  
  onWindowBoundsChanged: (callback) => {
    ipcRenderer.on('window:boundsChanged', (_, data) => callback(data));
  },
  
  removeAllListeners: (channel) => {
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

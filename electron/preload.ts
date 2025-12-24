import { contextBridge, ipcRenderer } from 'electron';

// Tipos para a API exposta
export interface Tab {
  id: string;
  name: string;
  url: string;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  zoom?: number;
  group_id: string;
  position: number;
  open_as_window?: boolean;
}

export interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
}

export interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
}

export interface LocalConfig {
  tab_groups: TabGroup[];
  tabs: Tab[];
  text_shortcuts: TextShortcut[];
}

export interface ElectronAPI {
  // Config
  getConfig: () => Promise<LocalConfig>;
  
  // Tab Groups
  addTabGroup: (group: Omit<TabGroup, 'id'>) => Promise<TabGroup>;
  updateTabGroup: (id: string, data: Partial<TabGroup>) => Promise<TabGroup | null>;
  deleteTabGroup: (id: string) => Promise<boolean>;
  
  // Tabs
  addTab: (tab: Omit<Tab, 'id'>) => Promise<Tab>;
  updateTab: (id: string, data: Partial<Tab>) => Promise<Tab | null>;
  deleteTab: (id: string) => Promise<boolean>;
  
  // Text Shortcuts
  addTextShortcut: (shortcut: Omit<TextShortcut, 'id'>) => Promise<TextShortcut>;
  updateTextShortcut: (id: string, data: Partial<TextShortcut>) => Promise<TextShortcut | null>;
  deleteTextShortcut: (id: string) => Promise<boolean>;
  importTextShortcuts: (shortcuts: Omit<TextShortcut, 'id'>[]) => Promise<TextShortcut[]>;
  exportTextShortcuts: () => Promise<TextShortcut[]>;
  
  // Janelas
  createWindow: (tab: Tab) => Promise<any>;
  
  // Atalhos de teclado globais
  registerShortcut: (shortcut: string, tabId: string) => Promise<any>;
  unregisterShortcut: (shortcut: string) => Promise<any>;
  unregisterAllShortcuts: () => Promise<any>;
  
  // Eventos
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  removeAllListeners: (channel: string) => void;
}

const electronAPI: ElectronAPI = {
  // Config
  getConfig: () => ipcRenderer.invoke('config:get'),
  
  // Tab Groups
  addTabGroup: (group) => ipcRenderer.invoke('tabGroup:add', group),
  updateTabGroup: (id, data) => ipcRenderer.invoke('tabGroup:update', id, data),
  deleteTabGroup: (id) => ipcRenderer.invoke('tabGroup:delete', id),
  
  // Tabs
  addTab: (tab) => ipcRenderer.invoke('tab:add', tab),
  updateTab: (id, data) => ipcRenderer.invoke('tab:update', id, data),
  deleteTab: (id) => ipcRenderer.invoke('tab:delete', id),
  
  // Text Shortcuts
  addTextShortcut: (shortcut) => ipcRenderer.invoke('shortcut:add', shortcut),
  updateTextShortcut: (id, data) => ipcRenderer.invoke('shortcut:update', id, data),
  deleteTextShortcut: (id) => ipcRenderer.invoke('shortcut:delete', id),
  importTextShortcuts: (shortcuts) => ipcRenderer.invoke('shortcuts:import', shortcuts),
  exportTextShortcuts: () => ipcRenderer.invoke('shortcuts:export'),

  // Janelas
  createWindow: (tab) => ipcRenderer.invoke('window:create', tab),

  // Atalhos de teclado
  registerShortcut: (shortcut, tabId) => ipcRenderer.invoke('keyboard:register', shortcut, tabId),
  unregisterShortcut: (shortcut) => ipcRenderer.invoke('keyboard:unregister', shortcut),
  unregisterAllShortcuts: () => ipcRenderer.invoke('keyboard:unregisterAll'),

  // Eventos
  onShortcutTriggered: (callback) => {
    ipcRenderer.on('keyboard:triggered', (_, tabId) => callback(tabId));
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

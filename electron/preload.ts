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
  alternative_domains?: string[];
  show_link_transform_panel?: boolean;
  capture_token?: boolean;
  capture_token_header?: string;
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

export interface DownloadItem {
  filename: string;
  path: string;
  url: string;
  completedAt: number;
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

export interface TokenCapturedData {
  tabId: string;
  domain: string;
  tokenName: string;
  tokenValue: string;
}

export interface ElectronAPI {
  // Auth - Sessão persistente
  getSession: () => Promise<AuthSession | null>;
  setSession: (session: AuthSession) => Promise<boolean>;
  clearSession: () => Promise<boolean>;
  
  // Session restore - Janelas flutuantes
  getFloatingWindowsSession: () => Promise<SavedWindowState[] | null>;
  clearFloatingWindowsSession: () => Promise<boolean>;
  
  // User Settings
  getSetting: (key: string) => Promise<unknown>;
  setSetting: (key: string, value: unknown) => Promise<boolean>;
  getAllSettings: () => Promise<Record<string, unknown>>;
  setAllSettings: (settings: Record<string, unknown>) => Promise<boolean>;
  
  // Clipboard
  writeToClipboard: (text: string) => Promise<{ success: boolean; error?: string }>;
  
  // Janelas
  createWindow: (tab: TabData) => Promise<{ success: boolean; windowId?: string; error?: string }>;
  closeWindow: (tabId: string) => Promise<{ success: boolean }>;
  openExternal: (url: string) => Promise<{ success: boolean; error?: string }>;
  
  // Controles de janela principal
  minimizeWindow: () => Promise<{ success: boolean }>;
  maximizeWindow: () => Promise<{ success: boolean; isMaximized: boolean }>;
  closeMainWindow: () => Promise<{ success: boolean }>;
  isMaximized: () => Promise<boolean>;
  onMaximizeChange: (callback: (isMaximized: boolean) => void) => void;
  
  // Downloads
  getRecentDownloads: () => Promise<DownloadItem[]>;
  openDownloadedFile: (path: string) => Promise<{ success: boolean; error?: string }>;
  showInFolder: (path: string) => Promise<{ success: boolean; error?: string }>;
  onDownloadCompleted: (callback: (download: DownloadItem) => void) => void;
  
  // Atalhos de teclado globais
  registerShortcut: (shortcut: string, tabId: string) => Promise<{ success: boolean; error?: string }>;
  unregisterShortcut: (shortcut: string) => Promise<{ success: boolean; error?: string }>;
  unregisterAllShortcuts: () => Promise<{ success: boolean; error?: string }>;
  
  // Eventos
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  onWindowPositionChanged: (callback: (data: WindowPositionData) => void) => void;
  onWindowSizeChanged: (callback: (data: WindowSizeData) => void) => void;
  onWindowBoundsChanged: (callback: (data: WindowBoundsData) => void) => void;
  onFloatingSavePosition: (callback: (data: WindowBoundsData) => void) => void;
  onTokenCaptured: (callback: (data: TokenCapturedData) => void) => void;
  removeTokenListener: (callback: (data: TokenCapturedData) => void) => void;
  // Credential handlers
  onCredentialSave: (callback: (event: unknown, data: { url: string; username: string; password: string; siteName?: string }) => void) => void;
  onCredentialGet: (callback: (event: unknown, data: { url: string; responseChannel: string }) => void) => void;
  onCredentialBlockDomain: (callback: (event: unknown, data: { domain: string; responseChannel: string }) => void) => void;
  onCredentialIsBlocked: (callback: (event: unknown, data: { domain: string; responseChannel: string }) => void) => void;
  sendCredentialResponse: (channel: string, credentials: unknown[]) => void;
  sendBlockDomainResponse: (channel: string, result: { success: boolean }) => void;
  sendIsBlockedResponse: (channel: string, result: { blocked: boolean }) => void;
  removeCredentialListeners: () => void;
  // Form Field handlers
  onFormFieldSave: (callback: (event: unknown, data: { domain: string; field: string; value: string; label?: string }) => void) => void;
  onFormFieldGet: (callback: (event: unknown, data: { domain: string; field: string; responseChannel: string }) => void) => void;
  sendFormFieldResponse: (channel: string, suggestions: string[]) => void;
  removeFormFieldListeners: () => void;
  removeAllListeners: (channel: string) => void;
}

// ============================================
// Sistema de buffer para eventos de token
// Garante que eventos nunca sejam perdidos
// ============================================
console.log('[Preload] Inicializando sistema de buffer de tokens...');

type TokenCallback = (data: TokenCapturedData) => void;
let tokenCallbacks: TokenCallback[] = [];
let pendingTokenEvents: TokenCapturedData[] = [];

// Registrar listener IMEDIATAMENTE - não esperar onTokenCaptured()
ipcRenderer.on('token:captured', (_, data: TokenCapturedData) => {
  console.log('[Preload] ===== TOKEN:CAPTURED RECEBIDO =====');
  console.log('[Preload] Dados:', JSON.stringify(data));
  console.log('[Preload] Callbacks registrados:', tokenCallbacks.length);
  
  if (tokenCallbacks.length > 0) {
    console.log('[Preload] Chamando', tokenCallbacks.length, 'callbacks...');
    tokenCallbacks.forEach((cb, i) => {
      console.log('[Preload] Chamando callback', i + 1);
      try {
        cb(data);
      } catch (err) {
        console.error('[Preload] Erro no callback', i + 1, ':', err);
      }
    });
  } else {
    // Guardar para quando callback for registrado
    pendingTokenEvents.push(data);
    console.log('[Preload] Nenhum callback - token guardado em buffer. Pendentes:', pendingTokenEvents.length);
  }
});

console.log('[Preload] Listener token:captured registrado globalmente');

const electronAPI: ElectronAPI = {
  // Auth - Sessão persistente
  getSession: () => ipcRenderer.invoke('auth:getSession'),
  setSession: (session) => ipcRenderer.invoke('auth:setSession', session),
  clearSession: () => ipcRenderer.invoke('auth:clearSession'),

  // Session restore - Janelas flutuantes
  getFloatingWindowsSession: () => ipcRenderer.invoke('session:getFloatingWindows'),
  clearFloatingWindowsSession: () => ipcRenderer.invoke('session:clearFloatingWindows'),

  // User Settings
  getSetting: (key) => ipcRenderer.invoke('settings:get', key),
  setSetting: (key, value) => ipcRenderer.invoke('settings:set', key, value),
  getAllSettings: () => ipcRenderer.invoke('settings:getAll'),
  setAllSettings: (settings) => ipcRenderer.invoke('settings:setAll', settings),

  // Clipboard
  writeToClipboard: (text) => ipcRenderer.invoke('clipboard:write', text),

  // Janelas
  createWindow: (tab) => ipcRenderer.invoke('window:create', tab),
  closeWindow: (tabId) => ipcRenderer.invoke('window:close', tabId),
  openExternal: (url) => ipcRenderer.invoke('window:openExternal', url),

  // Controles de janela principal
  minimizeWindow: () => ipcRenderer.invoke('window:minimize'),
  maximizeWindow: () => ipcRenderer.invoke('window:maximize'),
  closeMainWindow: () => ipcRenderer.invoke('window:closeMain'),
  isMaximized: () => ipcRenderer.invoke('window:isMaximized'),
  onMaximizeChange: (callback) => {
    ipcRenderer.on('window:maximizeChange', (_, isMaximized) => callback(isMaximized));
  },

  // Downloads
  getRecentDownloads: () => ipcRenderer.invoke('downloads:getRecent'),
  openDownloadedFile: (path) => ipcRenderer.invoke('downloads:openFile', path),
  showInFolder: (path) => ipcRenderer.invoke('downloads:showInFolder', path),
  onDownloadCompleted: (callback) => {
    ipcRenderer.on('download:completed', (_, download) => callback(download));
  },

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
  
  onFloatingSavePosition: (callback) => {
    ipcRenderer.on('floating:requestSavePosition', (_, data) => callback(data));
  },
  
  // Token capture com buffer
  onTokenCaptured: (callback) => {
    console.log('[Preload] Registrando callback de token');
    tokenCallbacks.push(callback);
    console.log('[Preload] Total callbacks:', tokenCallbacks.length);
    
    // Processar eventos pendentes
    if (pendingTokenEvents.length > 0) {
      console.log('[Preload] Processando', pendingTokenEvents.length, 'tokens pendentes');
      const pending = [...pendingTokenEvents];
      pendingTokenEvents = [];
      pending.forEach(data => {
        try {
          callback(data);
        } catch (err) {
          console.error('[Preload] Erro ao processar token pendente:', err);
        }
      });
    }
  },
  
  removeTokenListener: (callback) => {
    console.log('[Preload] Removendo callback de token');
    const before = tokenCallbacks.length;
    tokenCallbacks = tokenCallbacks.filter(cb => cb !== callback);
    console.log('[Preload] Callbacks removidos:', before - tokenCallbacks.length, 'restantes:', tokenCallbacks.length);
  },
  
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  },
  
  // Credential handlers para janelas flutuantes
  onCredentialSave: (callback) => {
    ipcRenderer.on('credential:save', (_, data) => callback(_, data));
  },
  
  onCredentialGet: (callback) => {
    ipcRenderer.on('credential:get', (_, data) => callback(_, data));
  },
  
  sendCredentialResponse: (channel, credentials) => {
    ipcRenderer.send(channel, credentials);
  },
  
  onCredentialBlockDomain: (callback) => {
    ipcRenderer.on('credential:blockDomain', (_, data) => callback(_, data));
  },
  
  onCredentialIsBlocked: (callback) => {
    ipcRenderer.on('credential:isBlocked', (_, data) => callback(_, data));
  },
  
  sendBlockDomainResponse: (channel, result) => {
    ipcRenderer.send(channel, result);
  },
  
  sendIsBlockedResponse: (channel, result) => {
    ipcRenderer.send(channel, result);
  },
  
  removeCredentialListeners: () => {
    ipcRenderer.removeAllListeners('credential:save');
    ipcRenderer.removeAllListeners('credential:get');
    ipcRenderer.removeAllListeners('credential:blockDomain');
    ipcRenderer.removeAllListeners('credential:isBlocked');
  },
  
  // Form Field handlers para janelas flutuantes
  onFormFieldSave: (callback) => {
    console.log('[Preload] Registrando listener para formField:save');
    ipcRenderer.on('formField:save', (_, data) => {
      console.log('[Preload] Recebido formField:save:', data);
      callback(_, data);
    });
  },
  
  onFormFieldGet: (callback) => {
    console.log('[Preload] Registrando listener para formField:get');
    ipcRenderer.on('formField:get', (_, data) => {
      console.log('[Preload] ===== RECEBIDO formField:get =====');
      console.log('[Preload] Data:', JSON.stringify(data));
      callback(_, data);
    });
  },
  
  sendFormFieldResponse: (channel, suggestions) => {
    console.log('[Preload] ===== ENVIANDO RESPOSTA DE FORM FIELD =====');
    console.log('[Preload] Channel:', channel);
    console.log('[Preload] Suggestions:', suggestions);
    ipcRenderer.send(channel, suggestions);
    console.log('[Preload] Resposta enviada via ipcRenderer.send');
  },
  
  removeFormFieldListeners: () => {
    console.log('[Preload] Removendo listeners de formField');
    ipcRenderer.removeAllListeners('formField:save');
    ipcRenderer.removeAllListeners('formField:get');
  },
};

// Expor API de forma segura
contextBridge.exposeInMainWorld('electronAPI', electronAPI);

console.log('[Preload] electronAPI exposta com sucesso');

// Declaração de tipos globais
declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

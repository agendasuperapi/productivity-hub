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
  urls?: { url: string; shortcut_enabled?: boolean; zoom?: number; session_group?: string }[];
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
  shortcutConfig?: { activationKey: string; activationTime: number };
  alternative_domains?: string[];
  show_link_transform_panel?: boolean;
  capture_token?: boolean;
  capture_token_header?: string;
  session_group?: string;
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

export interface LocalCredentialData {
  id: string;
  domain: string;
  username: string;
  encrypted_password: string;
  site_name?: string | null;
  created_at: string;
  updated_at: string;
  synced: boolean;
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
  readFromClipboard: () => Promise<{ success: boolean; text?: string; error?: string }>;
  
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
  saveMainWindowPosition: () => Promise<{ success: boolean }>;
  
  // Downloads
  getRecentDownloads: () => Promise<DownloadItem[]>;
  openDownloadedFile: (path: string) => Promise<{ success: boolean; error?: string }>;
  showInFolder: (path: string) => Promise<{ success: boolean; error?: string }>;
  onDownloadCompleted: (callback: (download: DownloadItem) => void) => void;
  selectDownloadsFolder: () => Promise<{ success: boolean; path?: string; canceled?: boolean }>;
  getDownloadsFolder: () => Promise<string>;
  setDownloadsFolder: (folder: string) => Promise<{ success: boolean }>;
  getDefaultDownloadsFolder: () => Promise<string>;
  
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
  // Form Field local storage handlers
  getFormFieldDomains: () => Promise<{ domain: string; valueCount: number }[]>;
  clearFormFieldsForDomain: (domain: string) => Promise<{ success: boolean; deleted: number }>;
  // Local credentials handlers (offline storage)
  saveLocalCredential: (credential: LocalCredentialData) => Promise<{ success: boolean }>;
  getLocalCredentialsByDomain: (domain: string) => Promise<LocalCredentialData[]>;
  getAllLocalCredentials: () => Promise<LocalCredentialData[]>;
  deleteLocalCredential: (id: string) => Promise<{ success: boolean }>;
  markLocalCredentialSynced: (id: string) => Promise<{ success: boolean }>;
  getUnsyncedLocalCredentials: () => Promise<LocalCredentialData[]>;
  syncCredentialsFromSupabase: (credentials: LocalCredentialData[]) => Promise<{ success: boolean }>;
  removeAllListeners: (channel: string) => void;
  // Blocked domains local storage
  getLocalBlockedDomains: () => Promise<string[]>;
  addLocalBlockedDomain: (domain: string) => Promise<{ success: boolean }>;
  removeLocalBlockedDomain: (domain: string) => Promise<{ success: boolean }>;
  syncBlockedDomainsFromSupabase: (domains: string[]) => Promise<{ success: boolean }>;
  isLocalDomainBlocked: (domain: string) => Promise<boolean>;
  // Data cleanup
  deleteCredentialsByDomain: (domain: string) => Promise<{ success: boolean; deleted?: number }>;
  clearSessionData: (partitionName: string) => Promise<{ success: boolean; error?: string }>;
  // Browser data local cache (offline)
  getBrowserDataLocal: () => Promise<{ tabGroups: any[]; tabs: any[]; lastSync: string | null }>;
  saveBrowserDataLocal: (data: { tabGroups?: any[]; tabs?: any[] }) => Promise<{ success: boolean }>;
  // Tab settings (abrir dialog de edição via janela flutuante)
  onTabOpenSettings: (callback: (tabId: string) => void) => void;
  // Navegação via botões laterais do mouse
  onNavigateBack: (callback: () => void) => () => void;
  onNavigateForward: (callback: () => void) => () => void;
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

// ============================================
// Sistema de buffer para eventos de download
// Garante que eventos nunca sejam perdidos (ex.: primeiro download)
// ============================================
console.log('[Preload] Inicializando sistema de buffer de downloads...');

type DownloadCompletedCallback = (download: DownloadItem) => void;
let downloadCompletedCallbacks: DownloadCompletedCallback[] = [];
let pendingDownloadCompletedEvents: DownloadItem[] = [];

// Registrar listener IMEDIATAMENTE - não esperar onDownloadCompleted()
ipcRenderer.on('download:completed', (_, download: DownloadItem) => {
  console.log('[Preload] ===== DOWNLOAD:COMPLETED RECEBIDO =====');
  console.log('[Preload] Download:', JSON.stringify(download));
  console.log('[Preload] Callbacks registrados:', downloadCompletedCallbacks.length);

  if (downloadCompletedCallbacks.length > 0) {
    downloadCompletedCallbacks.forEach((cb, i) => {
      try {
        cb(download);
      } catch (err) {
        console.error('[Preload] Erro no callback de download', i + 1, ':', err);
      }
    });
  } else {
    pendingDownloadCompletedEvents.push(download);
    console.log('[Preload] Nenhum callback - download guardado em buffer. Pendentes:', pendingDownloadCompletedEvents.length);
  }
});

console.log('[Preload] Listener download:completed registrado globalmente');

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
  readFromClipboard: () => ipcRenderer.invoke('clipboard:read'),

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
  saveMainWindowPosition: () => ipcRenderer.invoke('mainWindow:saveBounds'),

  // Downloads
  getRecentDownloads: () => ipcRenderer.invoke('downloads:getRecent'),
  openDownloadedFile: (path) => ipcRenderer.invoke('downloads:openFile', path),
  showInFolder: (path) => ipcRenderer.invoke('downloads:showInFolder', path),
  selectDownloadsFolder: () => ipcRenderer.invoke('downloads:selectFolder'),
  getDownloadsFolder: () => ipcRenderer.invoke('downloads:getFolder'),
  setDownloadsFolder: (folder) => ipcRenderer.invoke('downloads:setFolder', folder),
  getDefaultDownloadsFolder: () => ipcRenderer.invoke('downloads:getDefaultFolder'),
  onDownloadCompleted: (callback) => {
    console.log('[Preload] Registrando callback de download');
    downloadCompletedCallbacks.push(callback);
    console.log('[Preload] Total callbacks de download:', downloadCompletedCallbacks.length);

    // Processar eventos pendentes
    if (pendingDownloadCompletedEvents.length > 0) {
      console.log('[Preload] Processando', pendingDownloadCompletedEvents.length, 'downloads pendentes');
      const pending = [...pendingDownloadCompletedEvents];
      pendingDownloadCompletedEvents = [];
      pending.forEach((download) => {
        try {
          callback(download);
        } catch (err) {
          console.error('[Preload] Erro ao processar download pendente:', err);
        }
      });
    }
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
    // IMPORTANTE: não remover o listener global do buffer de downloads.
    // O app usa removeAllListeners('download:completed') no cleanup, então aqui
    // limpamos apenas callbacks/buffer para evitar quebrar o auto-open inicial.
    if (channel === 'download:completed') {
      console.log('[Preload] Limpando callbacks/buffer de downloads (sem remover listener global)');
      downloadCompletedCallbacks = [];
      pendingDownloadCompletedEvents = [];
      return;
    }

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
  
  // Form Field local storage handlers
  getFormFieldDomains: () => ipcRenderer.invoke('floating:getFormFieldDomains'),
  clearFormFieldsForDomain: (domain: string) => ipcRenderer.invoke('floating:clearFormFieldsForDomain', domain),
  
  // Local credentials handlers (offline storage)
  saveLocalCredential: (credential: LocalCredentialData) => ipcRenderer.invoke('credential:saveLocal', credential),
  getLocalCredentialsByDomain: (domain: string) => ipcRenderer.invoke('credential:getLocalByDomain', domain),
  getAllLocalCredentials: () => ipcRenderer.invoke('credential:getAllLocal'),
  deleteLocalCredential: (id: string) => ipcRenderer.invoke('credential:deleteLocal', id),
  markLocalCredentialSynced: (id: string) => ipcRenderer.invoke('credential:markSynced', id),
  getUnsyncedLocalCredentials: () => ipcRenderer.invoke('credential:getUnsynced'),
  syncCredentialsFromSupabase: (credentials: LocalCredentialData[]) => ipcRenderer.invoke('credential:syncFromSupabase', credentials),
  
  // Blocked domains local storage
  getLocalBlockedDomains: () => ipcRenderer.invoke('blockedDomains:getLocal'),
  addLocalBlockedDomain: (domain: string) => ipcRenderer.invoke('blockedDomains:addLocal', domain),
  removeLocalBlockedDomain: (domain: string) => ipcRenderer.invoke('blockedDomains:removeLocal', domain),
  syncBlockedDomainsFromSupabase: (domains: string[]) => ipcRenderer.invoke('blockedDomains:syncFromSupabase', domains),
  isLocalDomainBlocked: (domain: string) => ipcRenderer.invoke('blockedDomains:isBlocked', domain),
  
  // Data cleanup
  deleteCredentialsByDomain: (domain: string) => ipcRenderer.invoke('credential:deleteByDomain', domain),
  clearSessionData: (partitionName: string) => ipcRenderer.invoke('session:clearData', partitionName),
  
  // Browser data local cache (offline)
  getBrowserDataLocal: () => ipcRenderer.invoke('browserData:getLocal'),
  saveBrowserDataLocal: (data: { tabGroups?: any[]; tabs?: any[] }) => ipcRenderer.invoke('browserData:saveLocal', data),
  
  // Tab settings (abrir dialog de edição via janela flutuante)
  onTabOpenSettings: (callback) => {
    ipcRenderer.on('tab:openSettings', (_, tabId) => callback(tabId));
  },
  
  // Navegação via botões laterais do mouse
  onNavigateBack: (callback: () => void) => {
    const handler = () => callback();
    ipcRenderer.on('navigate:back', handler);
    return () => ipcRenderer.removeListener('navigate:back', handler);
  },
  onNavigateForward: (callback: () => void) => {
    const handler = () => callback();
    ipcRenderer.on('navigate:forward', handler);
    return () => ipcRenderer.removeListener('navigate:forward', handler);
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

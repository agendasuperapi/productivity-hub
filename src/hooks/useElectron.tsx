import { useCallback, useEffect, useState } from 'react';

// Tipos para a API do Electron
interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcutData {
  command: string;
  expanded_text: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface KeywordData {
  key: string;
  value: string;
}

interface TabData {
  id: string;
  name: string;
  url: string;
  urls?: { url: string; shortcut_enabled?: boolean; zoom?: number }[];
  zoom?: number;
  layout_type?: string;
  open_as_window?: boolean;
  window_x?: number;
  window_y?: number;
  window_width?: number;
  window_height?: number;
  textShortcuts?: TextShortcutData[];
  keywords?: KeywordData[];
  alternative_domains?: string[];
  show_link_transform_panel?: boolean;
  /** Habilita captura automática de token via webRequest */
  capture_token?: boolean;
  /** Nome do header HTTP a ser capturado (default: X-Access-Token) */
  capture_token_header?: string;
}

interface WindowPositionData {
  tabId: string;
  x: number;
  y: number;
}

interface WindowSizeData {
  tabId: string;
  width: number;
  height: number;
}

interface WindowBoundsData {
  tabId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zoom: number;
}

interface SavedWindowState {
  tabId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zoom: number;
}

interface DownloadItem {
  filename: string;
  path: string;
  url: string;
  completedAt: number;
}

interface ElectronAPI {
  getSession: () => Promise<any>;
  setSession: (session: any) => Promise<boolean>;
  clearSession: () => Promise<boolean>;
  getFloatingWindowsSession: () => Promise<SavedWindowState[] | null>;
  clearFloatingWindowsSession: () => Promise<boolean>;
  writeToClipboard: (text: string) => Promise<{ success: boolean; error?: string }>;
  createWindow: (tab: TabData) => Promise<{ success: boolean; windowId?: string; error?: string }>;
  closeWindow: (tabId: string) => Promise<{ success: boolean }>;
  openExternal: (url: string) => Promise<{ success: boolean; error?: string }>;
  minimizeWindow: () => Promise<{ success: boolean }>;
  maximizeWindow: () => Promise<{ success: boolean; isMaximized: boolean }>;
  closeMainWindow: () => Promise<{ success: boolean }>;
  isMaximized: () => Promise<boolean>;
  onMaximizeChange: (callback: (isMaximized: boolean) => void) => void;
  saveMainWindowPosition: () => Promise<{ success: boolean }>;
  getRecentDownloads: () => Promise<DownloadItem[]>;
  openDownloadedFile: (path: string) => Promise<{ success: boolean; error?: string }>;
  showInFolder: (path: string) => Promise<{ success: boolean; error?: string }>;
  onDownloadCompleted: (callback: (download: DownloadItem) => void) => void;
  registerShortcut: (shortcut: string, tabId: string) => Promise<{ success: boolean; error?: string }>;
  unregisterShortcut: (shortcut: string) => Promise<{ success: boolean }>;
  unregisterAllShortcuts: () => Promise<{ success: boolean }>;
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  onWindowPositionChanged: (callback: (data: WindowPositionData) => void) => void;
  onWindowSizeChanged: (callback: (data: WindowSizeData) => void) => void;
  onWindowBoundsChanged: (callback: (data: WindowBoundsData) => void) => void;
  onFloatingSavePosition: (callback: (data: WindowBoundsData) => void) => void;
  // Form field local storage
  getFormFieldDomains: () => Promise<{ domain: string; valueCount: number }[]>;
  clearFormFieldsForDomain: (domain: string) => Promise<{ success: boolean; deleted: number }>;
  removeAllListeners: (channel: string) => void;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}

export type { TabData, WindowPositionData, WindowSizeData, WindowBoundsData, ElectronAPI, DownloadItem };

export function useElectron() {
  const [isElectron, setIsElectron] = useState(false);

  useEffect(() => {
    setIsElectron(!!window.electronAPI);
  }, []);

  const openExternal = useCallback(async (url: string) => {
    if (window.electronAPI?.openExternal) {
      return await window.electronAPI.openExternal(url);
    }
    // Fallback para web
    window.open(url, '_blank');
    return { success: true };
  }, []);

  const createWindow = useCallback(async (tab: TabData) => {
    if (window.electronAPI?.createWindow) {
      return await window.electronAPI.createWindow(tab);
    }
    // Fallback para web - abre em nova aba
    window.open(tab.url, '_blank');
    return { success: true };
  }, []);

  const closeWindow = useCallback(async (tabId: string) => {
    if (window.electronAPI?.closeWindow) {
      return await window.electronAPI.closeWindow(tabId);
    }
    return { success: true };
  }, []);

  const registerShortcut = useCallback(async (shortcut: string, tabId: string) => {
    if (window.electronAPI?.registerShortcut) {
      return await window.electronAPI.registerShortcut(shortcut, tabId);
    }
    return { success: false, error: 'Not in Electron' };
  }, []);

  const unregisterShortcut = useCallback(async (shortcut: string) => {
    if (window.electronAPI?.unregisterShortcut) {
      return await window.electronAPI.unregisterShortcut(shortcut);
    }
    return { success: true };
  }, []);

  const onShortcutTriggered = useCallback((callback: (tabId: string) => void) => {
    if (window.electronAPI?.onShortcutTriggered) {
      window.electronAPI.onShortcutTriggered(callback);
    }
  }, []);

  const onWindowPositionChanged = useCallback((callback: (data: WindowPositionData) => void) => {
    if (window.electronAPI?.onWindowPositionChanged) {
      window.electronAPI.onWindowPositionChanged(callback);
    }
  }, []);

  const onWindowSizeChanged = useCallback((callback: (data: WindowSizeData) => void) => {
    if (window.electronAPI?.onWindowSizeChanged) {
      window.electronAPI.onWindowSizeChanged(callback);
    }
  }, []);

  const onWindowBoundsChanged = useCallback((callback: (data: WindowBoundsData) => void) => {
    if (window.electronAPI?.onWindowBoundsChanged) {
      window.electronAPI.onWindowBoundsChanged(callback);
    }
  }, []);

  const onFloatingSavePosition = useCallback((callback: (data: WindowBoundsData) => void) => {
    if (window.electronAPI?.onFloatingSavePosition) {
      window.electronAPI.onFloatingSavePosition(callback);
    }
  }, []);

  const removeAllListeners = useCallback((channel: string) => {
    if (window.electronAPI?.removeAllListeners) {
      window.electronAPI.removeAllListeners(channel);
    }
  }, []);

  // Session management
  const getSession = useCallback(async () => {
    if (window.electronAPI?.getSession) {
      return await window.electronAPI.getSession();
    }
    return null;
  }, []);

  const setSession = useCallback(async (session: any) => {
    if (window.electronAPI?.setSession) {
      return await window.electronAPI.setSession(session);
    }
    return false;
  }, []);

  const clearSession = useCallback(async () => {
    if (window.electronAPI?.clearSession) {
      return await window.electronAPI.clearSession();
    }
    return false;
  }, []);

  // Floating windows session
  const getFloatingWindowsSession = useCallback(async (): Promise<SavedWindowState[] | null> => {
    if (window.electronAPI?.getFloatingWindowsSession) {
      return await window.electronAPI.getFloatingWindowsSession();
    }
    return null;
  }, []);

  const clearFloatingWindowsSession = useCallback(async () => {
    if (window.electronAPI?.clearFloatingWindowsSession) {
      return await window.electronAPI.clearFloatingWindowsSession();
    }
    return false;
  }, []);

  // Downloads
  const getRecentDownloads = useCallback(async (): Promise<DownloadItem[]> => {
    if (window.electronAPI?.getRecentDownloads) {
      return await window.electronAPI.getRecentDownloads();
    }
    return [];
  }, []);

  const openDownloadedFile = useCallback(async (path: string) => {
    if (window.electronAPI?.openDownloadedFile) {
      return await window.electronAPI.openDownloadedFile(path);
    }
    return { success: false, error: 'Not in Electron' };
  }, []);

  const showInFolder = useCallback(async (path: string) => {
    if (window.electronAPI?.showInFolder) {
      return await window.electronAPI.showInFolder(path);
    }
    return { success: false, error: 'Not in Electron' };
  }, []);

  const onDownloadCompleted = useCallback((callback: (download: DownloadItem) => void) => {
    if (window.electronAPI?.onDownloadCompleted) {
      window.electronAPI.onDownloadCompleted(callback);
    }
  }, []);

  // Window controls
  const minimizeWindow = useCallback(async () => {
    if (window.electronAPI?.minimizeWindow) {
      return await window.electronAPI.minimizeWindow();
    }
    return { success: false };
  }, []);

  const maximizeWindow = useCallback(async () => {
    if (window.electronAPI?.maximizeWindow) {
      return await window.electronAPI.maximizeWindow();
    }
    return { success: false, isMaximized: false };
  }, []);

  const closeMainWindow = useCallback(async () => {
    if (window.electronAPI?.closeMainWindow) {
      return await window.electronAPI.closeMainWindow();
    }
    return { success: false };
  }, []);

  const isMaximized = useCallback(async () => {
    if (window.electronAPI?.isMaximized) {
      return await window.electronAPI.isMaximized();
    }
    return false;
  }, []);

  const onMaximizeChange = useCallback((callback: (isMaximized: boolean) => void) => {
    if (window.electronAPI?.onMaximizeChange) {
      window.electronAPI.onMaximizeChange(callback);
    }
  }, []);

  const saveMainWindowPosition = useCallback(async () => {
    if (window.electronAPI?.saveMainWindowPosition) {
      return await window.electronAPI.saveMainWindowPosition();
    }
    return { success: false };
  }, []);

  return {
    isElectron,
    openExternal,
    createWindow,
    closeWindow,
    registerShortcut,
    unregisterShortcut,
    onShortcutTriggered,
    onWindowPositionChanged,
    onWindowSizeChanged,
    onWindowBoundsChanged,
    onFloatingSavePosition,
    removeAllListeners,
    getSession,
    setSession,
    clearSession,
    getFloatingWindowsSession,
    clearFloatingWindowsSession,
    getRecentDownloads,
    openDownloadedFile,
    showInFolder,
    onDownloadCompleted,
    minimizeWindow,
    maximizeWindow,
    closeMainWindow,
    isMaximized,
    onMaximizeChange,
    saveMainWindowPosition,
  };
}

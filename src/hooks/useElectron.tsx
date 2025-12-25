import { useCallback, useEffect, useState } from 'react';

// Tipos para a API do Electron
interface TextShortcutData {
  command: string;
  expanded_text: string;
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
  // Dados para injeção de scripts nas janelas flutuantes
  textShortcuts?: TextShortcutData[];
  keywords?: KeywordData[];
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

interface ElectronAPI {
  getSession: () => Promise<any>;
  setSession: (session: any) => Promise<boolean>;
  clearSession: () => Promise<boolean>;
  createWindow: (tab: TabData) => Promise<{ success: boolean; windowId?: string; error?: string }>;
  closeWindow: (tabId: string) => Promise<{ success: boolean }>;
  openExternal: (url: string) => Promise<{ success: boolean; error?: string }>;
  registerShortcut: (shortcut: string, tabId: string) => Promise<{ success: boolean; error?: string }>;
  unregisterShortcut: (shortcut: string) => Promise<{ success: boolean }>;
  unregisterAllShortcuts: () => Promise<{ success: boolean }>;
  onShortcutTriggered: (callback: (tabId: string) => void) => void;
  onWindowPositionChanged: (callback: (data: WindowPositionData) => void) => void;
  onWindowSizeChanged: (callback: (data: WindowSizeData) => void) => void;
  removeAllListeners: (channel: string) => void;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}

export type { TabData, WindowPositionData, WindowSizeData };

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
    removeAllListeners,
    getSession,
    setSession,
    clearSession,
  };
}

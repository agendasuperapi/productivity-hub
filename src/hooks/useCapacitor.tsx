import { useCallback } from 'react';

// Capacitor temporariamente desativado para evitar conflitos com Electron
export function useCapacitor() {
  // Sempre retorna false - Capacitor desativado temporariamente
  const isCapacitor = false;
  const platform = 'web' as const;
  const modulesLoaded = true;

  // Fallbacks web para todas as funções
  const copyToClipboard = useCallback(async (text: string): Promise<boolean> => {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (error) {
      console.error('Failed to copy to clipboard:', error);
      return false;
    }
  }, []);

  const readFromClipboard = useCallback(async (): Promise<string | null> => {
    try {
      return await navigator.clipboard.readText();
    } catch (error) {
      console.error('Failed to read from clipboard:', error);
      return null;
    }
  }, []);

  const openInBrowser = useCallback(async (url: string) => {
    window.open(url, '_blank');
  }, []);

  const openInAppBrowser = useCallback(async (url: string) => {
    window.open(url, '_blank');
  }, []);

  const setPreference = useCallback(async (key: string, value: string) => {
    localStorage.setItem(key, value);
  }, []);

  const getPreference = useCallback(async (key: string): Promise<string | null> => {
    return localStorage.getItem(key);
  }, []);

  const removePreference = useCallback(async (key: string) => {
    localStorage.removeItem(key);
  }, []);

  return {
    isCapacitor,
    isTablet: false,
    platform,
    modulesLoaded,
    copyToClipboard,
    readFromClipboard,
    openInBrowser,
    openInAppBrowser,
    setPreference,
    getPreference,
    removePreference
  };
}

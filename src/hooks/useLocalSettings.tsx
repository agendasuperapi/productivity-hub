import { useState, useEffect, useCallback, useSyncExternalStore } from 'react';

export type PdfOpenMode = 'disabled' | 'system' | 'app_window';

export interface LocalSettings {
  shortcuts_bar_position: 'left' | 'right' | 'bottom';
  shortcuts_bar_mode: 'fixed' | 'floating';
  shortcuts_bar_width: number; // For left/right positions
  shortcuts_bar_height: number; // For bottom position
  pdf_open_mode: PdfOpenMode; // How to open downloaded PDFs
}

const STORAGE_KEY = 'local-device-settings';

const defaultLocalSettings: LocalSettings = {
  shortcuts_bar_position: 'bottom',
  shortcuts_bar_mode: 'fixed',
  shortcuts_bar_width: 220,
  shortcuts_bar_height: 120,
  pdf_open_mode: 'disabled',
};

function getStoredSettings(): LocalSettings {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored);
      return {
        ...defaultLocalSettings,
        ...parsed,
      };
    }
  } catch (error) {
    console.error('Error reading local settings:', error);
  }
  return defaultLocalSettings;
}

// Store para sincronização global
let listeners: Set<() => void> = new Set();
let currentSettings: LocalSettings = getStoredSettings();

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot(): LocalSettings {
  return currentSettings;
}

function emitChange() {
  listeners.forEach(listener => listener());
}

function saveSettings(newSettings: LocalSettings) {
  currentSettings = newSettings;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(newSettings));
  } catch (error) {
    console.error('Error saving local settings:', error);
  }
  emitChange();
}

// Escutar mudanças de outras abas/janelas
if (typeof window !== 'undefined') {
  window.addEventListener('storage', (e) => {
    if (e.key === STORAGE_KEY && e.newValue) {
      try {
        currentSettings = { ...defaultLocalSettings, ...JSON.parse(e.newValue) };
        emitChange();
      } catch {
        // Ignore parse errors
      }
    }
  });
}

export function useLocalSettings() {
  const settings = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);

  const updateSettings = useCallback((updates: Partial<LocalSettings>) => {
    const newSettings = { ...currentSettings, ...updates };
    saveSettings(newSettings);
  }, []);

  const resetSettings = useCallback(() => {
    saveSettings(defaultLocalSettings);
  }, []);

  return {
    settings,
    updateSettings,
    resetSettings,
    defaultSettings: defaultLocalSettings,
  };
}

import { useState, useEffect, useCallback } from 'react';

export interface LocalSettings {
  shortcuts_bar_position: 'left' | 'right' | 'bottom';
  shortcuts_bar_mode: 'fixed' | 'floating';
}

const STORAGE_KEY = 'local-device-settings';

const defaultLocalSettings: LocalSettings = {
  shortcuts_bar_position: 'bottom',
  shortcuts_bar_mode: 'fixed',
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

export function useLocalSettings() {
  const [settings, setSettings] = useState<LocalSettings>(getStoredSettings);

  // Sync with localStorage on mount
  useEffect(() => {
    setSettings(getStoredSettings());
  }, []);

  const updateSettings = useCallback((updates: Partial<LocalSettings>) => {
    setSettings(prev => {
      const newSettings = { ...prev, ...updates };
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(newSettings));
      } catch (error) {
        console.error('Error saving local settings:', error);
      }
      return newSettings;
    });
  }, []);

  const resetSettings = useCallback(() => {
    setSettings(defaultLocalSettings);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(defaultLocalSettings));
    } catch (error) {
      console.error('Error resetting local settings:', error);
    }
  }, []);

  return {
    settings,
    updateSettings,
    resetSettings,
    defaultSettings: defaultLocalSettings,
  };
}

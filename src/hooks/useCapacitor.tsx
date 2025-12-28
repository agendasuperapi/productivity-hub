import { useState, useEffect, useCallback } from 'react';

// Dynamic imports for Capacitor - may not be available in all environments
let Capacitor: any = null;
let Clipboard: any = null;
let Browser: any = null;
let Preferences: any = null;

// Try to load Capacitor modules dynamically
const loadCapacitorModules = async () => {
  try {
    const core = await import('@capacitor/core');
    Capacitor = core.Capacitor;
    
    const clipboard = await import('@capacitor/clipboard');
    Clipboard = clipboard.Clipboard;
    
    const browser = await import('@capacitor/browser');
    Browser = browser.Browser;
    
    const preferences = await import('@capacitor/preferences');
    Preferences = preferences.Preferences;
    
    return true;
  } catch (error) {
    console.log('Capacitor modules not available:', error);
    return false;
  }
};

export function useCapacitor() {
  const [isCapacitor, setIsCapacitor] = useState(false);
  const [platform, setPlatform] = useState<'web' | 'android' | 'ios'>('web');
  const [modulesLoaded, setModulesLoaded] = useState(false);

  useEffect(() => {
    const initCapacitor = async () => {
      const loaded = await loadCapacitorModules();
      setModulesLoaded(loaded);
      
      if (loaded && Capacitor) {
        const isNative = Capacitor.isNativePlatform();
        setIsCapacitor(isNative);
        setPlatform(Capacitor.getPlatform() as 'web' | 'android' | 'ios');
      }
    };

    initCapacitor();
  }, []);

  // Clipboard functions
  const copyToClipboard = useCallback(async (text: string): Promise<boolean> => {
    try {
      if (isCapacitor && Clipboard) {
        await Clipboard.write({ string: text });
      } else {
        await navigator.clipboard.writeText(text);
      }
      return true;
    } catch (error) {
      console.error('Failed to copy to clipboard:', error);
      return false;
    }
  }, [isCapacitor]);

  const readFromClipboard = useCallback(async (): Promise<string | null> => {
    try {
      if (isCapacitor && Clipboard) {
        const result = await Clipboard.read();
        return result.value;
      } else {
        return await navigator.clipboard.readText();
      }
    } catch (error) {
      console.error('Failed to read from clipboard:', error);
      return null;
    }
  }, [isCapacitor]);

  // Browser functions
  const openInBrowser = useCallback(async (url: string) => {
    try {
      if (isCapacitor && Browser) {
        await Browser.open({ url, presentationStyle: 'popover' });
      } else {
        window.open(url, '_blank');
      }
    } catch (error) {
      console.error('Failed to open browser:', error);
    }
  }, [isCapacitor]);

  const openInAppBrowser = useCallback(async (url: string) => {
    try {
      if (isCapacitor && Browser) {
        await Browser.open({ 
          url, 
          presentationStyle: 'fullscreen',
          toolbarColor: '#000000'
        });
      } else {
        window.open(url, '_blank');
      }
    } catch (error) {
      console.error('Failed to open in-app browser:', error);
    }
  }, [isCapacitor]);

  // Preferences (storage) functions
  const setPreference = useCallback(async (key: string, value: string) => {
    try {
      if (isCapacitor && Preferences) {
        await Preferences.set({ key, value });
      } else {
        localStorage.setItem(key, value);
      }
    } catch (error) {
      console.error('Failed to set preference:', error);
    }
  }, [isCapacitor]);

  const getPreference = useCallback(async (key: string): Promise<string | null> => {
    try {
      if (isCapacitor && Preferences) {
        const result = await Preferences.get({ key });
        return result.value;
      } else {
        return localStorage.getItem(key);
      }
    } catch (error) {
      console.error('Failed to get preference:', error);
      return null;
    }
  }, [isCapacitor]);

  const removePreference = useCallback(async (key: string) => {
    try {
      if (isCapacitor && Preferences) {
        await Preferences.remove({ key });
      } else {
        localStorage.removeItem(key);
      }
    } catch (error) {
      console.error('Failed to remove preference:', error);
    }
  }, [isCapacitor]);

  return {
    isCapacitor,
    isTablet: isCapacitor,
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

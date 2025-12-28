import { useState, useEffect, useCallback, useRef } from 'react';

interface CapacitorModules {
  Capacitor: any;
  Clipboard: any;
  Browser: any;
  Preferences: any;
}

export function useCapacitor() {
  const [isCapacitor, setIsCapacitor] = useState(false);
  const [platform, setPlatform] = useState<'web' | 'android' | 'ios'>('web');
  const [modulesLoaded, setModulesLoaded] = useState(false);
  const modulesRef = useRef<CapacitorModules | null>(null);

  useEffect(() => {
    let mounted = true;

    const loadCapacitorModules = async () => {
      try {
        const [core, clipboard, browser, preferences] = await Promise.all([
          import('@capacitor/core'),
          import('@capacitor/clipboard'),
          import('@capacitor/browser'),
          import('@capacitor/preferences')
        ]);

        if (!mounted) return;

        modulesRef.current = {
          Capacitor: core.Capacitor,
          Clipboard: clipboard.Clipboard,
          Browser: browser.Browser,
          Preferences: preferences.Preferences
        };

        const isNative = core.Capacitor.isNativePlatform();
        setIsCapacitor(isNative);
        setPlatform(core.Capacitor.getPlatform() as 'web' | 'android' | 'ios');
        setModulesLoaded(true);
      } catch (error) {
        console.log('Capacitor modules not available, using web fallbacks');
        if (mounted) {
          setModulesLoaded(true);
        }
      }
    };

    loadCapacitorModules();

    return () => {
      mounted = false;
    };
  }, []);

  // Clipboard functions
  const copyToClipboard = useCallback(async (text: string): Promise<boolean> => {
    try {
      if (isCapacitor && modulesRef.current?.Clipboard) {
        await modulesRef.current.Clipboard.write({ string: text });
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
      if (isCapacitor && modulesRef.current?.Clipboard) {
        const result = await modulesRef.current.Clipboard.read();
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
      if (isCapacitor && modulesRef.current?.Browser) {
        await modulesRef.current.Browser.open({ url, presentationStyle: 'popover' });
      } else {
        window.open(url, '_blank');
      }
    } catch (error) {
      console.error('Failed to open browser:', error);
    }
  }, [isCapacitor]);

  const openInAppBrowser = useCallback(async (url: string) => {
    try {
      if (isCapacitor && modulesRef.current?.Browser) {
        await modulesRef.current.Browser.open({ 
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
      if (isCapacitor && modulesRef.current?.Preferences) {
        await modulesRef.current.Preferences.set({ key, value });
      } else {
        localStorage.setItem(key, value);
      }
    } catch (error) {
      console.error('Failed to set preference:', error);
    }
  }, [isCapacitor]);

  const getPreference = useCallback(async (key: string): Promise<string | null> => {
    try {
      if (isCapacitor && modulesRef.current?.Preferences) {
        const result = await modulesRef.current.Preferences.get({ key });
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
      if (isCapacitor && modulesRef.current?.Preferences) {
        await modulesRef.current.Preferences.remove({ key });
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

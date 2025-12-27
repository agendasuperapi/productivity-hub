import { useState, useEffect, useCallback } from 'react';
import { Capacitor } from '@capacitor/core';
import { Clipboard } from '@capacitor/clipboard';
import { Browser } from '@capacitor/browser';
import { Preferences } from '@capacitor/preferences';

export function useCapacitor() {
  const [isCapacitor, setIsCapacitor] = useState(false);
  const [platform, setPlatform] = useState<'web' | 'android' | 'ios'>('web');

  useEffect(() => {
    const checkPlatform = () => {
      const isNative = Capacitor.isNativePlatform();
      setIsCapacitor(isNative);
      setPlatform(Capacitor.getPlatform() as 'web' | 'android' | 'ios');
    };

    checkPlatform();
  }, []);

  // Clipboard functions
  const copyToClipboard = useCallback(async (text: string): Promise<boolean> => {
    try {
      if (isCapacitor) {
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
      if (isCapacitor) {
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
      if (isCapacitor) {
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
      if (isCapacitor) {
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
      if (isCapacitor) {
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
      if (isCapacitor) {
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
      if (isCapacitor) {
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
    isTablet: isCapacitor, // Assume tablet if running in Capacitor
    platform,
    copyToClipboard,
    readFromClipboard,
    openInBrowser,
    openInAppBrowser,
    setPreference,
    getPreference,
    removePreference
  };
}

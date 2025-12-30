import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { Json } from '@/integrations/supabase/types';

export interface UserSettings {
  browser: {
    auto_restore_session: boolean;
    save_window_positions: boolean;
    confirm_on_close: boolean;
  };
  shortcuts: {
    prefix: string;
  };
  notifications: {
    sound_enabled: boolean;
    toast_position: 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right';
  };
  interface: {
    density: 'compact' | 'normal' | 'comfortable';
    animations_enabled: boolean;
    sidebar_collapsed: boolean;
    shortcuts_bar_position: 'left' | 'right' | 'bottom';
  };
  integrations: {
    webhook_url: string;
  };
}

const defaultSettings: UserSettings = {
  browser: {
    auto_restore_session: true,
    save_window_positions: true,
    confirm_on_close: true,
  },
  shortcuts: {
    prefix: '/',
  },
  notifications: {
    sound_enabled: false,
    toast_position: 'bottom-right',
  },
  interface: {
    density: 'normal',
    animations_enabled: true,
    sidebar_collapsed: false,
    shortcuts_bar_position: 'bottom',
  },
  integrations: {
    webhook_url: '',
  },
};

// Helper to safely merge settings with defaults
function mergeWithDefaults(saved: Partial<UserSettings> | null): UserSettings {
  if (!saved) return defaultSettings;
  
  return {
    browser: {
      ...defaultSettings.browser,
      ...(saved.browser || {}),
    },
    shortcuts: {
      ...defaultSettings.shortcuts,
      ...(saved.shortcuts || {}),
    },
    notifications: {
      ...defaultSettings.notifications,
      ...(saved.notifications || {}),
    },
    interface: {
      ...defaultSettings.interface,
      ...(saved.interface || {}),
    },
    integrations: {
      ...defaultSettings.integrations,
      ...(saved.integrations || {}),
    },
  };
}

export function useUserSettings() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [settings, setSettings] = useState<UserSettings>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Load settings from database
  useEffect(() => {
    async function loadSettings() {
      if (!user) {
        setLoading(false);
        return;
      }

      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('settings')
          .eq('user_id', user.id)
          .single();

        if (error) throw error;

        const savedSettings = data?.settings as Partial<UserSettings> | null;
        const merged = mergeWithDefaults(savedSettings);
        setSettings(merged);
        
        // Apply interface settings immediately
        applyInterfaceSettings(merged.interface);
        
        // Also save to localStorage for quick access
        localStorage.setItem('user-settings', JSON.stringify(merged));
      } catch (error) {
        console.error('Error loading settings:', error);
        // Try to load from localStorage as fallback
        const cached = localStorage.getItem('user-settings');
        if (cached) {
          try {
            const parsed = JSON.parse(cached);
            const merged = mergeWithDefaults(parsed);
            setSettings(merged);
            applyInterfaceSettings(merged.interface);
          } catch {
            // Use defaults
          }
        }
      } finally {
        setLoading(false);
      }
    }

    loadSettings();
  }, [user]);

  // Apply interface settings to DOM
  const applyInterfaceSettings = useCallback((interfaceSettings: UserSettings['interface']) => {
    const root = document.documentElement;
    
    // Remove existing classes
    root.classList.remove('density-compact', 'density-normal', 'density-comfortable');
    root.classList.remove('no-animations');
    
    // Apply density
    root.classList.add(`density-${interfaceSettings.density}`);
    
    // Apply animations setting
    if (!interfaceSettings.animations_enabled) {
      root.classList.add('no-animations');
    }
  }, []);

  // Save settings to database
  const saveSettings = useCallback(async (newSettings: UserSettings) => {
    if (!user) return;

    setSaving(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ settings: newSettings as unknown as Json })
        .eq('user_id', user.id);

      if (error) throw error;

      // Update localStorage
      localStorage.setItem('user-settings', JSON.stringify(newSettings));
      
      toast({ title: 'Configurações salvas!' });
    } catch (error) {
      console.error('Error saving settings:', error);
      toast({ 
        title: 'Erro ao salvar configurações', 
        variant: 'destructive' 
      });
    } finally {
      setSaving(false);
    }
  }, [user, toast]);

  // Update a specific section of settings
  const updateSettings = useCallback(<K extends keyof UserSettings>(
    section: K,
    updates: Partial<UserSettings[K]>
  ) => {
    setSettings(prev => {
      const newSettings = {
        ...prev,
        [section]: {
          ...prev[section],
          ...updates,
        },
      };

      // Apply interface settings immediately if that section was updated
      if (section === 'interface') {
        applyInterfaceSettings(newSettings.interface);
      }

      // Save to database (debounced would be better in production)
      saveSettings(newSettings);

      return newSettings;
    });
  }, [applyInterfaceSettings, saveSettings]);

  // Reset settings to defaults
  const resetSettings = useCallback(() => {
    setSettings(defaultSettings);
    applyInterfaceSettings(defaultSettings.interface);
    saveSettings(defaultSettings);
    toast({ title: 'Configurações restauradas para o padrão' });
  }, [applyInterfaceSettings, saveSettings, toast]);

  return {
    settings,
    loading,
    saving,
    updateSettings,
    resetSettings,
    defaultSettings,
  };
}

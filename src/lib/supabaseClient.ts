// Custom Supabase client wrapper that supports multiple concurrent sessions
// Each device gets its own unique storage key, preventing session conflicts

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/integrations/supabase/types';
import { getStorageKeyForDevice, getDeviceId } from './deviceId';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

let supabaseInstance: SupabaseClient<Database> | null = null;

export function getSupabaseClient(): SupabaseClient<Database> {
  if (!supabaseInstance) {
    const storageKey = getStorageKeyForDevice();
    
    supabaseInstance = createClient<Database>(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
      auth: {
        storage: localStorage,
        storageKey: storageKey,
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
    
    console.log('[Supabase] Client initialized with device-specific storage key:', storageKey);
    console.log('[Supabase] Device ID:', getDeviceId());
  }
  
  return supabaseInstance;
}

// Export a singleton instance - use this instead of the auto-generated client
// to support multiple concurrent sessions across devices
export const supabaseWithDevice = getSupabaseClient();

import { createClient } from '@supabase/supabase-js';
import Store from 'electron-store';

// Type for store with methods
interface StoreWithMethods {
  get(key: string): unknown;
  set(key: string, value: unknown): void;
  delete(key: string): void;
}

// Storage adapter para Electron usando electron-store
class ElectronStorage {
  private store: StoreWithMethods;

  constructor() {
    this.store = new Store({
      name: 'supabase-auth',
      encryptionKey: 'supabase-auth-key',
    }) as unknown as StoreWithMethods;
  }

  getItem(key: string): string | null {
    const value = this.store.get(key) as string | undefined;
    return value ?? null;
  }

  setItem(key: string, value: string): void {
    this.store.set(key, value);
  }

  removeItem(key: string): void {
    this.store.delete(key);
  }
}

const SUPABASE_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplZ2pydmdscmpuaHVreHFreG9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MTA4NTAsImV4cCI6MjA4MjA4Njg1MH0.mhrSxMboDPKan4ez71_f5qjwUhxGMCq61GXvuTo93MU';

const storage = new ElectronStorage();

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: {
      getItem: (key: string) => storage.getItem(key),
      setItem: (key: string, value: string) => storage.setItem(key, value),
      removeItem: (key: string) => storage.removeItem(key),
    },
    persistSession: true,
    autoRefreshToken: true,
  },
});

export interface Tab {
  id: string;
  name: string;
  url: string;
  icon?: string;
  color?: string;
  zoom?: number;
  open_as_window?: boolean;
  shortcut?: string;
}

export interface UserConfig {
  tabs: Tab[];
  layout?: 'single' | 'split-2x1' | 'split-1x2';
}

const API_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co/functions/v1/get-user-config';

export async function fetchUserConfig(): Promise<UserConfig> {
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session?.access_token) {
    throw new Error('Usuário não autenticado');
  }

  const response = await fetch(API_URL, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const errorData = await response.json() as { error?: string };
    throw new Error(errorData.error || 'Erro ao buscar configurações');
  }

  return await response.json() as UserConfig;
}

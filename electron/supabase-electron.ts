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

export interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  tabs?: Tab[];
}

export interface UserConfig {
  tab_groups?: TabGroup[];
  tabs?: Tab[];
  text_shortcuts?: any[];
  split_layouts?: any[];
  layout?: 'single' | 'split-2x1' | 'split-1x2';
}

const API_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co/functions/v1/get-user-config';

export async function fetchUserConfig(providedSession?: { access_token: string; expires_at?: number }): Promise<UserConfig> {
  console.log('[Supabase] Iniciando fetchUserConfig...');
  
  try {
    let accessToken: string;
    let expiresAt: number;
    let isNewSession = false;

    // Se uma sessão foi fornecida (ex: logo após login), usar ela diretamente
    if (providedSession?.access_token) {
      console.log('[Supabase] Usando sessão fornecida diretamente');
      accessToken = providedSession.access_token;
      expiresAt = providedSession.expires_at || 0;
      isNewSession = true;
    } else {
      // Caso contrário, obter sessão do storage
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError) {
        console.error('[Supabase] Erro ao obter sessão:', sessionError);
        throw new Error(`Erro de sessão: ${sessionError.message}`);
      }
      
      if (!session?.access_token) {
        console.error('[Supabase] Sessão inválida ou token ausente');
        throw new Error('Usuário não autenticado - faça login novamente');
      }

      accessToken = session.access_token;
      expiresAt = session.expires_at || 0;

      // Verificar se o token está próximo de expirar (menos de 60 segundos)
      const now = Math.floor(Date.now() / 1000);
      const timeUntilExpiry = expiresAt - now;
      
      // Só fazer refresh se o token estiver próximo de expirar
      if (timeUntilExpiry < 60 && timeUntilExpiry > 0) {
        console.log('[Supabase] Token próximo de expirar, tentando refresh...');
        const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();
        
        if (!refreshError && refreshData.session) {
          accessToken = refreshData.session.access_token;
          expiresAt = refreshData.session.expires_at || 0;
          console.log('[Supabase] Token atualizado com sucesso');
        } else {
          console.warn('[Supabase] Refresh falhou, usando token atual:', refreshError?.message);
        }
      }
    }

    // Pequeno delay para garantir que o token seja propagado (clock skew)
    if (isNewSession) {
      console.log('[Supabase] Aguardando propagação do token...');
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    console.log('[Supabase] Token obtido, expira em:', new Date(expiresAt * 1000).toISOString());
    console.log('[Supabase] Chamando API:', API_URL);

    const response = await fetch(API_URL, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY,
      },
    });

    console.log('[Supabase] Response status:', response.status, response.statusText);

    if (!response.ok) {
      let errorMessage = `HTTP ${response.status}: ${response.statusText}`;
      try {
        const errorData = await response.json() as { error?: string; message?: string };
        errorMessage = errorData.error || errorData.message || errorMessage;
      } catch {
        // Não conseguiu parsear JSON, usar mensagem padrão
      }
      console.error('[Supabase] Erro na resposta:', errorMessage);
      
      // Se for erro de JWT, sugerir novo login
      if (errorMessage.includes('JWT') || response.status === 401) {
        throw new Error('Sessão expirada - faça login novamente');
      }
      
      throw new Error(errorMessage);
    }

    const config = await response.json() as UserConfig;
    console.log('[Supabase] Configurações carregadas com sucesso:', {
      grupos: config.tab_groups?.length || 0,
      tabs: config.tabs?.length || 0
    });
    
    return config;
  } catch (error: any) {
    console.error('[Supabase] Erro em fetchUserConfig:', error);
    
    // Melhorar mensagem de erro para erros de rede
    if (error.name === 'TypeError' && error.message.includes('fetch')) {
      throw new Error('Erro de conexão - verifique sua internet');
    }
    
    throw error;
  }
}

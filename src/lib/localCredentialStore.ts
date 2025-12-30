// Serviço de armazenamento local para credenciais (via electron-store)
// Permite acesso offline e resposta instantânea

export interface LocalCredential {
  id: string;
  domain: string;
  username: string;
  encrypted_password: string;
  site_name?: string | null;
  created_at: string;
  updated_at: string;
  synced: boolean; // Flag para saber se está sincronizado com Supabase
}

// Verifica se estamos no Electron (via any para evitar conflito de tipos)
const getElectronAPI = (): Record<string, unknown> | null => {
  if (typeof window !== 'undefined') {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = window as any;
    if (w.electronAPI) {
      return w.electronAPI as Record<string, unknown>;
    }
  }
  return null;
};

// API para gerenciar credenciais locais via Electron
export const localCredentialStore = {
  // Salvar ou atualizar credencial local
  save: async (credential: LocalCredential): Promise<boolean> => {
    const api = getElectronAPI();
    if (!api || typeof api.saveLocalCredential !== 'function') return false;
    try {
      const result = await (api.saveLocalCredential as (c: LocalCredential) => Promise<{ success: boolean }>)(credential);
      return result?.success ?? false;
    } catch (error) {
      console.error('[LocalCredStore] Erro ao salvar:', error);
      return false;
    }
  },

  // Buscar credenciais por domínio
  getByDomain: async (domain: string): Promise<LocalCredential[]> => {
    const api = getElectronAPI();
    if (!api || typeof api.getLocalCredentialsByDomain !== 'function') return [];
    try {
      return await (api.getLocalCredentialsByDomain as (d: string) => Promise<LocalCredential[]>)(domain) ?? [];
    } catch (error) {
      console.error('[LocalCredStore] Erro ao buscar por domínio:', error);
      return [];
    }
  },

  // Buscar todas as credenciais
  getAll: async (): Promise<LocalCredential[]> => {
    const api = getElectronAPI();
    if (!api || typeof api.getAllLocalCredentials !== 'function') return [];
    try {
      return await (api.getAllLocalCredentials as () => Promise<LocalCredential[]>)() ?? [];
    } catch (error) {
      console.error('[LocalCredStore] Erro ao buscar todas:', error);
      return [];
    }
  },

  // Remover credencial
  delete: async (id: string): Promise<boolean> => {
    const api = getElectronAPI();
    if (!api || typeof api.deleteLocalCredential !== 'function') return false;
    try {
      const result = await (api.deleteLocalCredential as (id: string) => Promise<{ success: boolean }>)(id);
      return result?.success ?? false;
    } catch (error) {
      console.error('[LocalCredStore] Erro ao deletar:', error);
      return false;
    }
  },

  // Marcar como sincronizado
  markAsSynced: async (id: string): Promise<boolean> => {
    const api = getElectronAPI();
    if (!api || typeof api.markLocalCredentialSynced !== 'function') return false;
    try {
      const result = await (api.markLocalCredentialSynced as (id: string) => Promise<{ success: boolean }>)(id);
      return result?.success ?? false;
    } catch (error) {
      console.error('[LocalCredStore] Erro ao marcar sincronizado:', error);
      return false;
    }
  },

  // Buscar não sincronizados
  getUnsynced: async (): Promise<LocalCredential[]> => {
    const api = getElectronAPI();
    if (!api || typeof api.getUnsyncedLocalCredentials !== 'function') return [];
    try {
      return await (api.getUnsyncedLocalCredentials as () => Promise<LocalCredential[]>)() ?? [];
    } catch (error) {
      console.error('[LocalCredStore] Erro ao buscar não sincronizados:', error);
      return [];
    }
  },

  // Sincronizar do Supabase para local
  syncFromSupabase: async (credentials: LocalCredential[]): Promise<boolean> => {
    const api = getElectronAPI();
    if (!api || typeof api.syncCredentialsFromSupabase !== 'function') return false;
    try {
      const result = await (api.syncCredentialsFromSupabase as (c: LocalCredential[]) => Promise<{ success: boolean }>)(credentials);
      return result?.success ?? false;
    } catch (error) {
      console.error('[LocalCredStore] Erro ao sincronizar do Supabase:', error);
      return false;
    }
  },

  // Verificar se está no Electron
  isAvailable: (): boolean => {
    const api = getElectronAPI();
    return api !== null && typeof api.saveLocalCredential === 'function';
  }
};

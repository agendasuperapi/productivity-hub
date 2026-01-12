import { useState, useEffect, useCallback } from 'react';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';

export interface BlockedDomain {
  id: string;
  domain: string;
  created_at: string;
}

// Helper para acessar API do Electron
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

export function useBlockedDomains() {
  const { user } = useAuth();
  const [blockedDomains, setBlockedDomains] = useState<BlockedDomain[]>([]);
  const [loading, setLoading] = useState(true);

  // Sincronizar domínios do Supabase para o cache local
  const syncToLocal = useCallback(async (domains: BlockedDomain[]) => {
    const api = getElectronAPI();
    if (api && typeof api.syncBlockedDomainsFromSupabase === 'function') {
      const domainStrings = domains.map(d => d.domain);
      await (api.syncBlockedDomainsFromSupabase as (d: string[]) => Promise<{ success: boolean }>)(domainStrings);
    }
  }, []);

  const fetchBlockedDomains = useCallback(async () => {
    if (!user) {
      setBlockedDomains([]);
      setLoading(false);
      return;
    }

    try {
      const { data, error } = await supabase
        .from('blocked_credential_domains')
        .select('*')
        .eq('user_id', user.id)
        .order('domain', { ascending: true });

      if (error) throw error;
      const domains = data || [];
      setBlockedDomains(domains);
      
      // Sincronizar para cache local (Electron)
      await syncToLocal(domains);
    } catch (error) {
      console.error('Erro ao buscar domínios bloqueados:', error);
      
      // Fallback: tentar buscar do cache local
      const api = getElectronAPI();
      if (api && typeof api.getLocalBlockedDomains === 'function') {
        try {
          const localDomains = await (api.getLocalBlockedDomains as () => Promise<string[]>)();
          // Converter strings para objetos BlockedDomain
          const now = new Date().toISOString();
          const fallbackDomains = localDomains.map((domain, index) => ({
            id: `local-${index}`,
            domain,
            created_at: now,
          }));
          setBlockedDomains(fallbackDomains);
        } catch (localError) {
          console.error('Erro ao buscar domínios locais:', localError);
        }
      }
    } finally {
      setLoading(false);
    }
  }, [user, syncToLocal]);

  useEffect(() => {
    fetchBlockedDomains();
  }, [fetchBlockedDomains]);

  const blockDomain = useCallback(async (domain: string): Promise<boolean> => {
    if (!user) return false;

    const normalizedDomain = domain.toLowerCase();

    // 1. Salvar localmente primeiro (resposta instantânea)
    const api = getElectronAPI();
    if (api && typeof api.addLocalBlockedDomain === 'function') {
      await (api.addLocalBlockedDomain as (d: string) => Promise<{ success: boolean }>)(normalizedDomain);
    }

    // 2. Salvar no Supabase
    try {
      const { error } = await supabase
        .from('blocked_credential_domains')
        .insert({
          user_id: user.id,
          domain: normalizedDomain,
        });

      if (error) {
        // Ignorar erro de duplicata (constraint unique)
        if (error.code === '23505') {
          return true;
        }
        throw error;
      }

      await fetchBlockedDomains();
      return true;
    } catch (error) {
      console.error('Erro ao bloquear domínio:', error);
      // Domínio já foi salvo localmente, então não mostrar erro
      return true;
    }
  }, [user, fetchBlockedDomains]);

  const unblockDomain = useCallback(async (id: string): Promise<boolean> => {
    if (!user) return false;

    // Encontrar o domínio para remover localmente também
    const domainToRemove = blockedDomains.find(d => d.id === id);

    // 1. Remover do cache local
    if (domainToRemove) {
      const api = getElectronAPI();
      if (api && typeof api.removeLocalBlockedDomain === 'function') {
        await (api.removeLocalBlockedDomain as (d: string) => Promise<{ success: boolean }>)(domainToRemove.domain);
      }
    }

    // 2. Remover do Supabase (somente se não for um ID local)
    if (!id.startsWith('local-')) {
      try {
        const { error } = await supabase
          .from('blocked_credential_domains')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

        if (error) throw error;
      } catch (error) {
        console.error('Erro ao desbloquear domínio:', error);
        toast.error('Erro ao desbloquear domínio');
        return false;
      }
    }

    setBlockedDomains(prev => prev.filter(d => d.id !== id));
    toast.success('Domínio desbloqueado');
    return true;
  }, [user, blockedDomains]);

  const isBlocked = useCallback((domain: string): boolean => {
    const normalizedDomain = domain.toLowerCase();
    return blockedDomains.some(d => d.domain === normalizedDomain);
  }, [blockedDomains]);

  // Verificação rápida via cache local (para uso no Electron)
  const isBlockedLocal = useCallback(async (domain: string): Promise<boolean> => {
    const api = getElectronAPI();
    if (api && typeof api.isLocalDomainBlocked === 'function') {
      return await (api.isLocalDomainBlocked as (d: string) => Promise<boolean>)(domain);
    }
    // Fallback para verificação em memória
    return isBlocked(domain);
  }, [isBlocked]);

  return {
    blockedDomains,
    loading,
    blockDomain,
    unblockDomain,
    isBlocked,
    isBlockedLocal,
    refreshBlockedDomains: fetchBlockedDomains,
  };
}

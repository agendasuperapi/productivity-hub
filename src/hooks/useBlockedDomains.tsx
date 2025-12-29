import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';

export interface BlockedDomain {
  id: string;
  domain: string;
  created_at: string;
}

export function useBlockedDomains() {
  const { user } = useAuth();
  const [blockedDomains, setBlockedDomains] = useState<BlockedDomain[]>([]);
  const [loading, setLoading] = useState(true);

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
      setBlockedDomains(data || []);
    } catch (error) {
      console.error('Erro ao buscar domínios bloqueados:', error);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchBlockedDomains();
  }, [fetchBlockedDomains]);

  const blockDomain = useCallback(async (domain: string): Promise<boolean> => {
    if (!user) return false;

    try {
      const { error } = await supabase
        .from('blocked_credential_domains')
        .insert({
          user_id: user.id,
          domain: domain.toLowerCase(),
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
      toast.error('Erro ao bloquear domínio');
      return false;
    }
  }, [user, fetchBlockedDomains]);

  const unblockDomain = useCallback(async (id: string): Promise<boolean> => {
    if (!user) return false;

    try {
      const { error } = await supabase
        .from('blocked_credential_domains')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);

      if (error) throw error;

      setBlockedDomains(prev => prev.filter(d => d.id !== id));
      toast.success('Domínio desbloqueado');
      return true;
    } catch (error) {
      console.error('Erro ao desbloquear domínio:', error);
      toast.error('Erro ao desbloquear domínio');
      return false;
    }
  }, [user]);

  const isBlocked = useCallback((domain: string): boolean => {
    const normalizedDomain = domain.toLowerCase();
    return blockedDomains.some(d => d.domain === normalizedDomain);
  }, [blockedDomains]);

  return {
    blockedDomains,
    loading,
    blockDomain,
    unblockDomain,
    isBlocked,
    refreshBlockedDomains: fetchBlockedDomains,
  };
}

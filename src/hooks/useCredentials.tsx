import { useState, useEffect, useCallback, useRef } from 'react';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/hooks/useAuth';
import { encryptPassword, decryptPassword, extractDomain } from '@/lib/crypto';
import { localCredentialStore, LocalCredential } from '@/lib/localCredentialStore';
import { toast } from 'sonner';

export interface SavedCredential {
  id: string;
  user_id: string;
  domain: string;
  site_name: string | null;
  username: string;
  encrypted_password: string;
  created_at: string;
  updated_at: string;
  synced?: boolean; // Indica se está sincronizado com Supabase
}

export interface DecryptedCredential extends Omit<SavedCredential, 'encrypted_password'> {
  password: string;
}

const SYNC_INTERVAL = 30000; // 30 segundos

export function useCredentials() {
  const { user } = useAuth();
  const [credentials, setCredentials] = useState<SavedCredential[]>([]);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const syncIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const isElectron = localCredentialStore.isAvailable();

  // Buscar credenciais - primeiro local, depois Supabase
  const fetchCredentials = useCallback(async () => {
    if (!user) {
      setCredentials([]);
      setLoading(false);
      return;
    }

    try {
      // Se estamos no Electron, buscar local primeiro (resposta instantânea)
      if (isElectron) {
        const localCreds = await localCredentialStore.getAll();
        if (localCreds.length > 0) {
          setCredentials(localCreds.map(c => ({
            ...c,
            user_id: user.id,
            site_name: c.site_name ?? null,
            synced: c.synced
          })));
          setLoading(false);
        }
      }

      // Buscar do Supabase (fonte de verdade)
      const { data, error } = await supabase
        .from('saved_credentials')
        .select('*')
        .eq('user_id', user.id)
        .order('domain', { ascending: true });

      if (error) throw error;

      const supabaseCredentials: SavedCredential[] = (data || []).map(c => ({
        ...c,
        synced: true
      }));

      // Se estamos no Electron, sincronizar para local
      if (isElectron && data) {
        const localFormat: LocalCredential[] = data.map(c => ({
          id: c.id,
          domain: c.domain,
          username: c.username,
          encrypted_password: c.encrypted_password,
          site_name: c.site_name,
          created_at: c.created_at,
          updated_at: c.updated_at,
          synced: true
        }));
        await localCredentialStore.syncFromSupabase(localFormat);
        
        // Verificar se há credenciais locais não sincronizadas
        const unsynced = await localCredentialStore.getUnsynced();
        if (unsynced.length > 0) {
          // Mesclar não sincronizadas
          const merged = [...supabaseCredentials];
          unsynced.forEach(localCred => {
            const exists = merged.some(c => c.domain === localCred.domain && c.username === localCred.username);
            if (!exists) {
              merged.push({
                ...localCred,
                user_id: user.id,
                site_name: localCred.site_name ?? null,
                synced: false
              });
            }
          });
          setCredentials(merged);
        } else {
          setCredentials(supabaseCredentials);
        }
      } else {
        setCredentials(supabaseCredentials);
      }
    } catch (error) {
      console.error('Error fetching credentials:', error);
      // Se falhou no Supabase mas temos dados locais, usar eles
      if (isElectron) {
        const localCreds = await localCredentialStore.getAll();
        if (localCreds.length > 0) {
          setCredentials(localCreds.map(c => ({
            ...c,
            user_id: user?.id || '',
            site_name: c.site_name ?? null,
            synced: c.synced
          })));
        }
      } else {
        toast.error('Erro ao carregar credenciais');
      }
    } finally {
      setLoading(false);
    }
  }, [user, isElectron]);

  // Sincronizar credenciais não sincronizadas com Supabase
  const syncUnsynced = useCallback(async () => {
    if (!user || !isElectron || syncing) return;

    try {
      const unsynced = await localCredentialStore.getUnsynced();
      if (unsynced.length === 0) return;

      setSyncing(true);
      console.log('[useCredentials] Sincronizando', unsynced.length, 'credenciais...');

      for (const cred of unsynced) {
        try {
          // Verificar se já existe no Supabase
          const { data: existing } = await supabase
            .from('saved_credentials')
            .select('id')
            .eq('user_id', user.id)
            .eq('domain', cred.domain)
            .eq('username', cred.username)
            .maybeSingle();

          if (existing) {
            // Atualizar existente
            await supabase
              .from('saved_credentials')
              .update({
                encrypted_password: cred.encrypted_password,
                site_name: cred.site_name,
                updated_at: new Date().toISOString()
              })
              .eq('id', existing.id);
          } else {
            // Inserir novo
            await supabase
              .from('saved_credentials')
              .insert({
                id: cred.id,
                user_id: user.id,
                domain: cred.domain,
                username: cred.username,
                encrypted_password: cred.encrypted_password,
                site_name: cred.site_name
              });
          }

          // Marcar como sincronizado localmente
          await localCredentialStore.markAsSynced(cred.id);
        } catch (err) {
          console.error('[useCredentials] Erro ao sincronizar credencial:', cred.id, err);
        }
      }

      console.log('[useCredentials] Sincronização concluída');
    } catch (error) {
      console.error('[useCredentials] Erro na sincronização:', error);
    } finally {
      setSyncing(false);
    }
  }, [user, isElectron, syncing]);

  useEffect(() => {
    fetchCredentials();
  }, [fetchCredentials]);

  // Sincronização periódica
  useEffect(() => {
    if (!user || !isElectron) return;

    // Sincronizar imediatamente ao iniciar
    syncUnsynced();

    // Configurar intervalo de sincronização
    syncIntervalRef.current = setInterval(syncUnsynced, SYNC_INTERVAL);

    return () => {
      if (syncIntervalRef.current) {
        clearInterval(syncIntervalRef.current);
      }
    };
  }, [user, isElectron, syncUnsynced]);

  const saveCredential = useCallback(async (
    url: string,
    username: string,
    password: string,
    siteName?: string
  ): Promise<boolean> => {
    if (!user) {
      console.error('[useCredentials] Sem usuário logado para salvar credenciais');
      return false;
    }

    try {
      console.log('[useCredentials] Salvando credencial para:', url, username);
      const domain = extractDomain(url);
      const encryptedPwd = await encryptPassword(password, user.id);
      const now = new Date().toISOString();
      const credId = crypto.randomUUID();

      // Se estamos no Electron, salvar localmente primeiro (resposta instantânea)
      if (isElectron) {
        const localCred: LocalCredential = {
          id: credId,
          domain,
          username,
          encrypted_password: encryptedPwd,
          site_name: siteName || domain,
          created_at: now,
          updated_at: now,
          synced: false
        };
        await localCredentialStore.save(localCred);
        
        // Atualizar estado imediatamente
        setCredentials(prev => {
          const exists = prev.findIndex(c => c.domain === domain && c.username === username);
          const credWithUserId: SavedCredential = { 
            ...localCred, 
            user_id: user.id,
            site_name: localCred.site_name ?? null
          };
          if (exists >= 0) {
            const updated = [...prev];
            updated[exists] = credWithUserId;
            return updated;
          }
          return [...prev, credWithUserId];
        });
        
        toast.success('Credenciais salvas');
      }

      // Tentar salvar no Supabase (em background se Electron)
      try {
        const { data: existing } = await supabase
          .from('saved_credentials')
          .select('id')
          .eq('user_id', user.id)
          .eq('domain', domain)
          .eq('username', username)
          .maybeSingle();

        if (existing) {
          await supabase
            .from('saved_credentials')
            .update({
              encrypted_password: encryptedPwd,
              site_name: siteName || domain,
              updated_at: now
            })
            .eq('id', existing.id);
          
          if (isElectron) {
            await localCredentialStore.markAsSynced(existing.id);
          }
        } else {
          await supabase
            .from('saved_credentials')
            .insert({
              id: credId,
              user_id: user.id,
              domain,
              site_name: siteName || domain,
              username,
              encrypted_password: encryptedPwd
            });
          
          if (isElectron) {
            await localCredentialStore.markAsSynced(credId);
          }
        }

        if (!isElectron) {
          toast.success('Credenciais salvas');
          await fetchCredentials();
        } else {
          // Atualizar estado para mostrar como sincronizado
          setCredentials(prev => prev.map(c => 
            c.id === credId ? { ...c, synced: true } : c
          ));
        }
      } catch (supabaseError) {
        console.error('[useCredentials] Erro ao salvar no Supabase:', supabaseError);
        if (!isElectron) {
          toast.error('Erro ao salvar credenciais');
          return false;
        }
        // Se estamos no Electron, a credencial foi salva localmente, então é sucesso
      }

      return true;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Erro desconhecido';
      console.error('[useCredentials] Erro ao salvar credencial:', message);
      toast.error('Erro ao salvar credenciais: ' + message);
      return false;
    }
  }, [user, fetchCredentials, isElectron]);

  const getCredentialForDomain = useCallback(async (url: string): Promise<DecryptedCredential | null> => {
    if (!user) return null;

    try {
      const domain = extractDomain(url);
      
      // Se estamos no Electron, buscar local primeiro (mais rápido)
      if (isElectron) {
        const localCreds = await localCredentialStore.getByDomain(domain);
        if (localCreds.length > 0) {
          const cred = localCreds[0];
          const password = await decryptPassword(cred.encrypted_password, user.id);
          return {
            id: cred.id,
            user_id: user.id,
            domain: cred.domain,
            site_name: cred.site_name ?? null,
            username: cred.username,
            password,
            created_at: cred.created_at,
            updated_at: cred.updated_at
          };
        }
      }

      // Fallback para Supabase
      const { data, error } = await supabase
        .from('saved_credentials')
        .select('*')
        .eq('user_id', user.id)
        .eq('domain', domain)
        .maybeSingle();

      if (error || !data) return null;

      const password = await decryptPassword(data.encrypted_password, user.id);
      
      return {
        id: data.id,
        user_id: data.user_id,
        domain: data.domain,
        site_name: data.site_name,
        username: data.username,
        password,
        created_at: data.created_at,
        updated_at: data.updated_at
      };
    } catch (error) {
      console.error('Error getting credential:', error);
      return null;
    }
  }, [user, isElectron]);

  const getAllCredentialsForDomain = useCallback(async (url: string): Promise<DecryptedCredential[]> => {
    if (!user) return [];

    try {
      const domain = extractDomain(url);
      
      // Se estamos no Electron, buscar local primeiro
      if (isElectron) {
        const localCreds = await localCredentialStore.getByDomain(domain);
        if (localCreds.length > 0) {
          const decrypted = await Promise.all(
            localCreds.map(async (cred) => ({
              id: cred.id,
              user_id: user.id,
              domain: cred.domain,
              site_name: cred.site_name ?? null,
              username: cred.username,
              password: await decryptPassword(cred.encrypted_password, user.id),
              created_at: cred.created_at,
              updated_at: cred.updated_at
            }))
          );
          return decrypted;
        }
      }
      
      // Fallback para Supabase
      const { data, error } = await supabase
        .from('saved_credentials')
        .select('*')
        .eq('user_id', user.id)
        .eq('domain', domain);

      if (error || !data) return [];

      const decrypted = await Promise.all(
        data.map(async (cred) => ({
          id: cred.id,
          user_id: cred.user_id,
          domain: cred.domain,
          site_name: cred.site_name,
          username: cred.username,
          password: await decryptPassword(cred.encrypted_password, user.id),
          created_at: cred.created_at,
          updated_at: cred.updated_at
        }))
      );

      return decrypted;
    } catch (error) {
      console.error('Error getting credentials:', error);
      return [];
    }
  }, [user, isElectron]);

  const deleteCredential = useCallback(async (id: string): Promise<boolean> => {
    if (!user) return false;

    try {
      // Deletar localmente primeiro
      if (isElectron) {
        await localCredentialStore.delete(id);
        setCredentials(prev => prev.filter(c => c.id !== id));
      }

      // Deletar do Supabase
      const { error } = await supabase
        .from('saved_credentials')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);

      if (error) throw error;

      toast.success('Credencial removida');
      
      if (!isElectron) {
        await fetchCredentials();
      }
      
      return true;
    } catch (error) {
      console.error('Error deleting credential:', error);
      toast.error('Erro ao remover credencial');
      return false;
    }
  }, [user, fetchCredentials, isElectron]);

  const decryptCredential = useCallback(async (credential: SavedCredential): Promise<string> => {
    if (!user) return '';
    return decryptPassword(credential.encrypted_password, user.id);
  }, [user]);

  // Forçar sincronização manual
  const forceSync = useCallback(async () => {
    if (!isElectron) return;
    await syncUnsynced();
    await fetchCredentials();
  }, [isElectron, syncUnsynced, fetchCredentials]);

  return {
    credentials,
    loading,
    syncing,
    saveCredential,
    getCredentialForDomain,
    getAllCredentialsForDomain,
    deleteCredential,
    decryptCredential,
    refreshCredentials: fetchCredentials,
    forceSync
  };
}
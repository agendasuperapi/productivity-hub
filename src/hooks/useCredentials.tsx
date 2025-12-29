import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { encryptPassword, decryptPassword, extractDomain } from '@/lib/crypto';
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
}

export interface DecryptedCredential extends Omit<SavedCredential, 'encrypted_password'> {
  password: string;
}

export function useCredentials() {
  const { user } = useAuth();
  const [credentials, setCredentials] = useState<SavedCredential[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchCredentials = useCallback(async () => {
    if (!user) {
      setCredentials([]);
      setLoading(false);
      return;
    }

    try {
      const { data, error } = await supabase
        .from('saved_credentials')
        .select('*')
        .eq('user_id', user.id)
        .order('domain', { ascending: true });

      if (error) throw error;
      setCredentials(data || []);
    } catch (error) {
      console.error('Error fetching credentials:', error);
      toast.error('Erro ao carregar credenciais');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchCredentials();
  }, [fetchCredentials]);

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
      console.log('[useCredentials] Iniciando salvamento de credencial para:', url, username);
      const domain = extractDomain(url);
      console.log('[useCredentials] Domínio extraído:', domain);
      
      const encryptedPwd = await encryptPassword(password, user.id);
      console.log('[useCredentials] Senha encriptada com sucesso');

      // Check if credential already exists for this domain + username
      const { data: existing, error: checkError } = await supabase
        .from('saved_credentials')
        .select('id')
        .eq('user_id', user.id)
        .eq('domain', domain)
        .eq('username', username)
        .maybeSingle();

      if (checkError) {
        console.error('[useCredentials] Erro ao verificar credencial existente:', checkError);
        throw checkError;
      }

      if (existing) {
        console.log('[useCredentials] Atualizando credencial existente:', existing.id);
        // Update existing
        const { error } = await supabase
          .from('saved_credentials')
          .update({
            encrypted_password: encryptedPwd,
            site_name: siteName || domain,
            updated_at: new Date().toISOString()
          })
          .eq('id', existing.id);

        if (error) {
          console.error('[useCredentials] Erro ao atualizar credencial:', error);
          throw error;
        }
        console.log('[useCredentials] Credencial atualizada com sucesso');
        toast.success('Credenciais atualizadas');
      } else {
        console.log('[useCredentials] Inserindo nova credencial');
        // Insert new
        const { error } = await supabase
          .from('saved_credentials')
          .insert({
            user_id: user.id,
            domain,
            site_name: siteName || domain,
            username,
            encrypted_password: encryptedPwd
          });

        if (error) {
          console.error('[useCredentials] Erro ao inserir credencial:', error);
          throw error;
        }
        console.log('[useCredentials] Credencial inserida com sucesso');
        toast.success('Credenciais salvas');
      }

      await fetchCredentials();
      return true;
    } catch (error: any) {
      console.error('[useCredentials] Erro ao salvar credencial:', error?.message || error);
      toast.error('Erro ao salvar credenciais: ' + (error?.message || 'Erro desconhecido'));
      return false;
    }
  }, [user, fetchCredentials]);

  const getCredentialForDomain = useCallback(async (url: string): Promise<DecryptedCredential | null> => {
    if (!user) return null;

    try {
      const domain = extractDomain(url);
      
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
  }, [user]);

  const getAllCredentialsForDomain = useCallback(async (url: string): Promise<DecryptedCredential[]> => {
    if (!user) return [];

    try {
      const domain = extractDomain(url);
      
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
  }, [user]);

  const deleteCredential = useCallback(async (id: string): Promise<boolean> => {
    if (!user) return false;

    try {
      const { error } = await supabase
        .from('saved_credentials')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);

      if (error) throw error;

      toast.success('Credencial removida');
      await fetchCredentials();
      return true;
    } catch (error) {
      console.error('Error deleting credential:', error);
      toast.error('Erro ao remover credencial');
      return false;
    }
  }, [user, fetchCredentials]);

  const decryptCredential = useCallback(async (credential: SavedCredential): Promise<string> => {
    if (!user) return '';
    return decryptPassword(credential.encrypted_password, user.id);
  }, [user]);

  return {
    credentials,
    loading,
    saveCredential,
    getCredentialForDomain,
    getAllCredentialsForDomain,
    deleteCredential,
    decryptCredential,
    refreshCredentials: fetchCredentials
  };
}

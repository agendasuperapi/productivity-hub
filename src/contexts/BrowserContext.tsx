import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useCredentials } from '@/hooks/useCredentials';
import { useFormFieldValues } from '@/hooks/useFormFieldValues';
import { toast } from 'sonner';
export interface TabUrl {
  url: string;
  shortcut_enabled?: boolean;
  zoom?: number;
}

export interface Tab {
  id: string;
  name: string;
  url: string;
  urls?: TabUrl[];
  layout_type?: string;
  zoom?: number;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  open_as_window?: boolean;
  position: number;
  window_x?: number;
  window_y?: number;
  window_width?: number;
  window_height?: number;
  alternative_domains?: string[];
  show_link_transform_panel?: boolean;
  /** Habilita captura automática de token via webRequest */
  capture_token?: boolean;
  /** Nome do header HTTP a ser capturado (default: X-Access-Token) */
  capture_token_header?: string;
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  tabs: Tab[];
}

interface BrowserContextType {
  groups: TabGroup[];
  activeGroup: TabGroup | null;
  activeTab: Tab | null;
  loading: boolean;
  tabNotifications: Record<string, number>;
  setActiveGroup: (group: TabGroup | null) => void;
  setActiveTab: (tab: Tab | null) => void;
  setTabNotification: (tabId: string, count: number) => void;
  refreshData: () => Promise<void>;
}

const BrowserContext = createContext<BrowserContextType | undefined>(undefined);

// Função para verificar dinamicamente se está no Electron
const getElectronAPI = () => {
  if (typeof window !== 'undefined' && (window as any).electronAPI) {
    return (window as any).electronAPI;
  }
  return null;
};

export function BrowserProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const { saveCredential, getAllCredentialsForDomain } = useCredentials();
  const { saveFieldValue, getValuesForField } = useFormFieldValues();
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [activeGroup, setActiveGroup] = useState<TabGroup | null>(null);
  const [activeTab, setActiveTab] = useState<Tab | null>(null);
  const [loading, setLoading] = useState(true);
  const [tabNotifications, setTabNotifications] = useState<Record<string, number>>({});

  const setTabNotification = (tabId: string, count: number) => {
    setTabNotifications(prev => {
      if (prev[tabId] === count) return prev;
      return { ...prev, [tabId]: count };
    });
  };

  // Função para buscar dados - otimizada para Electron
  const fetchData = useCallback(async (isInitial = false) => {
    if (!user) return;

    console.log('[BrowserContext] Fetching data...', { isInitial, isElectron: !!getElectronAPI() });

    const [groupsRes, tabsRes] = await Promise.all([
      supabase.from('tab_groups').select('*').order('position'),
      supabase.from('tabs').select('*').order('position'),
    ]);

    if (groupsRes.error) {
      console.error('[BrowserContext] Error fetching groups:', groupsRes.error);
    }
    if (tabsRes.error) {
      console.error('[BrowserContext] Error fetching tabs:', tabsRes.error);
    }

    const groupsData = groupsRes.data || [];
    const tabsData = tabsRes.data || [];

    console.log('[BrowserContext] Fetched:', { groups: groupsData.length, tabs: tabsData.length });

    const groupsWithTabs: TabGroup[] = groupsData.map(group => ({
      ...group,
      tabs: tabsData
        .filter(tab => tab.group_id === group.id)
        .map(tab => ({
          ...tab,
          urls: Array.isArray(tab.urls) ? (tab.urls as unknown as TabUrl[]) : [],
          alternative_domains: Array.isArray(tab.alternative_domains) ? (tab.alternative_domains as unknown as string[]) : [],
        }))
    }));

    // Atualizar grupos e loading simultaneamente para evitar flash
    setGroups(groupsWithTabs);
    
    // Só definir grupo/aba ativa no carregamento inicial
    if (isInitial && groupsWithTabs.length > 0) {
      setActiveGroup(groupsWithTabs[0]);
      if (groupsWithTabs[0].tabs.length > 0 && !groupsWithTabs[0].tabs[0].open_as_window) {
        setActiveTab(groupsWithTabs[0].tabs[0]);
      }
    }
    
    setLoading(false);
  }, [user]);

  // Função pública para refresh manual
  const refreshData = useCallback(async () => {
    console.log('[BrowserContext] Manual refresh triggered');
    await fetchData(false);
  }, [fetchData]);

  // Carregar dados inicial
  useEffect(() => {
    if (user) {
      fetchData(true);
    }
  }, [user, fetchData]);

  // Subscription em tempo real para tab_groups e tabs
  useEffect(() => {
    if (!user) return;

    console.log('[BrowserContext] Setting up realtime subscription...');

    const channel = supabase
      .channel('browser-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'tab_groups' },
        (payload) => {
          console.log('[BrowserContext] tab_groups changed:', payload);
          fetchData();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'tabs' },
        (payload) => {
          console.log('[BrowserContext] tabs changed:', payload);
          fetchData();
        }
      )
      .subscribe((status, err) => {
        console.log('[BrowserContext] Subscription status:', status, err);
        if (status === 'SUBSCRIBED') {
          console.log('[BrowserContext] Realtime conectado com sucesso!');
        } else if (status === 'CHANNEL_ERROR') {
          console.error('[BrowserContext] Erro no canal realtime:', err);
          // Tentar reconectar após 5 segundos
          setTimeout(() => {
            console.log('[BrowserContext] Tentando reconectar...');
            fetchData();
          }, 5000);
        } else if (status === 'TIMED_OUT') {
          console.warn('[BrowserContext] Conexão realtime expirou');
        }
      });

    return () => {
      console.log('[BrowserContext] Removing realtime channel');
      supabase.removeChannel(channel);
    };
  }, [user, fetchData]);

  // Polling como fallback para Electron (a cada 30 segundos)
  useEffect(() => {
    const electronAPI = getElectronAPI();
    if (!user || !electronAPI) return;

    console.log('[BrowserContext] Setting up polling fallback for Electron...');

    const interval = setInterval(() => {
      console.log('[BrowserContext] Polling fallback - fetching data...');
      fetchData();
    }, 30000); // 30 segundos

    return () => {
      console.log('[BrowserContext] Clearing polling interval');
      clearInterval(interval);
    };
  }, [user, fetchData]);

  // Listener para tokens capturados via Electron IPC
  useEffect(() => {
    if (!user) return;

    // Verificar dinamicamente se está no Electron
    const electronAPI = getElectronAPI();
    if (!electronAPI?.onTokenCaptured) {
      console.log('[BrowserContext] electronAPI não disponível, ignorando token listener');
      return;
    }

    console.log('[BrowserContext] ===========================================');
    console.log('[BrowserContext] Registrando listener de token capture para user:', user.id);
    console.log('[BrowserContext] ===========================================');

    // Handler com referência estável
    const handleTokenCaptured = async (data: { 
      tabId: string; 
      domain: string; 
      tokenName: string; 
      tokenValue: string 
    }) => {
      console.log('[BrowserContext] ===========================================');
      console.log('[BrowserContext] TOKEN RECEBIDO VIA IPC!');
      console.log('[BrowserContext] tabId:', data.tabId);
      console.log('[BrowserContext] domain:', data.domain);
      console.log('[BrowserContext] tokenName:', data.tokenName);
      console.log('[BrowserContext] tokenLength:', data.tokenValue?.length);
      console.log('[BrowserContext] userId:', user.id);
      console.log('[BrowserContext] ===========================================');
      
      try {
        // Salvar token no Supabase
        const { data: result, error } = await supabase
          .from('captured_tokens')
          .upsert({
            user_id: user.id,
            tab_id: data.tabId,
            domain: data.domain,
            token_name: data.tokenName,
            token_value: data.tokenValue,
            updated_at: new Date().toISOString(),
          }, { 
            onConflict: 'user_id,tab_id,domain' 
          })
          .select();
        
        if (error) {
          console.error('[BrowserContext] ERRO ao salvar token:', error);
          toast.error('Erro ao salvar token: ' + error.message);
          return;
        }
        
        console.log('[BrowserContext] TOKEN SALVO COM SUCESSO:', result);
        toast.success('Token capturado e atualizado!');

        // Buscar nome da tab e webhook global do perfil
        const [tabResult, profileResult] = await Promise.all([
          supabase
            .from('tabs')
            .select('name')
            .eq('id', data.tabId)
            .maybeSingle(),
          supabase
            .from('profiles')
            .select('settings')
            .eq('user_id', user.id)
            .maybeSingle(),
        ]);

        const tabName = tabResult.data?.name;
        const webhookUrl = (profileResult.data?.settings as any)?.integrations?.webhook_url;

        if (webhookUrl) {
          console.log('[BrowserContext] Enviando token para webhook global:', webhookUrl);
          
          try {
            const { data: webhookResult, error: webhookError } = await supabase.functions.invoke('forward-token-webhook', {
              body: {
                webhook_url: webhookUrl,
                tab_id: data.tabId,
                tab_name: tabName,
                domain: data.domain,
                token_name: data.tokenName,
                token_value: data.tokenValue,
                captured_at: new Date().toISOString(),
                user_email: user.email,
              },
            });

            if (webhookError) {
              console.error('[BrowserContext] Erro no webhook:', webhookError);
              toast.error('Token salvo, mas erro ao enviar webhook');
            } else if (webhookResult?.success) {
              console.log('[BrowserContext] Webhook enviado com sucesso');
              toast.success('Token enviado para webhook!');
            } else {
              console.warn('[BrowserContext] Webhook retornou erro:', webhookResult);
            }
          } catch (webhookErr) {
            console.error('[BrowserContext] Erro ao chamar webhook:', webhookErr);
          }
        }
      } catch (err) {
        console.error('[BrowserContext] ERRO CATCH ao processar token:', err);
      }
    };

    // Registrar o listener
    electronAPI.onTokenCaptured(handleTokenCaptured);

    // Cleanup - remover callback específico
    return () => {
      console.log('[BrowserContext] Removendo listener de token');
      if (electronAPI.removeTokenListener) {
        electronAPI.removeTokenListener(handleTokenCaptured);
      }
    };
  }, [user]);

  // Listener para credenciais vindas das janelas flutuantes
  useEffect(() => {
    if (!user) return;

    const electronAPI = getElectronAPI();
    if (!electronAPI) return;

    // Handler para salvar credenciais
    const handleCredentialSave = async (event: any, data: { 
      url: string; 
      username: string; 
      password: string; 
      siteName?: string 
    }) => {
      console.log('[BrowserContext] Recebido credential:save para:', data.url);
      
      try {
        const success = await saveCredential(data.url, data.username, data.password, data.siteName);
        if (success) {
          console.log('[BrowserContext] Credenciais salvas com sucesso');
        } else {
          console.error('[BrowserContext] Falha ao salvar credenciais');
        }
      } catch (err) {
        console.error('[BrowserContext] Erro ao salvar credenciais:', err);
      }
    };

    // Handler para buscar credenciais (para auto-fill)
    const handleCredentialGet = async (event: any, data: { url: string; responseChannel: string }) => {
      console.log('[BrowserContext] Recebido credential:get para:', data.url);
      
      try {
        const credentials = await getAllCredentialsForDomain(data.url);
        console.log('[BrowserContext] Credenciais encontradas:', credentials.length);
        
        // Enviar resposta de volta via IPC
        if (electronAPI.sendCredentialResponse) {
          electronAPI.sendCredentialResponse(data.responseChannel, credentials);
        }
      } catch (err) {
        console.error('[BrowserContext] Erro ao buscar credenciais:', err);
        if (electronAPI.sendCredentialResponse) {
          electronAPI.sendCredentialResponse(data.responseChannel, []);
        }
      }
    };

    // Registrar listeners via IPC do renderer
    if (electronAPI.onCredentialSave) {
      electronAPI.onCredentialSave(handleCredentialSave);
    }
    if (electronAPI.onCredentialGet) {
      electronAPI.onCredentialGet(handleCredentialGet);
    }

    return () => {
      console.log('[BrowserContext] Removendo listeners de credenciais');
      if (electronAPI.removeCredentialListeners) {
        electronAPI.removeCredentialListeners();
      }
    };
  }, [user, saveCredential, getAllCredentialsForDomain]);

  // Listener para form fields vindos das janelas flutuantes
  useEffect(() => {
    if (!user) return;

    const electronAPI = getElectronAPI();
    if (!electronAPI) return;

    // Handler para salvar campo de formulário
    const handleFormFieldSave = async (event: any, data: { 
      domain: string; 
      field: string; 
      value: string; 
      label?: string 
    }) => {
      console.log('[BrowserContext] Recebido formField:save para:', data.domain, data.field);
      
      try {
        await saveFieldValue(data.domain, data.field, data.value, data.label);
        console.log('[BrowserContext] Campo salvo com sucesso');
      } catch (err) {
        console.error('[BrowserContext] Erro ao salvar campo:', err);
      }
    };

    // Handler para buscar sugestões de campos
    const handleFormFieldGet = async (event: any, data: { domain: string; field: string; responseChannel: string }) => {
      console.log('[BrowserContext] Recebido formField:get para:', data.domain, data.field);
      
      try {
        const values = await getValuesForField(data.domain, data.field);
        const suggestions = values.map(v => v.field_value);
        console.log('[BrowserContext] Sugestões encontradas:', suggestions.length);
        
        // Enviar resposta de volta via IPC
        if (electronAPI.sendFormFieldResponse) {
          electronAPI.sendFormFieldResponse(data.responseChannel, suggestions);
        }
      } catch (err) {
        console.error('[BrowserContext] Erro ao buscar sugestões:', err);
        if (electronAPI.sendFormFieldResponse) {
          electronAPI.sendFormFieldResponse(data.responseChannel, []);
        }
      }
    };

    // Registrar listeners via IPC do renderer
    if (electronAPI.onFormFieldSave) {
      electronAPI.onFormFieldSave(handleFormFieldSave);
    }
    if (electronAPI.onFormFieldGet) {
      electronAPI.onFormFieldGet(handleFormFieldGet);
    }

    return () => {
      console.log('[BrowserContext] Removendo listeners de form fields');
      if (electronAPI.removeFormFieldListeners) {
        electronAPI.removeFormFieldListeners();
      }
    };
  }, [user, saveFieldValue, getValuesForField]);

  const handleSetActiveGroup = (group: TabGroup | null) => {
    setActiveGroup(group);
    if (group && group.tabs.length > 0) {
      const firstTab = group.tabs[0];
      if (!firstTab.open_as_window) {
        setActiveTab(firstTab);
      }
    }
  };

  return (
    <BrowserContext.Provider value={{
      groups,
      activeGroup,
      activeTab,
      loading,
      tabNotifications,
      setActiveGroup: handleSetActiveGroup,
      setActiveTab,
      setTabNotification,
      refreshData,
    }}>
      {children}
    </BrowserContext.Provider>
  );
}

export function useBrowser() {
  const context = useContext(BrowserContext);
  return context;
}

export function useBrowserSafe() {
  return useContext(BrowserContext);
}

import { createContext, useContext, useState, useEffect, useCallback, useRef, ReactNode } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useCredentials } from '@/hooks/useCredentials';
import { useFormFieldValues } from '@/hooks/useFormFieldValues';
import { useBlockedDomains } from '@/hooks/useBlockedDomains';
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
  reorderTabsInGroup: (groupId: string, reorderedTabs: Tab[]) => void;
  moveTabToGroup: (tabId: string, fromGroupId: string, toGroupId: string) => void;
  reorderGroups: (reorderedGroups: TabGroup[]) => void;
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
  const { blockDomain, isBlocked } = useBlockedDomains();
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [activeGroup, setActiveGroup] = useState<TabGroup | null>(null);
  const [activeTab, setActiveTab] = useState<Tab | null>(null);
  const [loading, setLoading] = useState(true);
  const [tabNotifications, setTabNotifications] = useState<Record<string, number>>({});
  const [isElectronReady, setIsElectronReady] = useState(false);
  const initialLoadDone = useRef(false);

  // Verificar se está no Electron com retry para garantir detecção
  useEffect(() => {
    const checkElectronAPI = () => {
      const api = getElectronAPI();
      if (api?.onTokenCaptured) {
        console.log('[BrowserContext] Electron API detectada e pronta');
        setIsElectronReady(true);
        return true;
      }
      return false;
    };

    // Verificar imediatamente
    if (checkElectronAPI()) return;

    // Se não encontrou, tentar novamente algumas vezes
    let attempts = 0;
    const maxAttempts = 10;
    const interval = setInterval(() => {
      attempts++;
      console.log(`[BrowserContext] Tentativa ${attempts}/${maxAttempts} de detectar Electron API...`);
      if (checkElectronAPI() || attempts >= maxAttempts) {
        clearInterval(interval);
        if (attempts >= maxAttempts) {
          console.log('[BrowserContext] Electron API não detectada após todas tentativas (ambiente web)');
        }
      }
    }, 500);

    return () => clearInterval(interval);
  }, []);

  const setTabNotification = (tabId: string, count: number) => {
    setTabNotifications(prev => {
      if (prev[tabId] === count) return prev;
      return { ...prev, [tabId]: count };
    });
  };

  // Função para buscar dados - LOCAL FIRST para Electron
  const fetchData = useCallback(async (isInitial = false) => {
    if (!user) return;

    const electronAPI = getElectronAPI();
    console.log('[BrowserContext] Fetching data...', { isInitial, isElectron: !!electronAPI });

    // 1. Se estamos no Electron, carregar do cache local PRIMEIRO (instantâneo)
    if (electronAPI?.getBrowserDataLocal) {
      try {
        const localData = await electronAPI.getBrowserDataLocal();
        if (localData.tabGroups?.length > 0) {
          console.log('[BrowserContext] Carregando dados locais:', { 
            groups: localData.tabGroups.length, 
            tabs: localData.tabs.length,
            lastSync: localData.lastSync 
          });
          
          const groupsWithTabs: TabGroup[] = localData.tabGroups.map((group: any) => ({
            ...group,
            tabs: localData.tabs
              .filter((tab: any) => tab.group_id === group.id)
              .map((tab: any) => ({
                ...tab,
                urls: Array.isArray(tab.urls) ? tab.urls : [],
                alternative_domains: Array.isArray(tab.alternative_domains) ? tab.alternative_domains : [],
              }))
          }));

          setGroups(groupsWithTabs);
          
          if (isInitial && groupsWithTabs.length > 0) {
            setActiveGroup(groupsWithTabs[0]);
            if (groupsWithTabs[0].tabs.length > 0 && !groupsWithTabs[0].tabs[0].open_as_window) {
              setActiveTab(groupsWithTabs[0].tabs[0]);
            }
          }
          
          setLoading(false); // UI aparece imediatamente com dados locais
        }
      } catch (localError) {
        console.log('[BrowserContext] Erro ao carregar dados locais:', localError);
      }
    }

    // 2. Tentar sincronizar com Supabase em background
    try {
      const [groupsRes, tabsRes] = await Promise.all([
        supabase.from('tab_groups').select('*').order('position'),
        supabase.from('tabs').select('*').order('position'),
      ]);

      if (groupsRes.error) {
        console.error('[BrowserContext] Error fetching groups:', groupsRes.error);
        throw groupsRes.error;
      }
      if (tabsRes.error) {
        console.error('[BrowserContext] Error fetching tabs:', tabsRes.error);
        throw tabsRes.error;
      }

      const groupsData = groupsRes.data || [];
      const tabsData = tabsRes.data || [];

      console.log('[BrowserContext] Dados do Supabase:', { groups: groupsData.length, tabs: tabsData.length });

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

      // Atualizar estado
      setGroups(groupsWithTabs);
      
      // Só definir grupo/aba ativa no carregamento inicial (se ainda não definido)
      if (isInitial && groupsWithTabs.length > 0 && !activeGroup) {
        setActiveGroup(groupsWithTabs[0]);
        if (groupsWithTabs[0].tabs.length > 0 && !groupsWithTabs[0].tabs[0].open_as_window) {
          setActiveTab(groupsWithTabs[0].tabs[0]);
        }
      }

      // Salvar no cache local para próxima vez
      if (electronAPI?.saveBrowserDataLocal) {
        await electronAPI.saveBrowserDataLocal({ 
          tabGroups: groupsData, 
          tabs: tabsData 
        });
      }
    } catch (error) {
      console.log('[BrowserContext] Offline ou erro - usando dados locais existentes');
      // Se falhar, os dados locais já foram carregados acima (se disponíveis)
    }
    
    setLoading(false);
  }, [user, activeGroup]);

  // Função pública para refresh manual
  const refreshData = useCallback(async () => {
    console.log('[BrowserContext] Manual refresh triggered');
    await fetchData(false);
  }, [fetchData]);

  // Carregar dados inicial - apenas UMA vez por sessão
  useEffect(() => {
    if (user && !initialLoadDone.current) {
      initialLoadDone.current = true;
      fetchData(true);
    }
  }, [user, fetchData]);

  // Limpar estado ao fazer logout
  useEffect(() => {
    if (!user) {
      initialLoadDone.current = false;
      setActiveGroup(null);
      setActiveTab(null);
      setGroups([]);
      setLoading(true);
    }
  }, [user]);

  // Subscription em tempo real para tab_groups e tabs
  useEffect(() => {
    if (!user) return;

    let retryCount = 0;
    let retryTimeout: ReturnType<typeof setTimeout>;
    let hasLoggedSuccess = false;
    let hasLoggedError = false;

    const setupChannel = () => {
      const channel = supabase
        .channel(`browser-realtime-${Date.now()}`)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'tab_groups' },
          () => fetchData()
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'tabs' },
          () => fetchData()
        )
        .subscribe((status, err) => {
          if (status === 'SUBSCRIBED') {
            if (!hasLoggedSuccess) {
              console.log('[BrowserContext] Realtime conectado');
              hasLoggedSuccess = true;
            }
            retryCount = 0;
            hasLoggedError = false;
          } else if (status === 'CHANNEL_ERROR') {
            if (!hasLoggedError) {
              console.warn('[BrowserContext] Erro realtime, usando polling como fallback');
              hasLoggedError = true;
            }
            // Exponential backoff: 5s, 10s, 20s, max 60s
            const delay = Math.min(5000 * Math.pow(2, retryCount), 60000);
            retryCount++;
            retryTimeout = setTimeout(() => {
              supabase.removeChannel(channel);
              setupChannel();
            }, delay);
          }
        });

      return channel;
    };

    const channel = setupChannel();

    return () => {
      clearTimeout(retryTimeout);
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
    // Só registrar quando tiver user E Electron estiver pronto
    if (!user || !isElectronReady) {
      console.log('[BrowserContext] Token listener não registrado:', { user: !!user, isElectronReady });
      return;
    }

    const electronAPI = getElectronAPI();
    if (!electronAPI?.onTokenCaptured) {
      console.log('[BrowserContext] electronAPI.onTokenCaptured não disponível');
      return;
    }

    console.log('[BrowserContext] ===========================================');
    console.log('[BrowserContext] REGISTRANDO listener de token capture');
    console.log('[BrowserContext] User ID:', user.id);
    console.log('[BrowserContext] User Email:', user.email);
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

        console.log('[BrowserContext] webhookUrl configurado:', webhookUrl || 'NENHUM');

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
  }, [user, isElectronReady]);

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

    // Handler para bloquear domínio (nunca salvar credenciais)
    const handleCredentialBlockDomain = async (event: any, data: { domain: string; responseChannel: string }) => {
      console.log('[BrowserContext] Recebido credential:blockDomain para:', data.domain);
      
      try {
        const success = await blockDomain(data.domain);
        console.log('[BrowserContext] Resultado do bloqueio:', success);
        
        if (electronAPI.sendBlockDomainResponse) {
          electronAPI.sendBlockDomainResponse(data.responseChannel, { success });
        }
      } catch (err) {
        console.error('[BrowserContext] Erro ao bloquear domínio:', err);
        if (electronAPI.sendBlockDomainResponse) {
          electronAPI.sendBlockDomainResponse(data.responseChannel, { success: false });
        }
      }
    };

    // Handler para verificar se domínio está bloqueado
    const handleCredentialIsBlocked = async (event: any, data: { domain: string; responseChannel: string }) => {
      console.log('[BrowserContext] Recebido credential:isBlocked para:', data.domain);
      
      try {
        const blocked = isBlocked(data.domain);
        console.log('[BrowserContext] Domínio bloqueado?', blocked);
        
        if (electronAPI.sendIsBlockedResponse) {
          electronAPI.sendIsBlockedResponse(data.responseChannel, { blocked });
        }
      } catch (err) {
        console.error('[BrowserContext] Erro ao verificar bloqueio:', err);
        if (electronAPI.sendIsBlockedResponse) {
          electronAPI.sendIsBlockedResponse(data.responseChannel, { blocked: false });
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
    if (electronAPI.onCredentialBlockDomain) {
      electronAPI.onCredentialBlockDomain(handleCredentialBlockDomain);
    }
    if (electronAPI.onCredentialIsBlocked) {
      electronAPI.onCredentialIsBlocked(handleCredentialIsBlocked);
    }

    return () => {
      console.log('[BrowserContext] Removendo listeners de credenciais');
      if (electronAPI.removeCredentialListeners) {
        electronAPI.removeCredentialListeners();
      }
    };
  }, [user, saveCredential, getAllCredentialsForDomain, blockDomain, isBlocked]);

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
      console.log('[BrowserContext] ===== RECEBIDO formField:get =====');
      console.log('[BrowserContext] Domain:', data.domain);
      console.log('[BrowserContext] Field:', data.field);
      console.log('[BrowserContext] ResponseChannel:', data.responseChannel);
      
      try {
        console.log('[BrowserContext] Buscando valores no Supabase...');
        const values = await getValuesForField(data.domain, data.field);
        const suggestions = values.map(v => v.field_value);
        console.log('[BrowserContext] ===== SUGESTÕES ENCONTRADAS =====');
        console.log('[BrowserContext] Total:', suggestions.length);
        console.log('[BrowserContext] Valores:', suggestions);
        
        // Enviar resposta de volta via IPC
        if (electronAPI.sendFormFieldResponse) {
          console.log('[BrowserContext] Enviando resposta via sendFormFieldResponse...');
          electronAPI.sendFormFieldResponse(data.responseChannel, suggestions);
          console.log('[BrowserContext] Resposta enviada!');
        } else {
          console.error('[BrowserContext] sendFormFieldResponse não disponível!');
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

  const reorderTabsInGroup = useCallback((groupId: string, reorderedTabs: Tab[]) => {
    setGroups(prevGroups => 
      prevGroups.map(g => 
        g.id === groupId 
          ? { ...g, tabs: reorderedTabs.map((tab, index) => ({ ...tab, position: index })) }
          : g
      )
    );
    // Atualizar também o activeGroup se for o mesmo
    setActiveGroup(prev => 
      prev && prev.id === groupId 
        ? { ...prev, tabs: reorderedTabs.map((tab, index) => ({ ...tab, position: index })) }
        : prev
    );
  }, []);

  const moveTabToGroup = useCallback((tabId: string, fromGroupId: string, toGroupId: string) => {
    setGroups(prevGroups => {
      const fromGroup = prevGroups.find(g => g.id === fromGroupId);
      const toGroup = prevGroups.find(g => g.id === toGroupId);
      if (!fromGroup || !toGroup) return prevGroups;

      const tab = fromGroup.tabs.find(t => t.id === tabId);
      if (!tab) return prevGroups;

      return prevGroups.map(g => {
        if (g.id === fromGroupId) {
          // Remove tab from source group and reorder positions
          const newTabs = g.tabs.filter(t => t.id !== tabId).map((t, i) => ({ ...t, position: i }));
          return { ...g, tabs: newTabs };
        }
        if (g.id === toGroupId) {
          // Add tab to destination group at the end
          const newTab = { ...tab, position: g.tabs.length };
          return { ...g, tabs: [...g.tabs, newTab] };
        }
        return g;
      });
    });

    // Atualizar activeGroup se necessário
    setActiveGroup(prev => {
      if (!prev) return prev;
      const updatedGroups = groups;
      const found = updatedGroups.find(g => g.id === prev.id);
      return found || prev;
    });
  }, [groups]);

  const reorderGroups = useCallback((reorderedGroups: TabGroup[]) => {
    setGroups(reorderedGroups.map((group, index) => ({ ...group, position: index })));
  }, []);

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
      reorderTabsInGroup,
      moveTabToGroup,
      reorderGroups,
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

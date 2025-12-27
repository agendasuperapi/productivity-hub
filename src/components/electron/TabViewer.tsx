import { useEffect, useState, useCallback, useMemo, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useElectron, WindowBoundsData } from '@/hooks/useElectron';
import { useBrowser } from '@/contexts/BrowserContext';
import { WebviewPanel } from './WebviewPanel';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { cn } from '@/lib/utils';
import { ExternalLink, Columns } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcut {
  command: string;
  expanded_text: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface Keyword {
  key: string;
  value: string;
}

interface TabViewerProps {
  className?: string;
}

// Mantém os webviews renderizados para não recarregar ao mudar de aba
export function TabViewer({ className }: TabViewerProps) {
  const { user } = useAuth();
  const { 
    isElectron, 
    createWindow, 
    onShortcutTriggered, 
    registerShortcut, 
    unregisterShortcut,
    onWindowBoundsChanged,
    removeAllListeners,
    getFloatingWindowsSession,
    clearFloatingWindowsSession,
  } = useElectron();
  const { toast } = useToast();
  const browserContext = useBrowser();
  const { groups = [], activeGroup = null, activeTab = null, loading = true, setActiveTab = () => {}, tabNotifications = {}, setTabNotification = () => {} } = browserContext || {};
  
  const [textShortcuts, setTextShortcuts] = useState<TextShortcut[]>([]);
  const [keywords, setKeywords] = useState<Keyword[]>([]);
  
  // Manter registro de quais abas já foram abertas (para manter webviews em memória)
  const [openedTabIds, setOpenedTabIds] = useState<Set<string>>(new Set());
  
  // Estado para diálogo de restauração de sessão
  const [showRestoreDialog, setShowRestoreDialog] = useState(false);
  const [savedSession, setSavedSession] = useState<Array<{ tabId: string }> | null>(null);
  const sessionCheckDone = useRef(false);

  // Função para salvar posição/tamanho no banco
  const saveWindowBounds = useCallback(async (tabId: string, bounds: Partial<{
    window_x: number;
    window_y: number;
    window_width: number;
    window_height: number;
    zoom: number;
  }>) => {
    if (!user) return;
    
    try {
      await supabase
        .from('tabs')
        .update(bounds)
        .eq('id', tabId)
        .eq('user_id', user.id);
    } catch (error) {
      console.error('Erro ao salvar posição da janela:', error);
    }
  }, [user]);

  // Escutar eventos de posição/tamanho das janelas (ao fechar)
  useEffect(() => {
    if (!isElectron) return;

    onWindowBoundsChanged((data: WindowBoundsData) => {
      // Salvar todos os bounds quando a janela fecha
      saveWindowBounds(data.tabId, { 
        window_x: data.x, 
        window_y: data.y,
        window_width: data.width,
        window_height: data.height,
        zoom: data.zoom,
      });
    });

    return () => {
      removeAllListeners('window:boundsChanged');
    };
  }, [isElectron, saveWindowBounds, onWindowBoundsChanged, removeAllListeners]);

  // Carregar shortcuts e keywords
  useEffect(() => {
    async function fetchExtras() {
      if (!user) return;

      const [shortcutsRes, keywordsRes] = await Promise.all([
        supabase.from('text_shortcuts').select('command, expanded_text, auto_send, messages'),
        supabase.from('keywords').select('key, value'),
      ]);

      // Converter messages de Json para ShortcutMessage[]
      const shortcuts: TextShortcut[] = (shortcutsRes.data || []).map(s => ({
        command: s.command,
        expanded_text: s.expanded_text,
        auto_send: s.auto_send,
        messages: Array.isArray(s.messages) ? (s.messages as unknown as ShortcutMessage[]) : undefined,
      }));
      setTextShortcuts(shortcuts);
      setKeywords(keywordsRes.data || []);
    }

    fetchExtras();
  }, [user]);

  // Verificar se há sessão salva de janelas flutuantes para restaurar
  useEffect(() => {
    async function checkSavedSession() {
      if (!isElectron || sessionCheckDone.current || groups.length === 0) return;
      
      sessionCheckDone.current = true;
      
      const session = await getFloatingWindowsSession();
      if (session && session.length > 0) {
        setSavedSession(session);
        setShowRestoreDialog(true);
      }
    }

    if (!loading) {
      checkSavedSession();
    }
  }, [isElectron, loading, groups, getFloatingWindowsSession]);

  // Restaurar janelas da sessão
  const handleRestoreSession = useCallback(async () => {
    if (!savedSession) return;
    
    const allTabs = groups.flatMap(g => g.tabs);
    let restoredCount = 0;
    
    for (const saved of savedSession) {
      const tab = allTabs.find(t => t.id === saved.tabId);
      if (tab && tab.open_as_window) {
        const urls = tab.urls && tab.urls.length > 0 
          ? tab.urls
          : [{ url: tab.url, shortcut_enabled: true, zoom: tab.zoom }];
        
        await createWindow({
          id: tab.id,
          name: tab.name,
          url: tab.url,
          urls: urls,
          layout_type: tab.layout_type,
          zoom: tab.zoom,
          window_x: tab.window_x,
          window_y: tab.window_y,
          window_width: tab.window_width,
          window_height: tab.window_height,
          textShortcuts: textShortcuts,
          keywords: keywords,
        });
        restoredCount++;
      }
    }
    
    // Limpar sessão salva
    await clearFloatingWindowsSession();
    setShowRestoreDialog(false);
    setSavedSession(null);
    
    if (restoredCount > 0) {
      toast({ 
        title: 'Sessão restaurada', 
        description: `${restoredCount} janela(s) reaberta(s)` 
      });
    }
  }, [savedSession, groups, createWindow, textShortcuts, keywords, clearFloatingWindowsSession, toast]);

  // Descartar sessão salva
  const handleDiscardSession = useCallback(async () => {
    await clearFloatingWindowsSession();
    setShowRestoreDialog(false);
    setSavedSession(null);
  }, [clearFloatingWindowsSession]);

  // Registrar atalhos de teclado globais
  useEffect(() => {
    if (!isElectron) return;

    const allTabs = groups.flatMap(g => g.tabs);
    
    allTabs.forEach(tab => {
      if (tab.keyboard_shortcut) {
        registerShortcut(tab.keyboard_shortcut, tab.id);
      }
    });

    onShortcutTriggered((tabId) => {
      const tab = allTabs.find(t => t.id === tabId);
      if (tab) {
        handleOpenTab(tab);
      }
    });

    return () => {
      allTabs.forEach(tab => {
        if (tab.keyboard_shortcut) {
          unregisterShortcut(tab.keyboard_shortcut);
        }
      });
    };
  }, [groups, isElectron]);

  // Adicionar aba à lista de abertas quando selecionada
  useEffect(() => {
    if (activeTab && !activeTab.open_as_window) {
      setOpenedTabIds(prev => {
        if (prev.has(activeTab.id)) return prev;
        const newSet = new Set(prev);
        newSet.add(activeTab.id);
        return newSet;
      });
    }
  }, [activeTab]);

  const handleOpenTab = async (tab: any) => {
    if (tab.open_as_window) {
      const urls = tab.urls && tab.urls.length > 0 
        ? tab.urls
        : [{ url: tab.url, shortcut_enabled: true, zoom: tab.zoom }];
      
      const result = await createWindow({
        id: tab.id,
        name: tab.name,
        url: tab.url,
        urls: urls,
        layout_type: tab.layout_type,
        zoom: tab.zoom,
        window_x: tab.window_x,
        window_y: tab.window_y,
        window_width: tab.window_width,
        window_height: tab.window_height,
        // Passar atalhos para injeção na janela flutuante
        textShortcuts: textShortcuts,
        keywords: keywords,
      });
      
      if (result.success) {
        toast({ title: `${tab.name} aberto em nova janela` });
      } else {
        toast({ title: 'Erro ao abrir janela', description: result.error, variant: 'destructive' });
      }
    } else {
      setActiveTab(tab);
    }
  };

  // Lista de abas que devem ser mantidas em memória (não open_as_window)
  const allInlineTabs = useMemo(() => {
    return groups.flatMap(g => g.tabs).filter(t => !t.open_as_window);
  }, [groups]);

  // Abas que já foram abertas e devem ser mantidas renderizadas
  const tabsToRender = useMemo(() => {
    return allInlineTabs.filter(t => openedTabIds.has(t.id));
  }, [allInlineTabs, openedTabIds]);

  if (loading) {
    return (
      <div className={cn("flex items-center justify-center", className)}>
        <div className="animate-pulse text-muted-foreground">Carregando...</div>
      </div>
    );
  }

  return (
    <>
      {/* Diálogo de restauração de sessão */}
      <AlertDialog open={showRestoreDialog} onOpenChange={setShowRestoreDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Restaurar sessão anterior?</AlertDialogTitle>
            <AlertDialogDescription>
              {savedSession?.length === 1 
                ? 'Você tinha 1 janela flutuante aberta na última sessão.'
                : `Você tinha ${savedSession?.length || 0} janelas flutuantes abertas na última sessão.`}
              <br />
              Deseja restaurá-las?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={handleDiscardSession}>
              Não, descartar
            </AlertDialogCancel>
            <AlertDialogAction onClick={handleRestoreSession}>
              Sim, restaurar
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <div className={cn("flex flex-col h-full", className)}>

        {/* Abas horizontais como pills */}
        {activeGroup && activeGroup.tabs.length > 0 && (
          <div className="border-b bg-muted/30 shrink-0">
            <ScrollArea className="w-full">
              <div className="flex items-center gap-2 px-2 py-1">
                {activeGroup.tabs.map(tab => {
                  const notificationCount = tabNotifications[tab.id] || 0;
                  return (
                    <Button
                      key={tab.id}
                      variant={activeTab?.id === tab.id ? "default" : "outline"}
                      size="sm"
                      onClick={() => handleOpenTab(tab)}
                      className={cn(
                        "rounded-full px-3 shrink-0 gap-2 relative",
                        activeTab?.id === tab.id && "shadow-sm"
                      )}
                    >
                      <DynamicIcon icon={tab.icon} fallback="🌐" className="h-4 w-4" />
                      <span className="truncate max-w-[120px]">{tab.name}</span>
                      {notificationCount > 0 && (
                        <span className="bg-red-500 text-white text-[10px] font-bold rounded-full min-w-[16px] h-[16px] flex items-center justify-center px-1">
                          {notificationCount > 99 ? '99+' : notificationCount}
                        </span>
                      )}
                      {tab.open_as_window && (
                        <ExternalLink className="h-3 w-3 opacity-70" />
                      )}
                    </Button>
                  );
                })}
              </div>
            </ScrollArea>
          </div>
        )}

        {/* Container de webviews - mantém todos renderizados, mostra apenas o ativo */}
        <div className="flex-1 relative">
          {/* Renderizar todas as abas já abertas, ocultando as inativas */}
          {tabsToRender.map(tab => (
            <div
              key={tab.id}
              className="absolute inset-0"
              style={{ 
                display: activeTab?.id === tab.id ? 'block' : 'none',
                visibility: activeTab?.id === tab.id ? 'visible' : 'hidden'
              }}
            >
              <WebviewPanel
                tab={tab}
                textShortcuts={textShortcuts}
                keywords={keywords}
                onClose={() => setActiveTab(null)}
                onNotificationChange={(count) => setTabNotification(tab.id, count)}
              />
            </div>
          ))}

          {/* Placeholder quando nenhuma aba está selecionada */}
          {!activeTab && (
            <div className="h-full flex items-center justify-center bg-muted/30">
              <div className="text-center max-w-md px-4">
                <div className="p-4 rounded-full bg-primary/10 w-fit mx-auto mb-4">
                  <Columns className="h-8 w-8 text-primary" />
                </div>
                <h3 className="text-lg font-semibold mb-2">
                  {groups.length === 0 ? 'Nenhum grupo configurado' : 'Selecione uma aba'}
                </h3>
                <p className="text-muted-foreground text-sm">
                  {groups.length === 0 
                    ? 'Configure seus grupos e abas nas configurações.'
                    : 'Clique em uma aba acima para visualizá-la.'}
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

import { useEffect, useState, useCallback, useMemo, useRef, useLayoutEffect, lazy, Suspense } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useElectron, WindowBoundsData, TabData } from '@/hooks/useElectron';
import { useBrowser, Tab, VirtualTab } from '@/contexts/BrowserContext';
import { useUserSettings } from '@/hooks/useUserSettings';
import { useLocalSettings } from '@/hooks/useLocalSettings';
import { WebviewPanel } from './WebviewPanel';
import { ShortcutsBar } from './ShortcutsBar';
import { TabEditDialog } from '@/components/tabs/TabEditDialog';
import { Button } from '@/components/ui/button';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { cn } from '@/lib/utils';
import { ExternalLink, Columns, ChevronDown, Keyboard, GripVertical, Pencil, Check, Trash2, Plus, X, FolderOpen, Key, FileText, Settings, LayoutDashboard } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { toast as sonnerToast } from 'sonner';

// Lazy load das páginas para abas virtuais
const DashboardPage = lazy(() => import('@/pages/Dashboard'));
const TabGroupsPage = lazy(() => import('@/pages/TabGroups'));
const ShortcutsPage = lazy(() => import('@/pages/Shortcuts'));
const PasswordsPage = lazy(() => import('@/pages/Passwords'));
const FormDataPage = lazy(() => import('@/pages/FormData'));
const SettingsPage = lazy(() => import('@/pages/Settings'));
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
  DragStartEvent,
  DragOverlay,
  useDroppable,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  horizontalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
  ContextMenuSeparator,
} from "@/components/ui/context-menu";

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcut {
  command: string;
  expanded_text: string;
  description?: string;
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

// Componente drop zone para grupos
interface DroppableGroupProps {
  groupId: string;
  groupName: string;
  groupIcon?: string;
  isActive: boolean;
  isDragging: boolean;
}

function DroppableGroup({ groupId, groupName, groupIcon, isActive, isDragging }: DroppableGroupProps) {
  const { isOver, setNodeRef } = useDroppable({
    id: `group-${groupId}`,
  });

  if (isActive || !isDragging) return null;

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex items-center gap-2 px-3 py-2 rounded-lg border-2 border-dashed transition-all duration-200 z-[9998]",
        isOver 
          ? "border-primary bg-primary/20 scale-105 shadow-lg" 
          : "border-muted-foreground/30 bg-background hover:border-primary/50 hover:bg-muted/80"
      )}
    >
      <DynamicIcon icon={groupIcon} fallback="📁" className="h-4 w-4" />
      <span className="text-sm font-medium whitespace-nowrap">{groupName}</span>
      {isOver && <span className="text-xs text-primary font-medium">Soltar aqui</span>}
    </div>
  );
}

// Componente de aba arrastável
interface SortableTabButtonProps {
  tab: Tab;
  isActive: boolean;
  notificationCount: number;
  onOpen: (tab: Tab) => void;
  onClearNotification: (tabId: string) => void;
  tabRef: (el: HTMLButtonElement | null) => void;
  isDragMode: boolean;
  onEdit: (tabId: string) => void;
  onDelete: (tabId: string) => void;
}

function SortableTabButton({ 
  tab, 
  isActive, 
  notificationCount, 
  onOpen, 
  onClearNotification,
  tabRef,
  isDragMode,
  onEdit,
  onDelete
}: SortableTabButtonProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: tab.id, disabled: !isDragMode });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition: transition || 'transform 200ms ease, box-shadow 200ms ease, scale 150ms ease',
    zIndex: isDragging ? 9999 : undefined,
    position: isDragging ? 'relative' : undefined,
    scale: isDragging ? 1.05 : 1,
    boxShadow: isDragging ? '0 12px 28px -8px rgba(0,0,0,0.4)' : undefined,
  };

  const buttonContent = (
    <Button
      ref={(el) => {
        setNodeRef(el);
        tabRef(el);
      }}
      variant={isActive ? "default" : "outline"}
      size="sm"
      onClick={() => {
        if (!isDragMode) {
          onOpen(tab);
          if (notificationCount > 0) {
            onClearNotification(tab.id);
          }
        }
      }}
      className={cn(
        "rounded-full px-3 gap-1 shrink-0 relative transition-all duration-200 group",
        "hover:scale-105 hover:shadow-lg hover:shadow-primary/20",
        isDragMode && "cursor-grab active:cursor-grabbing ring-2 ring-primary/20 hover:ring-primary/40",
        isActive && "shadow-md shadow-primary/30",
        isDragging && "opacity-90 ring-2 ring-primary scale-105"
      )}
      style={style}
      {...(isDragMode ? { ...attributes, ...listeners } : {})}
    >
      {isDragMode && (
        <GripVertical className={cn(
          "h-3 w-3 transition-opacity duration-200",
          isDragging ? "opacity-100" : "opacity-50"
        )} />
      )}
      <DynamicIcon 
        icon={tab.icon} 
        fallback="🌐" 
        className={cn(
          "h-4 w-4 shrink-0 transition-transform duration-200",
          !isDragMode && "group-hover:scale-110"
        )} 
        style={tab.color ? { color: tab.color } : undefined} 
      />
      <span className="truncate max-w-[120px]">{tab.name}</span>
      {notificationCount > 0 && (
        <span className="bg-red-500 text-white text-[10px] font-bold rounded-full min-w-[16px] h-[16px] flex items-center justify-center px-1 animate-pulse">
          {notificationCount > 99 ? '99+' : notificationCount}
        </span>
      )}
      {tab.open_as_window && (
        <ExternalLink className="h-3 w-3 opacity-70" />
      )}
    </Button>
  );

  if (isDragMode) {
    return buttonContent;
  }

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        {buttonContent}
      </ContextMenuTrigger>
      <ContextMenuContent>
        <ContextMenuItem onClick={() => onEdit(tab.id)}>
          <Pencil className="mr-2 h-4 w-4" />
          Editar aba
        </ContextMenuItem>
        <ContextMenuSeparator />
        <ContextMenuItem onClick={() => onDelete(tab.id)} className="text-destructive focus:text-destructive">
          <Trash2 className="mr-2 h-4 w-4" />
          Excluir aba
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  );
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
    onFloatingSavePosition,
    removeAllListeners,
    getFloatingWindowsSession,
    clearFloatingWindowsSession,
    onTabOpenSettings,
  } = useElectron();
  const { toast } = useToast();
  const { settings } = useUserSettings();
  const { settings: localSettings, updateSettings: updateLocalSettings } = useLocalSettings();
  const browserContext = useBrowser();
  const { 
    groups = [], 
    activeGroup = null, 
    activeTab = null, 
    loading = true, 
    setActiveTab = () => {}, 
    tabNotifications = {}, 
    setTabNotification = () => {}, 
    reorderTabsInGroup, 
    moveTabToGroup, 
    isDragMode = false, 
    setIsDragMode,
    virtualTabs = [],
    activeVirtualTab = null,
    closeVirtualTab,
    setActiveVirtualTab,
  } = browserContext || {};
  // Ícones para abas virtuais
  const virtualTabIcons: Record<string, React.ReactNode> = {
    LayoutDashboard: <LayoutDashboard className="h-4 w-4" />,
    FolderOpen: <FolderOpen className="h-4 w-4" />,
    Keyboard: <Keyboard className="h-4 w-4" />,
    Key: <Key className="h-4 w-4" />,
    FileText: <FileText className="h-4 w-4" />,
    Settings: <Settings className="h-4 w-4" />,
  };

  // Renderizar conteúdo de aba virtual
  const renderVirtualTabContent = (route: string) => {
    switch (route) {
      case '/dashboard':
        return <DashboardPage />;
      case '/tab-groups':
        return <TabGroupsPage />;
      case '/shortcuts':
        return <ShortcutsPage />;
      case '/passwords':
        return <PasswordsPage />;
      case '/form-data':
        return <FormDataPage />;
      case '/settings':
        return <SettingsPage />;
      default:
        return null;
    }
  };

  // Sempre usar a versão “mais fresca” do grupo ativo a partir de `groups`
  // (senão os botões das abas podem ficar com dados antigos até recarregar)
  const uiActiveGroup = useMemo(() => {
    if (!activeGroup) return null;
    return groups.find(g => g.id === activeGroup.id) ?? activeGroup;
  }, [groups, activeGroup?.id]);
   
  const [textShortcuts, setTextShortcuts] = useState<TextShortcut[]>([]);
  const [keywords, setKeywords] = useState<Keyword[]>([]);
  
  // Manter registro de quais abas já foram abertas (para manter webviews em memória)
  const [openedTabIds, setOpenedTabIds] = useState<Set<string>>(new Set());
  
  // Estado para diálogo de restauração de sessão
  const [showRestoreDialog, setShowRestoreDialog] = useState(false);
  const [savedSession, setSavedSession] = useState<Array<{ tabId: string }> | null>(null);
  const sessionCheckDone = useRef(false);
  
  // Estado para barra de atalhos
  const [showShortcutsBar, setShowShortcutsBar] = useState(false);
  
  // Estado para dialog de edição de aba
  const [editingTabId, setEditingTabId] = useState<string | null>(null);
  
  // Estado para aba sendo arrastada
  const [draggingTabId, setDraggingTabId] = useState<string | null>(null);
  
  // Overflow tabs state
  const [visibleTabs, setVisibleTabs] = useState<Tab[]>([]);
  const [overflowTabs, setOverflowTabs] = useState<Tab[]>([]);
  const tabsContainerRef = useRef<HTMLDivElement>(null);
  const tabRefs = useRef<Map<string, HTMLButtonElement>>(new Map());

  // DnD sensors
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  // Handler para início do arraste
  const handleDragStart = useCallback((event: DragStartEvent) => {
    setDraggingTabId(event.active.id as string);
  }, []);

  // Handler para reordenar abas via drag-and-drop
  const handleDragEnd = useCallback(async (event: DragEndEvent) => {
    const { active, over } = event;
    setDraggingTabId(null);
    
    if (!over || !activeGroup || !user) return;

    const overId = over.id as string;
    
    // Verificar se soltou em um grupo diferente
    if (overId.startsWith('group-')) {
      const targetGroupId = overId.replace('group-', '');
      if (targetGroupId !== activeGroup.id) {
        const tabId = active.id as string;
        
        // Atualizar estado local imediatamente
        if (moveTabToGroup) {
          moveTabToGroup(tabId, activeGroup.id, targetGroupId);
        }
        
        // Atualizar no banco de dados
        try {
          // Buscar grupo destino para calcular nova posição
          const targetGroup = groups.find(g => g.id === targetGroupId);
          const newPosition = targetGroup ? targetGroup.tabs.length : 0;
          
          await supabase
            .from('tabs')
            .update({ group_id: targetGroupId, position: newPosition })
            .eq('id', tabId)
            .eq('user_id', user.id);
          
          toast({ title: 'Aba movida para outro grupo' });
          
          // Refresh para garantir sincronização
          if (browserContext?.refreshData) {
            browserContext.refreshData();
          }
        } catch (error) {
          console.error('Erro ao mover aba:', error);
          toast({ title: 'Erro ao mover aba', variant: 'destructive' });
          if (browserContext?.refreshData) {
            browserContext.refreshData();
          }
        }
        return;
      }
    }

    // Reordenar dentro do mesmo grupo
    if (active.id === over.id) return;

    const oldIndex = activeGroup.tabs.findIndex(t => t.id === active.id);
    const newIndex = activeGroup.tabs.findIndex(t => t.id === over.id);

    if (oldIndex === -1 || newIndex === -1) return;

    const reorderedTabs = arrayMove(activeGroup.tabs, oldIndex, newIndex);
    
    // Atualizar estado local imediatamente
    if (reorderTabsInGroup) {
      reorderTabsInGroup(activeGroup.id, reorderedTabs);
    }
    
    // Atualizar posições no banco de dados
    try {
      const updates = reorderedTabs.map((tab, index) => 
        supabase
          .from('tabs')
          .update({ position: index })
          .eq('id', tab.id)
          .eq('user_id', user.id)
      );
      
      await Promise.all(updates);
      
      toast({ title: 'Ordem das abas atualizada' });
    } catch (error) {
      console.error('Erro ao reordenar abas:', error);
      toast({ title: 'Erro ao reordenar', variant: 'destructive' });
      // Em caso de erro, recarregar do banco
      if (browserContext?.refreshData) {
        browserContext.refreshData();
      }
    }
  }, [activeGroup, user, reorderTabsInGroup, moveTabToGroup, groups, browserContext, toast]);

  // Handler para excluir aba com undo
  const handleDeleteTab = useCallback(async (tabId: string) => {
    if (!user || !activeGroup || !browserContext) return;
    
    // Encontrar a aba antes de excluir
    const tabToDelete = activeGroup.tabs.find(t => t.id === tabId);
    if (!tabToDelete) return;
    
    // Salvar dados para possível restauração
    const tabData = {
      id: tabToDelete.id,
      name: tabToDelete.name,
      url: tabToDelete.url,
      urls: tabToDelete.urls,
      layout_type: tabToDelete.layout_type,
      icon: tabToDelete.icon,
      color: tabToDelete.color,
      zoom: tabToDelete.zoom,
      position: tabToDelete.position,
      open_as_window: tabToDelete.open_as_window,
      keyboard_shortcut: tabToDelete.keyboard_shortcut,
      alternative_domains: tabToDelete.alternative_domains,
      show_link_transform_panel: tabToDelete.show_link_transform_panel,
      capture_token: tabToDelete.capture_token,
      capture_token_header: tabToDelete.capture_token_header,
      group_id: activeGroup.id,
    };
    
    try {
      const { error } = await supabase
        .from('tabs')
        .delete()
        .eq('id', tabId)
        .eq('user_id', user.id);
      
      if (error) throw error;
      
      // Se era a aba ativa, limpar seleção
      if (activeTab?.id === tabId) {
        setActiveTab(null);
      }
      
      // Remover da lista de abas abertas
      setOpenedTabIds(prev => {
        const next = new Set(prev);
        next.delete(tabId);
        return next;
      });
      
      // Atualizar UI
      browserContext.refreshData();
      
      // Mostrar toast com opção de desfazer
      sonnerToast.success('Aba excluída', {
        description: `"${tabData.name}" foi removida`,
        action: {
          label: 'Desfazer',
          onClick: async () => {
            try {
              const { error: restoreError } = await supabase
                .from('tabs')
                .insert({
                  id: tabData.id,
                  user_id: user.id,
                  group_id: tabData.group_id,
                  name: tabData.name,
                  url: tabData.url,
                  urls: tabData.urls as any,
                  layout_type: tabData.layout_type,
                  icon: tabData.icon,
                  color: tabData.color,
                  zoom: tabData.zoom,
                  position: tabData.position,
                  open_as_window: tabData.open_as_window,
                  keyboard_shortcut: tabData.keyboard_shortcut,
                  alternative_domains: tabData.alternative_domains as any,
                  show_link_transform_panel: tabData.show_link_transform_panel,
                  capture_token: tabData.capture_token,
                  capture_token_header: tabData.capture_token_header,
                });
              
              if (restoreError) throw restoreError;
              
              sonnerToast.success('Aba restaurada!');
              browserContext.refreshData();
            } catch (restoreErr: any) {
              sonnerToast.error('Erro ao restaurar aba');
              console.error(restoreErr);
            }
          },
        },
        duration: 8000, // 8 segundos para dar tempo de desfazer
      });
    } catch (error: any) {
      toast({ title: 'Erro ao excluir aba', description: error.message, variant: 'destructive' });
    }
  }, [user, activeGroup, activeTab, setActiveTab, browserContext, toast]);

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

    // Escutar pedidos de salvar posição da janela flutuante
    onFloatingSavePosition((data: WindowBoundsData) => {
      saveWindowBounds(data.tabId, { 
        window_x: data.x, 
        window_y: data.y,
        window_width: data.width,
        window_height: data.height,
        zoom: data.zoom,
      });
      toast({ title: 'Posição e zoom salvos' });
    });

    return () => {
      removeAllListeners('window:boundsChanged');
      removeAllListeners('floating:requestSavePosition');
    };
  }, [isElectron, saveWindowBounds, onWindowBoundsChanged, onFloatingSavePosition, removeAllListeners, toast]);

  // Função para carregar shortcuts e keywords
  const fetchExtras = useCallback(async () => {
    if (!user) return;

    const [shortcutsRes, keywordsRes] = await Promise.all([
      supabase.from('text_shortcuts').select('command, expanded_text, description, auto_send, messages'),
      supabase.from('keywords').select('key, value'),
    ]);

    // Converter messages de Json para ShortcutMessage[]
    const shortcuts: TextShortcut[] = (shortcutsRes.data || []).map(s => ({
      command: s.command,
      expanded_text: s.expanded_text,
      description: s.description || undefined,
      auto_send: s.auto_send,
      messages: Array.isArray(s.messages) ? (s.messages as unknown as ShortcutMessage[]) : undefined,
    }));
    setTextShortcuts(shortcuts);
    setKeywords(keywordsRes.data || []);
  }, [user]);

  // Carregar shortcuts e keywords inicial
  useEffect(() => {
    fetchExtras();
  }, [fetchExtras]);

  // Subscription em tempo real para text_shortcuts e keywords
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('tabviewer-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'text_shortcuts' },
        () => {
          console.log('[TabViewer] text_shortcuts changed, reloading...');
          fetchExtras();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'keywords' },
        () => {
          console.log('[TabViewer] keywords changed, reloading...');
          fetchExtras();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, fetchExtras]);

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
    
    let restoredCount = 0;
    
    for (const saved of savedSession) {
      // Buscar dados frescos do Supabase para cada aba
      const { data: tab, error } = await supabase
        .from('tabs')
        .select('*')
        .eq('id', saved.tabId)
        .single();
      
      if (error || !tab) {
        console.error('[TabViewer] Erro ao buscar aba para restaurar:', saved.tabId, error);
        continue;
      }
      
      if (tab.open_as_window) {
        const tabUrls = Array.isArray(tab.urls) ? tab.urls as { url: string; shortcut_enabled?: boolean; zoom?: number; session_group?: string }[] : [];
        const urls = tabUrls.length > 0 
          ? tabUrls
          : [{ url: tab.url, shortcut_enabled: true, zoom: tab.zoom ?? 100 }];
        
        await createWindow({
          id: tab.id,
          name: tab.name,
          url: tab.url,
          urls: urls,
          layout_type: tab.layout_type ?? undefined,
          zoom: tab.zoom ?? undefined,
          window_x: tab.window_x ?? undefined,
          window_y: tab.window_y ?? undefined,
          window_width: tab.window_width ?? undefined,
          window_height: tab.window_height ?? undefined,
          textShortcuts: textShortcuts,
          keywords: keywords,
          alternative_domains: Array.isArray(tab.alternative_domains) ? tab.alternative_domains as string[] : [],
          show_link_transform_panel: tab.show_link_transform_panel ?? undefined,
          capture_token: tab.capture_token === true,  // Forçar boolean
          capture_token_header: tab.capture_token_header ?? undefined,
          link_click_behavior: settings.browser.link_click_behavior,
          session_group: tab.session_group ?? undefined,
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
  }, [savedSession, createWindow, textShortcuts, keywords, clearFloatingWindowsSession, toast]);

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

  // Listener para abrir configurações de aba via janela flutuante
  useEffect(() => {
    if (!isElectron) return;
    
    onTabOpenSettings((tabId) => {
      console.log('[TabViewer] Recebido pedido para abrir settings da aba:', tabId);
      setEditingTabId(tabId);
    });
    
    return () => {
      removeAllListeners('tab:openSettings');
    };
  }, [isElectron, onTabOpenSettings, removeAllListeners]);

  // Adicionar aba à lista de abertas quando selecionada - imediato
  useEffect(() => {
    if (activeTab && !activeTab.open_as_window) {
      setOpenedTabIds(prev => new Set([...prev, activeTab.id]));
    }
  }, [activeTab?.id, activeTab?.open_as_window]);

  const handleOpenTab = async (tab: any) => {
    if (tab.open_as_window) {
      // Buscar dados mais recentes da aba do Supabase para garantir campos atualizados
      const { data: freshTab, error } = await supabase
        .from('tabs')
        .select('*')
        .eq('id', tab.id)
        .single();
      
      if (error) {
        console.error('[TabViewer] Erro ao buscar aba:', error);
      }
      
      const tabData = freshTab || tab;
      
      console.log('[TabViewer] Dados da aba (fresh):', {
        name: tabData.name,
        capture_token: tabData.capture_token,
        capture_token_header: tabData.capture_token_header,
        typeof_capture_token: typeof tabData.capture_token
      });
      
      const urls = tabData.urls && tabData.urls.length > 0 
        ? tabData.urls
        : [{ url: tabData.url, shortcut_enabled: true, zoom: tabData.zoom }];
      
      const result = await createWindow({
        id: tabData.id,
        name: tabData.name,
        url: tabData.url,
        urls: urls,
        layout_type: tabData.layout_type,
        zoom: tabData.zoom,
        window_x: tabData.window_x,
        window_y: tabData.window_y,
        window_width: tabData.window_width,
        window_height: tabData.window_height,
        textShortcuts: textShortcuts,
        keywords: keywords,
        alternative_domains: tabData.alternative_domains,
        show_link_transform_panel: tabData.show_link_transform_panel,
        capture_token: tabData.capture_token === true,  // Forçar boolean
        capture_token_header: tabData.capture_token_header,
        link_click_behavior: settings.browser.link_click_behavior,
        session_group: tabData.session_group,
      });
      
      if (result.success) {
        toast({ title: `${tabData.name} aberto em nova janela` });
      } else {
        toast({ title: 'Erro ao abrir janela', description: result.error, variant: 'destructive' });
      }
    } else {
      // Desativar aba virtual ao abrir aba normal
      if (setActiveVirtualTab && activeVirtualTab) {
        setActiveVirtualTab(null);
      }
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

  // Calculate visible and overflow tabs based on container width
  const calculateOverflow = useCallback(() => {
    const container = tabsContainerRef.current;
    if (!container || !uiActiveGroup) return;

    const containerWidth = container.clientWidth;
    const gap = 8; // gap entre abas
    let usedWidth = 0;
    const visible: Tab[] = [];
    const overflow: Tab[] = [];

    for (const tab of uiActiveGroup.tabs) {
      const tabElement = tabRefs.current.get(tab.id);
      const tabWidth = tabElement?.offsetWidth || 100; // fallback width

      // Container já é só para as abas, overflow button está fora
      if (usedWidth + tabWidth <= containerWidth) {
        visible.push(tab);
        usedWidth += tabWidth + gap;
      } else {
        overflow.push(tab);
      }
    }

    // Se sobrou espaço e temos overflow, tentar encaixar mais
    if (overflow.length > 0) {
      setVisibleTabs(visible);
      setOverflowTabs(overflow);
    } else {
      setVisibleTabs(uiActiveGroup.tabs);
      setOverflowTabs([]);
    }
  }, [uiActiveGroup]);

  // Observe container resize
  useLayoutEffect(() => {
    const container = tabsContainerRef.current;
    if (!container) return;

    const observer = new ResizeObserver(() => {
      calculateOverflow();
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, [calculateOverflow]);

  // Recalculate when active group changes OR when tabs data changes (name/icon/color/etc.)
  useEffect(() => {
    // Pequeno delay para garantir que os refs estejam atualizados
    const timer = setTimeout(calculateOverflow, 50);
    return () => clearTimeout(timer);
  }, [uiActiveGroup?.id, uiActiveGroup?.tabs, calculateOverflow]);

  // Lista de grupos para o dialog de edição (must be before early return)
  const groupsForDialog = useMemo(() => {
    return groups.map(g => ({ id: g.id, name: g.name, color: g.color || '#6366f1' }));
  }, [groups]);

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

      {/* Dialog de edição de aba */}
      <TabEditDialog
        open={!!editingTabId}
        onOpenChange={(open) => !open && setEditingTabId(null)}
        tabId={editingTabId || ''}
        groups={groupsForDialog}
        defaultGroupId={activeGroup?.id}
        onSaved={() => {
          // Refresh tab data from context
          if (browserContext?.refreshData) {
            browserContext.refreshData();
          }
        }}
      />

      <div className={cn("flex flex-col h-full", className)}>

        {/* Abas horizontais como pills com overflow */}
        {uiActiveGroup && uiActiveGroup.tabs.length > 0 && (
          <div className="border-b bg-muted/30 shrink-0">
            <div className="flex items-center w-full">
              {/* Esquerda - fixo: Botão de atalhos */}
              <div className="shrink-0 px-2 py-1">
                <Button
                  variant={showShortcutsBar ? "default" : "outline"}
                  size="sm"
                  className="rounded-full px-3 gap-1"
                  onClick={() => setShowShortcutsBar(!showShortcutsBar)}
                  title="Barra de atalhos rápidos"
                >
                  <Keyboard className="h-4 w-4" />
                </Button>
              </div>

              {/* Centro - flexível: Abas visíveis com DnD */}
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragStart={handleDragStart}
                onDragEnd={handleDragEnd}
              >
                <div 
                  ref={tabsContainerRef} 
                  className="flex-1 flex items-center gap-2 py-1 overflow-hidden min-w-0"
                >
                  {/* Renderizar todas as abas invisíveis para medir */}
                  <div className="absolute opacity-0 pointer-events-none flex gap-2" aria-hidden="true">
                    {uiActiveGroup.tabs.map(tab => (
                      <Button
                        key={`measure-${tab.id}`}
                        ref={(el) => {
                          if (el) tabRefs.current.set(tab.id, el);
                        }}
                        variant="outline"
                        size="sm"
                        className="rounded-full px-3 shrink-0 gap-2"
                      >
                        <GripVertical className="h-3 w-3 opacity-50" />
                        <DynamicIcon icon={tab.icon} fallback="🌐" className="h-4 w-4" style={tab.color ? { color: tab.color } : undefined} />
                        <span className="truncate max-w-[120px]">{tab.name}</span>
                        {tab.open_as_window && <ExternalLink className="h-3 w-3" />}
                      </Button>
                    ))}
                  </div>
                  
                  {/* Abas visíveis com drag-and-drop */}
                  <SortableContext 
                    items={visibleTabs.map(t => t.id)} 
                    strategy={horizontalListSortingStrategy}
                  >
                    {visibleTabs.map(tab => (
                      <SortableTabButton
                        key={tab.id}
                        tab={tab}
                        isActive={activeTab?.id === tab.id}
                        notificationCount={tabNotifications[tab.id] || 0}
                        onOpen={handleOpenTab}
                        onClearNotification={(tabId) => setTabNotification(tabId, 0)}
                        tabRef={(el) => {
                          if (el) tabRefs.current.set(tab.id, el);
                        }}
                        isDragMode={isDragMode}
                        onEdit={(tabId) => setEditingTabId(tabId)}
                        onDelete={(tabId) => handleDeleteTab(tabId)}
                      />
                    ))}
                  </SortableContext>
                  
                  {/* Drop zones para outros grupos (só aparecem quando arrastando) */}
                  {isDragMode && draggingTabId && groups.filter(g => g.id !== uiActiveGroup.id).length > 0 && (
                    <div className="flex items-center gap-2 ml-2 pl-2 border-l border-muted-foreground/30 relative z-[9998]">
                      {groups.filter(g => g.id !== uiActiveGroup.id).map(group => (
                        <DroppableGroup
                          key={group.id}
                          groupId={group.id}
                          groupName={group.name}
                          groupIcon={group.icon}
                          isActive={group.id === uiActiveGroup.id}
                          isDragging={!!draggingTabId}
                        />
                      ))}
                    </div>
                  )}
                </div>
              </DndContext>

              {/* Direita - fixo: Dropdown overflow e botão de editar */}
              <div className="shrink-0 px-2 py-1 flex items-center gap-1">
                {overflowTabs.length > 0 ? (
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="outline" size="sm" className="rounded-full px-3 gap-1">
                        <span>+{overflowTabs.length}</span>
                        <ChevronDown className="h-3 w-3" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="bg-popover z-50">
                      {overflowTabs.map(tab => {
                        const notificationCount = tabNotifications[tab.id] || 0;
                        return (
                          <DropdownMenuItem
                            key={tab.id}
                            className="flex items-center gap-2 cursor-pointer"
                            onClick={() => {
                              handleOpenTab(tab);
                              if (tabNotifications[tab.id]) {
                                setTabNotification(tab.id, 0);
                              }
                            }}
                          >
                            <DynamicIcon icon={tab.icon} fallback="🌐" className="h-4 w-4" style={tab.color ? { color: tab.color } : undefined} />
                            <span>{tab.name}</span>
                            {notificationCount > 0 && (
                              <span className="bg-red-500 text-white text-[10px] font-bold rounded-full min-w-[16px] h-[16px] flex items-center justify-center px-1">
                                {notificationCount > 99 ? '99+' : notificationCount}
                              </span>
                            )}
                            {tab.open_as_window && (
                              <ExternalLink className="h-3 w-3 opacity-70" />
                            )}
                          </DropdownMenuItem>
                        );
                      })}
                      {/* Botão de criar aba dentro do dropdown no mobile/tablet */}
                      <DropdownMenuItem
                        onClick={() => setEditingTabId('new')}
                        className="flex items-center gap-2 cursor-pointer text-primary"
                      >
                        <Plus className="h-4 w-4" />
                        <span>Nova aba</span>
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                ) : null}
                
                {/* Botão para criar nova aba - só visível no desktop ou quando não tem overflow */}
                <Button
                  variant="ghost"
                  size="sm"
                  className={cn(
                    "rounded-full h-8 w-8 p-0",
                    overflowTabs.length > 0 && "hidden lg:flex"
                  )}
                  onClick={() => setEditingTabId('new')}
                  title="Criar nova aba"
                >
                  <Plus className="h-4 w-4" />
                </Button>
                
                {/* Botão reordenar - oculto no mobile/tablet */}
                <Button
                  variant={isDragMode ? "default" : "outline"}
                  size="sm"
                  className="hidden lg:flex rounded-full px-3 gap-1"
                  onClick={() => setIsDragMode?.(!isDragMode)}
                  title={isDragMode ? "Finalizar reordenação" : "Reordenar abas e grupos"}
                >
                  {isDragMode ? <Check className="h-4 w-4" /> : <Pencil className="h-4 w-4" />}
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* Container principal com layout flexível para a barra de atalhos */}
        <div className={cn(
          "relative flex-1 flex min-h-0",
          localSettings.shortcuts_bar_mode === 'fixed' && localSettings.shortcuts_bar_position === 'bottom' ? "flex-col" : "flex-row"
        )}>
          {/* Barra de atalhos fixa - Esquerda */}
          {localSettings.shortcuts_bar_mode === 'fixed' && localSettings.shortcuts_bar_position === 'left' && (
            <ShortcutsBar
              position="left"
              shortcuts={textShortcuts}
              keywords={keywords}
              onClose={() => setShowShortcutsBar(false)}
              isOpen={showShortcutsBar}
              shortcutPrefix={settings.shortcuts.prefix}
              width={localSettings.shortcuts_bar_width}
              onResize={(size) => updateLocalSettings({ shortcuts_bar_width: size })}
            />
          )}

          {/* Container de webviews - mantém todos renderizados, mostra apenas o ativo */}
          <div className="flex-1 relative min-w-0 min-h-0 overflow-hidden">
            {/* Renderizar conteúdo de aba virtual se ativa */}
            <div 
              className={cn(
                "absolute inset-0 overflow-auto bg-background transition-all duration-300 ease-out",
                activeVirtualTab 
                  ? "opacity-100 translate-x-0" 
                  : "opacity-0 -translate-x-4 pointer-events-none"
              )}
            >
              {activeVirtualTab && (
                <Suspense fallback={
                  <div className="h-full flex items-center justify-center">
                    <div className="animate-pulse text-muted-foreground">Carregando...</div>
                  </div>
                }>
                  <div key={activeVirtualTab.id} className="animate-fade-in">
                    {renderVirtualTabContent(activeVirtualTab.route)}
                  </div>
                </Suspense>
              )}
            </div>
            
            {/* Renderizar todas as abas já abertas, ocultando as inativas */}
            <div 
              className={cn(
                "absolute inset-0 transition-all duration-300 ease-out",
                !activeVirtualTab 
                  ? "opacity-100 translate-x-0" 
                  : "opacity-0 translate-x-4 pointer-events-none"
              )}
            >
              {tabsToRender.map(tab => (
                <div
                  key={tab.id}
                  className={cn(
                    "absolute inset-0 transition-opacity duration-200",
                    activeTab?.id === tab.id ? "opacity-100" : "opacity-0 pointer-events-none"
                  )}
                >
                  <WebviewPanel
                    tab={tab}
                    textShortcuts={textShortcuts}
                    keywords={keywords}
                    onClose={() => setActiveTab(null)}
                    onNotificationChange={(count) => setTabNotification(tab.id, count)}
                    onEditTab={() => setEditingTabId(tab.id)}
                  />
                </div>
              ))}
            </div>

            {/* Placeholder quando nenhuma aba está selecionada */}
            {!activeTab && !activeVirtualTab && (
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

          {/* Barra de atalhos flutuante (overlay) */}
          {localSettings.shortcuts_bar_mode === 'floating' && showShortcutsBar && (
            localSettings.shortcuts_bar_position === 'bottom' ? (
              // Bottom: overlay dentro do container atual
              <div className="absolute inset-0 z-[9999] animate-fade-in">
                <div
                  className="absolute inset-0 bg-background/30"
                  onClick={() => setShowShortcutsBar(false)}
                />
                <div className="absolute left-0 right-0 bottom-0 animate-slide-in-bottom">
                  <ShortcutsBar
                    position="bottom"
                    shortcuts={textShortcuts}
                    keywords={keywords}
                    onClose={() => setShowShortcutsBar(false)}
                    isOpen={true}
                    shortcutPrefix={settings.shortcuts.prefix}
                    isFloating={true}
                    height={localSettings.shortcuts_bar_height}
                    onResize={(size) => updateLocalSettings({ shortcuts_bar_height: size })}
                  />
                </div>
              </div>
            ) : (
              // Left/Right: overlay fullscreen usando portal-like fixed positioning
              <div className="fixed inset-0 z-[9999] animate-fade-in">
                <div
                  className="absolute inset-0 bg-background/30"
                  onClick={() => setShowShortcutsBar(false)}
                />
                <div
                  className={cn(
                    "absolute top-0 bottom-0",
                    localSettings.shortcuts_bar_position === 'left' && "left-0 animate-slide-in-left",
                    localSettings.shortcuts_bar_position === 'right' && "right-0 animate-slide-in-right"
                  )}
                >
                  <ShortcutsBar
                    position={localSettings.shortcuts_bar_position}
                    shortcuts={textShortcuts}
                    keywords={keywords}
                    onClose={() => setShowShortcutsBar(false)}
                    isOpen={true}
                    shortcutPrefix={settings.shortcuts.prefix}
                    isFloating={true}
                    width={localSettings.shortcuts_bar_width}
                    onResize={(size) => updateLocalSettings({ shortcuts_bar_width: size })}
                  />
                </div>
              </div>
            )
          )}

          {/* Barra de atalhos fixa - Direita */}
          {localSettings.shortcuts_bar_mode === 'fixed' && localSettings.shortcuts_bar_position === 'right' && (
            <ShortcutsBar
              position="right"
              shortcuts={textShortcuts}
              keywords={keywords}
              onClose={() => setShowShortcutsBar(false)}
              isOpen={showShortcutsBar}
              shortcutPrefix={settings.shortcuts.prefix}
              width={localSettings.shortcuts_bar_width}
              onResize={(size) => updateLocalSettings({ shortcuts_bar_width: size })}
            />
          )}

          {/* Barra de atalhos fixa - Inferior */}
          {localSettings.shortcuts_bar_mode === 'fixed' && localSettings.shortcuts_bar_position === 'bottom' && (
            <ShortcutsBar
              position="bottom"
              shortcuts={textShortcuts}
              keywords={keywords}
              onClose={() => setShowShortcutsBar(false)}
              isOpen={showShortcutsBar}
              shortcutPrefix={settings.shortcuts.prefix}
              height={localSettings.shortcuts_bar_height}
              onResize={(size) => updateLocalSettings({ shortcuts_bar_height: size })}
            />
          )}
        </div>
      </div>
    </>
  );
}

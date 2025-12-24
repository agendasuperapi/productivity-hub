import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useElectron } from '@/hooks/useElectron';
import { WebviewPanel } from './WebviewPanel';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { 
  ChevronDown, 
  ChevronRight, 
  ExternalLink,
  Columns
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface TabUrl {
  url: string;
  shortcut_enabled?: boolean;
  zoom?: number;
}

interface Tab {
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
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  tabs: Tab[];
}

interface TextShortcut {
  command: string;
  expanded_text: string;
}

interface Keyword {
  key: string;
  value: string;
}

interface TabViewerProps {
  className?: string;
}

export function TabViewer({ className }: TabViewerProps) {
  const { user } = useAuth();
  const { isElectron, createWindow, onShortcutTriggered, registerShortcut, unregisterShortcut } = useElectron();
  const { toast } = useToast();
  
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [activeGroup, setActiveGroup] = useState<TabGroup | null>(null);
  const [activeTab, setActiveTab] = useState<Tab | null>(null);
  const [textShortcuts, setTextShortcuts] = useState<TextShortcut[]>([]);
  const [keywords, setKeywords] = useState<Keyword[]>([]);
  const [loading, setLoading] = useState(true);

  // Carregar dados
  useEffect(() => {
    async function fetchData() {
      if (!user) return;

      const [groupsRes, tabsRes, shortcutsRes, keywordsRes] = await Promise.all([
        supabase.from('tab_groups').select('*').order('position'),
        supabase.from('tabs').select('*').order('position'),
        supabase.from('text_shortcuts').select('command, expanded_text'),
        supabase.from('keywords').select('key, value'),
      ]);

      const groupsData = groupsRes.data || [];
      const tabsData = tabsRes.data || [];

      const groupsWithTabs: TabGroup[] = groupsData.map(group => ({
        ...group,
        tabs: tabsData
          .filter(tab => tab.group_id === group.id)
          .map(tab => ({
            ...tab,
            urls: Array.isArray(tab.urls) ? (tab.urls as unknown as TabUrl[]) : [],
          }))
      }));

      setGroups(groupsWithTabs);
      
      // Selecionar primeiro grupo automaticamente
      if (groupsWithTabs.length > 0) {
        setActiveGroup(groupsWithTabs[0]);
        if (groupsWithTabs[0].tabs.length > 0) {
          setActiveTab(groupsWithTabs[0].tabs[0]);
        }
      }
      
      setTextShortcuts(shortcutsRes.data || []);
      setKeywords(keywordsRes.data || []);
      setLoading(false);
    }

    fetchData();
  }, [user]);

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

  const handleSelectGroup = (group: TabGroup) => {
    setActiveGroup(group);
    // Selecionar primeira aba do grupo automaticamente
    if (group.tabs.length > 0) {
      const firstTab = group.tabs[0];
      if (!firstTab.open_as_window) {
        setActiveTab(firstTab);
      }
    }
  };

  const handleOpenTab = async (tab: Tab) => {
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

  if (loading) {
    return (
      <div className={cn("flex items-center justify-center", className)}>
        <div className="animate-pulse text-muted-foreground">Carregando...</div>
      </div>
    );
  }

  return (
    <div className={cn("flex h-full", className)}>
      {/* Sidebar com grupos */}
      <div className="w-56 border-r bg-sidebar flex flex-col">
        <div className="p-3 border-b">
          <h2 className="font-semibold text-sm flex items-center gap-2">
            <Columns className="h-4 w-4 text-primary" />
            Grupos
          </h2>
        </div>
        <ScrollArea className="flex-1">
          <div className="p-2 space-y-1">
            {groups.map(group => (
              <button
                key={group.id}
                onClick={() => handleSelectGroup(group)}
                className={cn(
                  "w-full flex items-center gap-2 p-2 rounded-md text-sm transition-colors",
                  activeGroup?.id === group.id 
                    ? "bg-primary text-primary-foreground" 
                    : "hover:bg-sidebar-accent"
                )}
              >
                <div 
                  className={cn(
                    "w-6 h-6 rounded flex items-center justify-center text-xs shrink-0",
                    activeGroup?.id === group.id ? "bg-primary-foreground/20" : "text-white"
                  )}
                  style={{ backgroundColor: activeGroup?.id === group.id ? undefined : (group.color || '#6366f1') }}
                >
                  {group.icon || '📁'}
                </div>
                <span className="flex-1 text-left truncate">{group.name}</span>
                <span className="text-xs opacity-70">{group.tabs.length}</span>
              </button>
            ))}

            {groups.length === 0 && (
              <div className="text-center py-8 text-muted-foreground text-sm">
                Nenhum grupo configurado
              </div>
            )}
          </div>
        </ScrollArea>
      </div>

      {/* Área principal */}
      <div className="flex-1 flex flex-col">
        {activeGroup ? (
          <>
            {/* Header com nome do grupo */}
            <div className="h-12 border-b flex items-center px-4 bg-background">
              <div 
                className="w-6 h-6 rounded flex items-center justify-center text-xs text-white shrink-0 mr-2"
                style={{ backgroundColor: activeGroup.color || '#6366f1' }}
              >
                {activeGroup.icon || '📁'}
              </div>
              <span className="font-medium">{activeGroup.name}</span>
              <span className="ml-2 text-xs text-muted-foreground">
                {activeGroup.tabs.length} {activeGroup.tabs.length === 1 ? 'aba' : 'abas'}
              </span>
            </div>

            {/* Abas horizontais como pills */}
            {activeGroup.tabs.length > 0 && (
              <div className="border-b bg-muted/30">
                <ScrollArea className="w-full">
                  <div className="flex items-center gap-2 p-2">
                    {activeGroup.tabs.map(tab => (
                      <Button
                        key={tab.id}
                        variant={activeTab?.id === tab.id ? "default" : "outline"}
                        size="sm"
                        onClick={() => handleOpenTab(tab)}
                        className={cn(
                          "rounded-full px-3 shrink-0 gap-2",
                          activeTab?.id === tab.id && "shadow-sm"
                        )}
                      >
                        <span className="text-sm">{tab.icon || '🌐'}</span>
                        <span className="truncate max-w-[120px]">{tab.name}</span>
                        {tab.open_as_window && (
                          <ExternalLink className="h-3 w-3 opacity-70" />
                        )}
                      </Button>
                    ))}
                  </div>
                </ScrollArea>
              </div>
            )}

            {/* Webview ou placeholder */}
            <div className="flex-1">
              {activeTab ? (
                <WebviewPanel
                  tab={activeTab}
                  textShortcuts={textShortcuts}
                  keywords={keywords}
                  onClose={() => setActiveTab(null)}
                />
              ) : (
                <div className="h-full flex items-center justify-center bg-muted/30">
                  <div className="text-center max-w-md px-4">
                    <div className="p-4 rounded-full bg-primary/10 w-fit mx-auto mb-4">
                      <Columns className="h-8 w-8 text-primary" />
                    </div>
                    <h3 className="text-lg font-semibold mb-2">
                      Selecione uma aba
                    </h3>
                    <p className="text-muted-foreground text-sm">
                      Clique em uma aba acima para visualizá-la.
                    </p>
                  </div>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="h-full flex items-center justify-center bg-muted/30">
            <div className="text-center max-w-md px-4">
              <div className="p-4 rounded-full bg-primary/10 w-fit mx-auto mb-4">
                <Columns className="h-8 w-8 text-primary" />
              </div>
              <h3 className="text-lg font-semibold mb-2">
                Selecione um grupo
              </h3>
              <p className="text-muted-foreground text-sm">
                Escolha um grupo na lista à esquerda para ver suas abas.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

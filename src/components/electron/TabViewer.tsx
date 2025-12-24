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
  const { isElectron, openExternal, createWindow, onShortcutTriggered, registerShortcut, unregisterShortcut } = useElectron();
  const { toast } = useToast();
  
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());
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
      setExpandedGroups(new Set(groupsData.map((g: any) => g.id)));
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
    
    // Registrar atalhos
    allTabs.forEach(tab => {
      if (tab.keyboard_shortcut) {
        registerShortcut(tab.keyboard_shortcut, tab.id);
      }
    });

    // Listener para atalhos
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

  const toggleGroup = (groupId: string) => {
    setExpandedGroups(prev => {
      const next = new Set(prev);
      if (next.has(groupId)) {
        next.delete(groupId);
      } else {
        next.add(groupId);
      }
      return next;
    });
  };

  const handleOpenTab = async (tab: Tab) => {
    if (tab.open_as_window) {
      // Abrir em janela Electron separada
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
      // Abrir no painel de webview
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
      {/* Sidebar com grupos e abas */}
      <div className="w-64 border-r bg-sidebar flex flex-col">
        <div className="p-3 border-b">
          <h2 className="font-semibold text-sm flex items-center gap-2">
            <Columns className="h-4 w-4 text-primary" />
            Abas Rápidas
          </h2>
        </div>
        <ScrollArea className="flex-1">
          <div className="p-2 space-y-1">
            {groups.map(group => (
              <div key={group.id}>
                <button
                  onClick={() => toggleGroup(group.id)}
                  className="w-full flex items-center gap-2 p-2 rounded-md hover:bg-sidebar-accent text-sm"
                >
                  <div 
                    className="w-6 h-6 rounded flex items-center justify-center text-xs text-white shrink-0"
                    style={{ backgroundColor: group.color || '#6366f1' }}
                  >
                    {group.icon || '📁'}
                  </div>
                  <span className="flex-1 text-left truncate">{group.name}</span>
                  {expandedGroups.has(group.id) ? (
                    <ChevronDown className="h-4 w-4 text-muted-foreground" />
                  ) : (
                    <ChevronRight className="h-4 w-4 text-muted-foreground" />
                  )}
                </button>

                {expandedGroups.has(group.id) && group.tabs.length > 0 && (
                  <div className="ml-4 mt-1 space-y-1">
                    {group.tabs.map(tab => (
                      <button
                        key={tab.id}
                        onClick={() => handleOpenTab(tab)}
                        className={cn(
                          "w-full flex items-center gap-2 p-2 rounded-md text-sm transition-colors",
                          activeTab?.id === tab.id 
                            ? "bg-primary/10 text-primary" 
                            : "hover:bg-sidebar-accent"
                        )}
                      >
                        <div 
                          className="w-5 h-5 rounded flex items-center justify-center text-xs text-white shrink-0"
                          style={{ backgroundColor: tab.color || '#22d3ee' }}
                        >
                          {tab.icon || '🌐'}
                        </div>
                        <span className="flex-1 text-left truncate">{tab.name}</span>
                        {tab.open_as_window && (
                          <ExternalLink className="h-3 w-3 text-muted-foreground" />
                        )}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            ))}

            {groups.length === 0 && (
              <div className="text-center py-8 text-muted-foreground text-sm">
                Nenhum grupo configurado
              </div>
            )}
          </div>
        </ScrollArea>
      </div>

      {/* Área principal - webview ou mensagem */}
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
                Clique em uma aba na lista à esquerda para visualizá-la aqui.
                {!isElectron && " No aplicativo Electron, você terá acesso completo às webviews."}
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

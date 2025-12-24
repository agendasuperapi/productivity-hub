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
    <div className={cn("flex flex-col h-full", className)}>
      {/* Header com aba ativa */}
      {activeTab && (
        <div className="h-12 border-b flex items-center justify-between px-4 bg-background shrink-0">
          <div className="flex items-center gap-2">
            <span className="text-lg">{activeTab.icon || '🌐'}</span>
            <span className="font-medium">{activeTab.name}</span>
          </div>
        </div>
      )}

      {/* Abas horizontais como pills */}
      {activeGroup && activeGroup.tabs.length > 0 && (
        <div className="border-b bg-muted/30 shrink-0">
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
  );
}

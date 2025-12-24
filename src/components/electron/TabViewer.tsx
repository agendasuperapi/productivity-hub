import { useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useElectron } from '@/hooks/useElectron';
import { useBrowser } from '@/contexts/BrowserContext';
import { WebviewPanel } from './WebviewPanel';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { ExternalLink, Columns } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useState } from 'react';

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
  const { groups, activeGroup, activeTab, loading, setActiveTab } = useBrowser();
  
  const [textShortcuts, setTextShortcuts] = useState<TextShortcut[]>([]);
  const [keywords, setKeywords] = useState<Keyword[]>([]);

  // Carregar shortcuts e keywords
  useEffect(() => {
    async function fetchExtras() {
      if (!user) return;

      const [shortcutsRes, keywordsRes] = await Promise.all([
        supabase.from('text_shortcuts').select('command, expanded_text'),
        supabase.from('keywords').select('key, value'),
      ]);

      setTextShortcuts(shortcutsRes.data || []);
      setKeywords(keywordsRes.data || []);
    }

    fetchExtras();
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

      {/* Abas horizontais como pills */}
      {activeGroup && activeGroup.tabs.length > 0 && (
        <div className="border-b bg-muted/30 shrink-0">
          <ScrollArea className="w-full">
            <div className="flex items-center gap-2 px-2 py-1">
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

import { useEffect, useState, useCallback, useMemo } from 'react';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/hooks/useAuth';
import { useCapacitor } from '@/hooks/useCapacitor';
import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { cn } from '@/lib/utils';
import { ExternalLink, Columns, Globe, Layout } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface TabViewerMobileProps {
  className?: string;
}

export function TabViewerMobile({ className }: TabViewerMobileProps) {
  const { user } = useAuth();
  const { openInAppBrowser, openInBrowser } = useCapacitor();
  const { toast } = useToast();
  const browserContext = useBrowser();
  const { 
    groups = [], 
    activeGroup = null, 
    activeTab = null, 
    loading = true, 
    setActiveTab = () => {} 
  } = browserContext || {};

  // Handle opening tab in mobile browser
  const handleOpenTab = useCallback(async (tab: any) => {
    // For multiple URLs, open only the first one or show a selector
    const url = tab.urls && tab.urls.length > 0 
      ? tab.urls[0].url 
      : tab.url;

    // Open in-app browser for better experience
    await openInAppBrowser(url);
    
    toast({ 
      title: tab.name, 
      description: 'Aberto no navegador' 
    });
  }, [openInAppBrowser, toast]);

  // Open externally in system browser
  const handleOpenExternal = useCallback(async (tab: any) => {
    const url = tab.urls && tab.urls.length > 0 
      ? tab.urls[0].url 
      : tab.url;

    await openInBrowser(url);
  }, [openInBrowser]);

  if (loading) {
    return (
      <div className={cn("flex items-center justify-center", className)}>
        <div className="animate-pulse text-muted-foreground">Carregando...</div>
      </div>
    );
  }

  return (
    <div className={cn("flex flex-col h-full", className)}>
      {/* Tab pills for current group */}
      {activeGroup && activeGroup.tabs.length > 0 && (
        <div className="border-b bg-muted/30 shrink-0">
          <ScrollArea className="w-full">
            <div className="flex items-center gap-2 px-3 py-2">
              {activeGroup.tabs.map(tab => (
                <Button
                  key={tab.id}
                  variant={activeTab?.id === tab.id ? "default" : "outline"}
                  size="sm"
                  onClick={() => setActiveTab(tab)}
                  className={cn(
                    "rounded-full px-4 shrink-0 gap-2",
                    activeTab?.id === tab.id && "shadow-sm"
                  )}
                >
                  <DynamicIcon icon={tab.icon} fallback="🌐" className="h-4 w-4" />
                  <span className="truncate max-w-[100px]">{tab.name}</span>
                </Button>
              ))}
            </div>
          </ScrollArea>
        </div>
      )}

      {/* Main content area */}
      <div className="flex-1 overflow-auto p-4">
        {!activeTab ? (
          // Placeholder when no tab selected
          <div className="h-full flex items-center justify-center">
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
                  : 'Toque em uma aba acima para visualizá-la.'}
              </p>
            </div>
          </div>
        ) : (
          // Tab details and actions
          <div className="space-y-4">
            {/* Tab header */}
            <div className="flex items-center gap-3 p-4 rounded-lg bg-card border">
              <div className="p-3 rounded-lg bg-primary/10">
                <DynamicIcon icon={activeTab.icon} fallback="🌐" className="h-6 w-6" />
              </div>
              <div className="flex-1 min-w-0">
                <h2 className="font-semibold truncate">{activeTab.name}</h2>
                <p className="text-sm text-muted-foreground truncate">
                  {activeTab.urls && activeTab.urls.length > 1 
                    ? `${activeTab.urls.length} URLs` 
                    : activeTab.url}
                </p>
              </div>
            </div>

            {/* URL list for multi-URL tabs */}
            {activeTab.urls && activeTab.urls.length > 0 && (
              <div className="space-y-2">
                <h3 className="text-sm font-medium text-muted-foreground px-1">
                  URLs ({activeTab.urls.length})
                </h3>
                {activeTab.urls.map((urlItem: any, index: number) => (
                  <Button
                    key={index}
                    variant="outline"
                    className="w-full justify-start gap-3 h-auto py-3"
                    onClick={() => openInAppBrowser(urlItem.url)}
                  >
                    <Globe className="h-4 w-4 shrink-0" />
                    <span className="truncate text-left flex-1">
                      {urlItem.url}
                    </span>
                    <ExternalLink className="h-4 w-4 shrink-0 opacity-50" />
                  </Button>
                ))}
              </div>
            )}

            {/* Action buttons */}
            <div className="grid grid-cols-2 gap-3 pt-4">
              <Button
                size="lg"
                className="gradient-primary"
                onClick={() => handleOpenTab(activeTab)}
              >
                <Layout className="h-5 w-5 mr-2" />
                Abrir In-App
              </Button>
              <Button
                size="lg"
                variant="outline"
                onClick={() => handleOpenExternal(activeTab)}
              >
                <ExternalLink className="h-5 w-5 mr-2" />
                Navegador
              </Button>
            </div>

            {/* Tab info */}
            <div className="p-4 rounded-lg bg-muted/30 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Layout</span>
                <span>{activeTab.layout_type || 'single'}</span>
              </div>
              {activeTab.keyboard_shortcut && (
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Atalho</span>
                  <code className="text-xs bg-background px-2 py-0.5 rounded">
                    {activeTab.keyboard_shortcut}
                  </code>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

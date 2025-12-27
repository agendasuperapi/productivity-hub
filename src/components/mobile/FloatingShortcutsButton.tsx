import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useCapacitor } from '@/hooks/useCapacitor';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { useToast } from '@/hooks/use-toast';
import { Keyboard, Search, Copy, Check, ChevronUp, Tag, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords } from '@/lib/shortcuts';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  category: string;
  description: string | null;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface Keyword {
  key: string;
  value: string;
}

const categories = [
  { value: 'all', label: 'Todos' },
  { value: 'geral', label: 'Geral' },
  { value: 'atendimento', label: 'Atendimento' },
  { value: 'vendas', label: 'Vendas' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'financeiro', label: 'Financeiro' },
];

export function FloatingShortcutsButton() {
  const { user } = useAuth();
  const { toast } = useToast();
  const { copyToClipboard, isCapacitor } = useCapacitor();
  
  const [isOpen, setIsOpen] = useState(false);
  const [shortcuts, setShortcuts] = useState<TextShortcut[]>([]);
  const [keywords, setKeywords] = useState<Keyword[]>([]);
  const [search, setSearch] = useState('');
  const [activeCategory, setActiveCategory] = useState('all');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [isMinimized, setIsMinimized] = useState(false);

  // Fetch shortcuts and keywords
  const fetchData = useCallback(async () => {
    if (!user) return;

    const [shortcutsRes, keywordsRes] = await Promise.all([
      supabase.from('text_shortcuts').select('*').order('command'),
      supabase.from('keywords').select('key, value'),
    ]);

    if (shortcutsRes.data) {
      const data: TextShortcut[] = shortcutsRes.data.map(s => ({
        ...s,
        messages: Array.isArray(s.messages) ? s.messages as unknown as ShortcutMessage[] : undefined
      }));
      setShortcuts(data);
    }
    if (keywordsRes.data) {
      setKeywords(keywordsRes.data);
    }
  }, [user]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Real-time subscription
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('floating-shortcuts-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'text_shortcuts' },
        () => fetchData()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'keywords' },
        () => fetchData()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, fetchData]);

  // Filter shortcuts
  const filteredShortcuts = shortcuts.filter(s => {
    const matchesSearch = 
      s.command.toLowerCase().includes(search.toLowerCase()) ||
      s.expanded_text.toLowerCase().includes(search.toLowerCase()) ||
      (s.description?.toLowerCase().includes(search.toLowerCase()));
    const matchesCategory = activeCategory === 'all' || s.category === activeCategory;
    return matchesSearch && matchesCategory;
  });

  // Copy shortcut text to clipboard
  const handleCopy = async (shortcut: TextShortcut) => {
    // Get the full text with all messages
    let fullText: string;
    
    if (shortcut.messages && shortcut.messages.length > 0) {
      fullText = shortcut.messages.map(m => m.text).join('\n\n');
    } else {
      fullText = shortcut.expanded_text;
    }

    // Apply keywords
    const processedText = applyKeywords(fullText, keywords);

    const success = await copyToClipboard(processedText);
    
    if (success) {
      setCopiedId(shortcut.id);
      toast({ title: 'Copiado!', description: shortcut.command });
      setTimeout(() => setCopiedId(null), 2000);
    } else {
      toast({ title: 'Erro ao copiar', variant: 'destructive' });
    }
  };

  // Don't render if not on Capacitor (mobile/tablet)
  if (!isCapacitor) return null;

  return (
    <>
      {/* Floating Button */}
      {!isOpen && (
        <div 
          className={cn(
            "fixed z-50 transition-all duration-300",
            isMinimized 
              ? "bottom-4 right-4" 
              : "bottom-6 right-6"
          )}
        >
          <Button
            size="lg"
            className={cn(
              "rounded-full shadow-lg gradient-primary h-14 w-14",
              !isMinimized && "h-16 w-16"
            )}
            onClick={() => setIsOpen(true)}
          >
            <Keyboard className={cn("h-6 w-6", !isMinimized && "h-7 w-7")} />
          </Button>
          
          {/* Minimize toggle */}
          <Button
            variant="secondary"
            size="icon"
            className="absolute -top-2 -left-2 h-6 w-6 rounded-full shadow"
            onClick={() => setIsMinimized(!isMinimized)}
          >
            {isMinimized ? <ChevronUp className="h-3 w-3" /> : <X className="h-3 w-3" />}
          </Button>
        </div>
      )}

      {/* Shortcuts Sheet */}
      <Sheet open={isOpen} onOpenChange={setIsOpen}>
        <SheetContent side="bottom" className="h-[80vh] rounded-t-2xl">
          <SheetHeader className="pb-4">
            <SheetTitle className="flex items-center gap-2">
              <Keyboard className="h-5 w-5" />
              Atalhos Rápidos
            </SheetTitle>
          </SheetHeader>

          {/* Search */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Buscar atalho..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-9"
            />
          </div>

          {/* Category Tabs */}
          <Tabs value={activeCategory} onValueChange={setActiveCategory} className="mb-4">
            <TabsList className="w-full h-auto flex-wrap gap-1 bg-transparent p-0">
              {categories.map(cat => (
                <TabsTrigger
                  key={cat.value}
                  value={cat.value}
                  className="rounded-full data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
                >
                  {cat.label}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>

          {/* Shortcuts List */}
          <ScrollArea className="h-[calc(80vh-200px)]">
            <div className="space-y-2 pr-4">
              {filteredShortcuts.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  Nenhum atalho encontrado
                </div>
              ) : (
                filteredShortcuts.map(shortcut => (
                  <div
                    key={shortcut.id}
                    className="p-3 rounded-lg border bg-card hover:bg-accent/50 transition-colors"
                    onClick={() => handleCopy(shortcut)}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <code className="text-sm font-mono font-semibold text-primary">
                            {shortcut.command}
                          </code>
                          <Badge variant="secondary" className="text-[10px]">
                            {shortcut.category}
                          </Badge>
                        </div>
                        <p className="text-sm text-muted-foreground line-clamp-2">
                          {shortcut.description || shortcut.expanded_text}
                        </p>
                        {shortcut.messages && shortcut.messages.length > 1 && (
                          <span className="text-xs text-muted-foreground">
                            {shortcut.messages.length} mensagens
                          </span>
                        )}
                      </div>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="shrink-0"
                      >
                        {copiedId === shortcut.id ? (
                          <Check className="h-4 w-4 text-green-500" />
                        ) : (
                          <Copy className="h-4 w-4" />
                        )}
                      </Button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </ScrollArea>
        </SheetContent>
      </Sheet>
    </>
  );
}

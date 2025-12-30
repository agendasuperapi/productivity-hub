import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Search, X, Copy, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords } from '@/lib/shortcuts';

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

interface ShortcutsBarProps {
  position: 'left' | 'right' | 'bottom';
  shortcuts: TextShortcut[];
  keywords: Keyword[];
  onClose: () => void;
  isOpen: boolean;
  shortcutPrefix: string;
}

export function ShortcutsBar({ 
  position, 
  shortcuts, 
  keywords, 
  onClose, 
  isOpen,
  shortcutPrefix 
}: ShortcutsBarProps) {
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const filteredShortcuts = useMemo(() => {
    if (!search) return shortcuts;
    const lower = search.toLowerCase();
    return shortcuts.filter(s => 
      s.command.toLowerCase().includes(lower) || 
      s.expanded_text.toLowerCase().includes(lower) ||
      s.description?.toLowerCase().includes(lower)
    );
  }, [shortcuts, search]);

  const handleCopy = async (shortcut: TextShortcut) => {
    // Aplicar keywords ao texto
    const processedText = applyKeywords(shortcut.expanded_text, keywords);
    
    try {
      await navigator.clipboard.writeText(processedText);
      setCopiedId(shortcut.command);
      setTimeout(() => setCopiedId(null), 1500);
    } catch (error) {
      console.error('Erro ao copiar:', error);
    }
  };

  if (!isOpen) return null;

  const isHorizontal = position === 'bottom';

  return (
    <div 
      className={cn(
        "bg-background/95 backdrop-blur-sm border-border shrink-0",
        isHorizontal 
          ? "border-t h-[120px] w-full" 
          : "border-l w-[220px] h-full",
        position === 'left' && "border-l-0 border-r"
      )}
    >
      {/* Header */}
      <div className={cn(
        "flex items-center gap-2 p-2 border-b border-border",
        isHorizontal ? "flex-row" : "flex-col"
      )}>
        <div className={cn(
          "relative flex-1",
          isHorizontal ? "max-w-[200px]" : "w-full"
        )}>
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3 w-3 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar..."
            className="pl-7 h-7 text-xs"
          />
        </div>
        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 shrink-0"
          onClick={onClose}
        >
          <X className="h-4 w-4" />
        </Button>
      </div>

      {/* Shortcuts list */}
      <ScrollArea className={cn(
        isHorizontal ? "h-[72px]" : "h-[calc(100%-48px)]"
      )}>
        <div className={cn(
          "p-2 gap-1.5",
          isHorizontal 
            ? "flex flex-row flex-wrap" 
            : "flex flex-col"
        )}>
          {filteredShortcuts.map((shortcut) => (
            <Button
              key={shortcut.command}
              variant="outline"
              size="sm"
              onClick={() => handleCopy(shortcut)}
              className={cn(
                "justify-start gap-2 text-xs h-auto py-1.5 px-2",
                isHorizontal ? "shrink-0" : "w-full",
                copiedId === shortcut.command && "bg-green-500/20 border-green-500"
              )}
            >
              {copiedId === shortcut.command ? (
                <Check className="h-3 w-3 text-green-500 shrink-0" />
              ) : (
                <Copy className="h-3 w-3 opacity-50 shrink-0" />
              )}
              <span className="truncate">
                <span className="text-muted-foreground">{shortcutPrefix}</span>
                <span className="font-medium">{shortcut.command.replace(/^\//, '')}</span>
                {shortcut.description && (
                  <span className="text-muted-foreground ml-1">- {shortcut.description}</span>
                )}
              </span>
            </Button>
          ))}

          {filteredShortcuts.length === 0 && (
            <div className="text-xs text-muted-foreground text-center py-4">
              Nenhum atalho encontrado
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

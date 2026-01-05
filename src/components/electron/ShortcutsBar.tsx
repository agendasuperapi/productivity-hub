import { useState, useMemo, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { Search, X, Copy, Check, Plus, Pencil } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords, applyKeywordsWithHighlight } from '@/lib/shortcuts';
import { ShortcutEditDialog, type Shortcut, type Keyword, type ShortcutMessage } from '@/components/shortcuts/ShortcutEditDialog';

interface TextShortcut {
  id?: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
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
  const [showDialog, setShowDialog] = useState(false);
  const [editingShortcut, setEditingShortcut] = useState<Shortcut | null>(null);

  const filteredShortcuts = useMemo(() => {
    if (!search) return shortcuts;
    const lower = search.toLowerCase();
    return shortcuts.filter(s => 
      s.command.toLowerCase().includes(lower) || 
      s.expanded_text.toLowerCase().includes(lower) ||
      s.description?.toLowerCase().includes(lower)
    );
  }, [shortcuts, search]);

  const getFullText = (shortcut: TextShortcut): string => {
    if (shortcut.messages && shortcut.messages.length > 0) {
      return shortcut.messages.map(m => m.text).join('\n\n');
    }
    return shortcut.expanded_text;
  };

  const handleCopy = async (shortcut: TextShortcut) => {
    const fullText = getFullText(shortcut);
    const processedText = applyKeywords(fullText, keywords);
    
    try {
      await navigator.clipboard.writeText(processedText);
      setCopiedId(shortcut.command);
      setTimeout(() => setCopiedId(null), 1500);
    } catch (error) {
      console.error('Erro ao copiar:', error);
    }
  };

  const openNewDialog = useCallback(() => {
    setEditingShortcut(null);
    setShowDialog(true);
  }, []);

  const openEditDialog = useCallback((shortcut: TextShortcut) => {
    setEditingShortcut(shortcut as Shortcut);
    setShowDialog(true);
  }, []);

  const handleDialogClose = useCallback((open: boolean) => {
    setShowDialog(open);
    if (!open) {
      setEditingShortcut(null);
    }
  }, []);

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
            className="pl-7 pr-7 h-7 text-xs"
          />
          {search && (
            <Button
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0 h-7 w-7"
              onClick={() => setSearch('')}
            >
              <X className="h-3 w-3" />
            </Button>
          )}
        </div>
        <div className="flex gap-1 shrink-0">
          <Button
            variant="outline"
            size="icon"
            className="h-7 w-7"
            onClick={openNewDialog}
            title="Novo atalho"
          >
            <Plus className="h-4 w-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7"
            onClick={onClose}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Dialog compartilhado para criar/editar atalho */}
      <ShortcutEditDialog
        open={showDialog}
        onOpenChange={handleDialogClose}
        shortcut={editingShortcut}
        keywords={keywords}
      />

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
            <div key={shortcut.command} className={cn("flex items-center gap-1", isHorizontal ? "shrink-0" : "w-full")}>
              <TooltipProvider delayDuration={300}>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleCopy(shortcut)}
                      className={cn(
                        "justify-start gap-2 text-xs h-auto py-1.5 px-2 flex-1 min-w-0",
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
                  </TooltipTrigger>
                  <TooltipContent side="top" className="max-w-xs whitespace-pre-wrap text-xs">
                    <p className="font-medium mb-1">{shortcutPrefix}{shortcut.command.replace(/^\//, '')}</p>
                    <div className="text-muted-foreground space-y-2">
                      {shortcut.messages && shortcut.messages.length > 0 ? (
                        shortcut.messages.map((msg, msgIndex) => (
                          <div key={msgIndex} className={shortcut.messages!.length > 1 ? "border-l-2 border-primary/30 pl-2" : ""}>
                            {applyKeywordsWithHighlight(msg.text, keywords).map((part, i) => (
                              part.isHighlighted ? (
                                <span key={i} className="text-primary font-medium bg-primary/10 px-0.5 rounded">
                                  {part.text}
                                </span>
                              ) : (
                                <span key={i}>{part.text}</span>
                              )
                            ))}
                          </div>
                        ))
                      ) : (
                        applyKeywordsWithHighlight(shortcut.expanded_text, keywords).map((part, i) => (
                          part.isHighlighted ? (
                            <span key={i} className="text-primary font-medium bg-primary/10 px-0.5 rounded">
                              {part.text}
                            </span>
                          ) : (
                            <span key={i}>{part.text}</span>
                          )
                        ))
                      )}
                    </div>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
              <Button
                variant="ghost"
                size="icon"
                className="h-6 w-6 shrink-0"
                onClick={() => openEditDialog(shortcut)}
                title="Editar atalho"
              >
                <Pencil className="h-3 w-3" />
              </Button>
            </div>
          ))}
        </div>
      </ScrollArea>
    </div>
  );
}

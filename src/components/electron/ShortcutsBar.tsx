import { useState, useMemo, useRef, useCallback, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
} from '@/components/ui/context-menu';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Search, X, Copy, Check, Plus, Pencil, ArrowUpDown, GripVertical, Trash2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords, applyKeywordsWithHighlight } from '@/lib/shortcuts';
import { ShortcutEditDialog } from '@/components/shortcuts/ShortcutEditDialog';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcut {
  id?: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
  use_count?: number;
  created_at?: string;
}

interface Keyword {
  key: string;
  value: string;
  id?: string;
}

type SortOption = 'use_count' | 'command' | 'message';
type SortDirection = 'asc' | 'desc';

interface ShortcutsBarProps {
  position: 'left' | 'right' | 'bottom';
  shortcuts: TextShortcut[];
  keywords: Keyword[];
  onClose: () => void;
  isOpen: boolean;
  shortcutPrefix: string;
  isFloating?: boolean;
  width?: number;
  height?: number;
  onResize?: (size: number) => void;
}

export function ShortcutsBar({ 
  position, 
  shortcuts, 
  keywords, 
  onClose, 
  isOpen,
  shortcutPrefix,
  isFloating = false,
  width = 220,
  height = 120,
  onResize
}: ShortcutsBarProps) {
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showDialog, setShowDialog] = useState(false);
  const [editingShortcut, setEditingShortcut] = useState<TextShortcut | null>(null);
  const [sortBy, setSortBy] = useState<SortOption>('use_count');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [shortcutToDelete, setShortcutToDelete] = useState<TextShortcut | null>(null);
  const { toast } = useToast();

  const filteredShortcuts = useMemo(() => {
    let result = shortcuts;
    
    // Filter by search
    if (search) {
      const lower = search.toLowerCase();
      result = result.filter(s => 
        s.command.toLowerCase().includes(lower) || 
        s.expanded_text.toLowerCase().includes(lower) ||
        s.description?.toLowerCase().includes(lower)
      );
    }
    
    // Sort
    return [...result].sort((a, b) => {
      const direction = sortDirection === 'asc' ? 1 : -1;
      switch (sortBy) {
        case 'use_count':
          return ((b.use_count || 0) - (a.use_count || 0)) * direction;
        case 'command':
          return a.command.localeCompare(b.command) * direction;
        case 'message':
          return a.expanded_text.localeCompare(b.expanded_text) * direction;
        default:
          return 0;
      }
    });
  }, [shortcuts, search, sortBy, sortDirection]);

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

  const openNewDialog = () => {
    setEditingShortcut(null);
    setShowDialog(true);
  };

  const openEditDialog = (shortcut: TextShortcut) => {
    setEditingShortcut(shortcut);
    setShowDialog(true);
  };

  const confirmDelete = (shortcut: TextShortcut) => {
    setShortcutToDelete(shortcut);
    setDeleteDialogOpen(true);
  };

  const handleDelete = async () => {
    if (!shortcutToDelete?.id) return;
    
    try {
      const { error } = await supabase
        .from('text_shortcuts')
        .delete()
        .eq('id', shortcutToDelete.id);
      
      if (error) throw error;
      
      toast({ title: 'Atalho excluído!' });
    } catch (error: any) {
      toast({
        title: 'Erro ao excluir',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setDeleteDialogOpen(false);
      setShortcutToDelete(null);
    }
  };

  const isHorizontal = position === 'bottom';

  // Resize handling
  const containerRef = useRef<HTMLDivElement>(null);
  const isResizing = useRef(false);
  const startPos = useRef(0);
  const startSize = useRef(0);

  const handleResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    isResizing.current = true;
    startPos.current = isHorizontal ? e.clientY : e.clientX;
    startSize.current = isHorizontal ? height : width;
    
    const handleMouseMove = (e: MouseEvent) => {
      if (!isResizing.current) return;
      
      let delta: number;
      if (isHorizontal) {
        // Bottom: drag up increases height
        delta = startPos.current - e.clientY;
      } else if (position === 'left') {
        // Left: drag right increases width
        delta = e.clientX - startPos.current;
      } else {
        // Right: drag left increases width
        delta = startPos.current - e.clientX;
      }
      
      const newSize = Math.max(100, Math.min(600, startSize.current + delta));
      if (containerRef.current) {
        if (isHorizontal) {
          containerRef.current.style.height = `${newSize}px`;
        } else {
          containerRef.current.style.width = `${newSize}px`;
        }
      }
    };
    
    const handleMouseUp = (e: MouseEvent) => {
      if (isResizing.current) {
        isResizing.current = false;
        
        let delta: number;
        if (isHorizontal) {
          delta = startPos.current - e.clientY;
        } else if (position === 'left') {
          delta = e.clientX - startPos.current;
        } else {
          delta = startPos.current - e.clientX;
        }
        
        const newSize = Math.max(100, Math.min(600, startSize.current + delta));
        onResize?.(newSize);
      }
      
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
    
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }, [isHorizontal, position, width, height, onResize]);

  // Escape key handler
  useEffect(() => {
    if (!isOpen || !isFloating) return;
    
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, isFloating, onClose]);

  if (!isOpen) return null;

  // Convert keywords to the format expected by ShortcutEditDialog
  const keywordsWithId = keywords.map((k, i) => ({
    id: k.id || `keyword-${i}`,
    key: k.key,
    value: k.value,
  }));

  // Compute dynamic size styles
  const sizeStyle = isFloating 
    ? isHorizontal
      ? { height: height, width: '100%' }
      : { width: width, height: '100%' }
    : isHorizontal 
      ? { height: height, width: '100%' }
      : { width: width, height: '100%' };

  return (
    <div 
      ref={containerRef}
      style={sizeStyle}
      className={cn(
        "bg-background/95 backdrop-blur-sm border-border shrink-0 relative",
        isFloating 
          ? "border-0" 
          : isHorizontal 
            ? "border-t" 
            : "border-l",
        !isFloating && position === 'left' && "border-l-0 border-r"
      )}
    >
      {/* Resize handle */}
      <div
        onMouseDown={handleResizeStart}
        className={cn(
          "absolute z-10 flex items-center justify-center opacity-50 hover:opacity-100 transition-opacity cursor-grab active:cursor-grabbing",
          isHorizontal 
            ? "top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 w-12 h-4 cursor-ns-resize"
            : position === 'left'
              ? "right-0 top-1/2 translate-x-1/2 -translate-y-1/2 w-4 h-12 cursor-ew-resize"
              : "left-0 top-1/2 -translate-x-1/2 -translate-y-1/2 w-4 h-12 cursor-ew-resize"
        )}
      >
        <GripVertical className={cn("h-4 w-4 text-muted-foreground", isHorizontal && "rotate-90")} />
      </div>
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
          <Select value={sortBy} onValueChange={(v) => setSortBy(v as SortOption)}>
            <SelectTrigger className="h-7 w-[90px] text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent
              position="popper"
              sideOffset={4}
              className="z-[10050]"
            >
              <SelectItem value="use_count">Mais usados</SelectItem>
              <SelectItem value="command">Atalho</SelectItem>
              <SelectItem value="message">Mensagem</SelectItem>
            </SelectContent>
          </Select>
          <Button
            variant="outline"
            size="icon"
            className="h-7 w-7"
            onClick={() => setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc')}
            title={sortDirection === 'asc' ? 'Crescente' : 'Decrescente'}
          >
            <ArrowUpDown className={cn("h-3 w-3 transition-transform", sortDirection === 'asc' && "rotate-180")} />
          </Button>
          <Button
            variant="outline"
            size="icon"
            className="h-7 w-7"
            onClick={openNewDialog}
            title="Novo atalho"
          >
            <Plus className="h-4 w-4" />
          </Button>
          {!isFloating && (
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7"
              onClick={onClose}
            >
              <X className="h-4 w-4" />
            </Button>
          )}
        </div>
      </div>

      {/* Dialog reutilizável para criar/editar */}
      <ShortcutEditDialog
        open={showDialog}
        onOpenChange={setShowDialog}
        shortcut={editingShortcut}
        keywords={keywordsWithId}
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
            <ContextMenu key={shortcut.command}>
              <ContextMenuTrigger asChild>
                <div className={cn("flex items-center gap-1", isHorizontal ? "shrink-0" : "w-full")}>
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
                    className="h-6 w-6 shrink-0 opacity-50 hover:opacity-100"
                    onClick={() => openEditDialog(shortcut)}
                  >
                    <Pencil className="h-3 w-3" />
                  </Button>
                </div>
              </ContextMenuTrigger>
              <ContextMenuContent className="z-[10050]">
                <ContextMenuItem onClick={() => handleCopy(shortcut)}>
                  <Copy className="h-4 w-4 mr-2" />
                  Copiar
                </ContextMenuItem>
                <ContextMenuItem onClick={() => openEditDialog(shortcut)}>
                  <Pencil className="h-4 w-4 mr-2" />
                  Editar
                </ContextMenuItem>
                <ContextMenuItem 
                  onClick={() => confirmDelete(shortcut)}
                  className="text-destructive focus:text-destructive"
                >
                  <Trash2 className="h-4 w-4 mr-2" />
                  Excluir
                </ContextMenuItem>
              </ContextMenuContent>
            </ContextMenu>
          ))}

          {filteredShortcuts.length === 0 && (
            <div className="text-xs text-muted-foreground text-center py-4">
              Nenhum atalho encontrado
            </div>
          )}
        </div>
      </ScrollArea>

      {/* Delete confirmation dialog */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir atalho</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir o atalho <strong>{shortcutPrefix}{shortcutToDelete?.command}</strong>? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

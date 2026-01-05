import { useState, useMemo, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { Search, X, Copy, Check, Plus, Pencil } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords, applyKeywordsWithHighlight } from '@/lib/shortcuts';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
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
  const { user } = useAuth();
  const { toast } = useToast();
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showDialog, setShowDialog] = useState(false);
  const [saving, setSaving] = useState(false);
  const [editingShortcut, setEditingShortcut] = useState<TextShortcut | null>(null);
  
  // Form state
  const [formCommand, setFormCommand] = useState('');
  const [formExpandedText, setFormExpandedText] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formCategory, setFormCategory] = useState('geral');
  const [formAutoSend, setFormAutoSend] = useState(false);

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
    const processedText = applyKeywords(shortcut.expanded_text, keywords);
    
    try {
      await navigator.clipboard.writeText(processedText);
      setCopiedId(shortcut.command);
      setTimeout(() => setCopiedId(null), 1500);
    } catch (error) {
      console.error('Erro ao copiar:', error);
    }
  };

  const resetForm = useCallback(() => {
    setFormCommand('');
    setFormExpandedText('');
    setFormDescription('');
    setFormCategory('geral');
    setFormAutoSend(false);
    setEditingShortcut(null);
  }, []);

  const openNewDialog = useCallback(() => {
    resetForm();
    setShowDialog(true);
  }, [resetForm]);

  const openEditDialog = useCallback((shortcut: TextShortcut) => {
    setEditingShortcut(shortcut);
    setFormCommand(shortcut.command);
    setFormExpandedText(shortcut.expanded_text);
    setFormDescription(shortcut.description || '');
    setFormCategory(shortcut.category || 'geral');
    setFormAutoSend(shortcut.auto_send || false);
    setShowDialog(true);
  }, []);

  const handleSave = async () => {
    if (!user || !formCommand.trim() || !formExpandedText.trim()) return;
    
    setSaving(true);
    try {
      const command = formCommand.startsWith('/') ? formCommand : `/${formCommand}`;
      
      if (editingShortcut?.id) {
        // Atualizar atalho existente
        const { error } = await supabase
          .from('text_shortcuts')
          .update({
            command: command,
            expanded_text: formExpandedText,
            description: formDescription || null,
            category: formCategory,
            auto_send: formAutoSend,
          })
          .eq('id', editingShortcut.id);

        if (error) throw error;
        toast({ title: 'Atalho atualizado com sucesso' });
      } else {
        // Criar novo atalho
        const { error } = await supabase.from('text_shortcuts').insert({
          user_id: user.id,
          command: command,
          expanded_text: formExpandedText,
          description: formDescription || null,
          category: formCategory,
          auto_send: formAutoSend,
        });

        if (error) throw error;
        toast({ title: 'Atalho criado com sucesso' });
      }

      setShowDialog(false);
      resetForm();
    } catch (error) {
      console.error('Erro ao salvar atalho:', error);
      toast({ title: 'Erro ao salvar atalho', variant: 'destructive' });
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen) return null;

  const isHorizontal = position === 'bottom';
  const isEditing = !!editingShortcut;

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

      {/* Dialog para criar/editar atalho */}
      <Dialog open={showDialog} onOpenChange={(open) => {
        setShowDialog(open);
        if (!open) resetForm();
      }}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{isEditing ? 'Editar Atalho' : 'Novo Atalho de Texto'}</DialogTitle>
            <DialogDescription>
              {isEditing 
                ? 'Modifique os campos e clique em Salvar'
                : 'Crie um comando que será substituído pelo texto expandido'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="command">Comando</Label>
              <Input
                id="command"
                value={formCommand}
                onChange={(e) => setFormCommand(e.target.value)}
                placeholder="/meuatalho"
                className="font-mono"
              />
              <p className="text-xs text-muted-foreground">
                O prefixo "/" será adicionado automaticamente se não incluído
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="expanded_text">Texto Expandido</Label>
              <Textarea
                id="expanded_text"
                value={formExpandedText}
                onChange={(e) => setFormExpandedText(e.target.value)}
                placeholder="Digite o texto que será inserido..."
                rows={4}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Descrição (opcional)</Label>
              <Input
                id="description"
                value={formDescription}
                onChange={(e) => setFormDescription(e.target.value)}
                placeholder="Descrição curta do atalho"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="category">Categoria</Label>
              <Select value={formCategory} onValueChange={setFormCategory}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="geral">Geral</SelectItem>
                  <SelectItem value="vendas">Vendas</SelectItem>
                  <SelectItem value="suporte">Suporte</SelectItem>
                  <SelectItem value="marketing">Marketing</SelectItem>
                  <SelectItem value="outros">Outros</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-center justify-between">
              <Label htmlFor="auto_send">Enviar automaticamente</Label>
              <Switch
                id="auto_send"
                checked={formAutoSend}
                onCheckedChange={setFormAutoSend}
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowDialog(false)}>
              Cancelar
            </Button>
            <Button 
              onClick={handleSave} 
              disabled={saving || !formCommand.trim() || !formExpandedText.trim()}
            >
              {saving ? 'Salvando...' : (isEditing ? 'Salvar' : 'Criar')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

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
                    <p className="text-muted-foreground">
                      {applyKeywordsWithHighlight(shortcut.expanded_text, keywords).map((part, i) => (
                        part.isHighlighted ? (
                          <span key={i} className="text-primary font-medium bg-primary/10 px-0.5 rounded">
                            {part.text}
                          </span>
                        ) : (
                          <span key={i}>{part.text}</span>
                        )
                      ))}
                    </p>
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
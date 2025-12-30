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
import { Search, X, Copy, Check, Plus } from 'lucide-react';
import { cn } from '@/lib/utils';
import { applyKeywords } from '@/lib/shortcuts';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';

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
  const { user } = useAuth();
  const { toast } = useToast();
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showNewDialog, setShowNewDialog] = useState(false);
  const [saving, setSaving] = useState(false);
  
  // Form state para novo atalho
  const [newCommand, setNewCommand] = useState('');
  const [newExpandedText, setNewExpandedText] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newCategory, setNewCategory] = useState('geral');
  const [newAutoSend, setNewAutoSend] = useState(false);

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

  const resetNewForm = useCallback(() => {
    setNewCommand('');
    setNewExpandedText('');
    setNewDescription('');
    setNewCategory('geral');
    setNewAutoSend(false);
  }, []);

  const handleCreateShortcut = async () => {
    if (!user || !newCommand.trim() || !newExpandedText.trim()) return;
    
    setSaving(true);
    try {
      const command = newCommand.startsWith('/') ? newCommand : `/${newCommand}`;
      
      const { error } = await supabase.from('text_shortcuts').insert({
        user_id: user.id,
        command: command,
        expanded_text: newExpandedText,
        description: newDescription || null,
        category: newCategory,
        auto_send: newAutoSend,
      });

      if (error) throw error;

      toast({ title: 'Atalho criado com sucesso' });
      setShowNewDialog(false);
      resetNewForm();
    } catch (error) {
      console.error('Erro ao criar atalho:', error);
      toast({ title: 'Erro ao criar atalho', variant: 'destructive' });
    } finally {
      setSaving(false);
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
        <Button
          variant="outline"
          size="icon"
          className="h-7 w-7 shrink-0"
          onClick={() => setShowNewDialog(true)}
          title="Novo atalho"
        >
          <Plus className="h-4 w-4" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 shrink-0"
          onClick={onClose}
        >
          <X className="h-4 w-4" />
        </Button>
      </div>

      {/* Dialog para novo atalho */}
      <Dialog open={showNewDialog} onOpenChange={setShowNewDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Novo Atalho de Texto</DialogTitle>
            <DialogDescription>
              Crie um comando que será substituído pelo texto expandido
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="command">Comando</Label>
              <Input
                id="command"
                value={newCommand}
                onChange={(e) => setNewCommand(e.target.value)}
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
                value={newExpandedText}
                onChange={(e) => setNewExpandedText(e.target.value)}
                placeholder="Digite o texto que será inserido..."
                rows={4}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Descrição (opcional)</Label>
              <Input
                id="description"
                value={newDescription}
                onChange={(e) => setNewDescription(e.target.value)}
                placeholder="Descrição curta do atalho"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="category">Categoria</Label>
              <Select value={newCategory} onValueChange={setNewCategory}>
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
                checked={newAutoSend}
                onCheckedChange={setNewAutoSend}
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowNewDialog(false)}>
              Cancelar
            </Button>
            <Button 
              onClick={handleCreateShortcut} 
              disabled={saving || !newCommand.trim() || !newExpandedText.trim()}
            >
              {saving ? 'Criando...' : 'Criar'}
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

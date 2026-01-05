import { useState, useMemo, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Checkbox } from '@/components/ui/checkbox';
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
import { Search, X, Copy, Check, Plus, Pencil, Trash2, Eye, EyeOff } from 'lucide-react';
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
  id?: string;
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

const categories = [
  { value: 'geral', label: 'Geral' },
  { value: 'vendas', label: 'Vendas' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'outros', label: 'Outros' },
];

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
  const [formDescription, setFormDescription] = useState('');
  const [formCategory, setFormCategory] = useState('geral');
  const [messages, setMessages] = useState<ShortcutMessage[]>([{ text: '', auto_send: true }]);
  const [showPreview, setShowPreview] = useState(false);

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

  const addMessage = () => {
    setMessages([...messages, { text: '', auto_send: true }]);
  };

  const removeMessage = (index: number) => {
    if (messages.length > 1) {
      setMessages(messages.filter((_, i) => i !== index));
    }
  };

  const updateMessage = (index: number, field: 'text' | 'auto_send', value: string | boolean) => {
    const updated = [...messages];
    updated[index] = { ...updated[index], [field]: value };
    setMessages(updated);
  };

  const resetForm = useCallback(() => {
    setFormCommand('');
    setFormDescription('');
    setFormCategory('geral');
    setMessages([{ text: '', auto_send: true }]);
    setEditingShortcut(null);
    setShowPreview(false);
  }, []);

  const openNewDialog = useCallback(() => {
    resetForm();
    setShowDialog(true);
  }, [resetForm]);

  const openEditDialog = useCallback((shortcut: TextShortcut) => {
    setEditingShortcut(shortcut);
    setFormCommand(shortcut.command);
    setFormDescription(shortcut.description || '');
    setFormCategory(shortcut.category || 'geral');
    
    // Carregar mensagens
    if (shortcut.messages && shortcut.messages.length > 0) {
      setMessages(shortcut.messages);
    } else {
      setMessages([{ text: shortcut.expanded_text, auto_send: shortcut.auto_send || false }]);
    }
    
    setShowDialog(true);
  }, []);

  const handleSave = async () => {
    const hasText = messages.some(m => m.text.trim());
    if (!user || !formCommand.trim() || !hasText) return;
    
    setSaving(true);
    try {
      const command = formCommand.startsWith('/') ? formCommand : `/${formCommand}`;
      const expandedText = messages[0]?.text || '';
      
      if (editingShortcut?.id) {
        const { error } = await supabase
          .from('text_shortcuts')
          .update({
            command: command,
            expanded_text: expandedText,
            description: formDescription || null,
            category: formCategory,
            auto_send: messages[0]?.auto_send || false,
            messages: messages as unknown as any,
          })
          .eq('id', editingShortcut.id);

        if (error) throw error;
        toast({ title: 'Atalho atualizado com sucesso' });
      } else {
        const { error } = await supabase.from('text_shortcuts').insert({
          user_id: user.id,
          command: command,
          expanded_text: expandedText,
          description: formDescription || null,
          category: formCategory,
          auto_send: messages[0]?.auto_send || false,
          messages: messages as unknown as any,
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
          
          <div className="space-y-4 py-4 max-h-[60vh] overflow-y-auto">
            <div className="space-y-2">
              <Label htmlFor="command">Comando *</Label>
              <Input
                id="command"
                value={formCommand}
                onChange={(e) => setFormCommand(e.target.value.toLowerCase())}
                placeholder="/meuatalho"
                className="font-mono"
              />
              <p className="text-xs text-muted-foreground">
                Deve começar com / (ex: /pix, /atendimento)
              </p>
            </div>

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <Label>Mensagens *</Label>
                <Button type="button" variant="outline" size="sm" onClick={addMessage}>
                  <Plus className="h-4 w-4 mr-1" />
                  Adicionar mensagem
                </Button>
              </div>
              
              {messages.map((msg, index) => (
                <div key={index} className="space-y-2 p-3 border rounded-lg bg-muted/30">
                  <div className="flex items-start gap-2">
                    <Textarea 
                      placeholder="Digite a mensagem..." 
                      value={msg.text} 
                      onChange={e => updateMessage(index, 'text', e.target.value)} 
                      rows={3} 
                      className="flex-1" 
                    />
                    {messages.length > 1 && (
                      <Button 
                        type="button" 
                        variant="ghost" 
                        size="icon" 
                        className="text-destructive hover:text-destructive shrink-0" 
                        onClick={() => removeMessage(index)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    )}
                  </div>
                  <div className="flex items-center space-x-2">
                    <Checkbox 
                      id={`auto_send_${index}`} 
                      checked={msg.auto_send} 
                      onCheckedChange={checked => updateMessage(index, 'auto_send', checked as boolean)} 
                    />
                    <Label htmlFor={`auto_send_${index}`} className="text-sm cursor-pointer">
                      Enviar automaticamente
                    </Label>
                  </div>
                </div>
              ))}
              
              <div className="flex flex-wrap gap-1.5">
                <span className="text-xs text-muted-foreground self-center mr-1">Inserir:</span>
                {keywords.map(k => (
                  <Button 
                    key={k.id || k.key}
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-6 px-2 text-xs font-mono"
                    onClick={() => {
                      const lastIndex = messages.length - 1;
                      if (lastIndex >= 0) {
                        updateMessage(lastIndex, 'text', messages[lastIndex].text + `<${k.key}>`);
                      }
                    }}
                  >
                    &lt;{k.key}&gt;
                  </Button>
                ))}
                {['SAUDACAO', 'DATA', 'HORA'].map(autoKey => (
                  <Button 
                    key={autoKey}
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-6 px-2 text-xs font-mono text-primary"
                    onClick={() => {
                      const lastIndex = messages.length - 1;
                      if (lastIndex >= 0) {
                        updateMessage(lastIndex, 'text', messages[lastIndex].text + `<${autoKey}>`);
                      }
                    }}
                  >
                    &lt;{autoKey}&gt;
                  </Button>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="category">Categoria</Label>
                <Select value={formCategory} onValueChange={setFormCategory}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {categories.map(cat => (
                      <SelectItem key={cat.value} value={cat.value}>
                        {cat.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Descrição</Label>
                <Input
                  id="description"
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  placeholder="Opcional"
                />
              </div>
            </div>
          </div>

          {showPreview && (
            <div className="border rounded-lg p-3 bg-muted/50 space-y-2 max-h-40 overflow-y-auto">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium text-muted-foreground">Pré-visualização</span>
              </div>
              {messages.filter(m => m.text.trim()).map((msg, index) => (
                <div 
                  key={index} 
                  className={cn(
                    "text-sm whitespace-pre-wrap",
                    messages.filter(m => m.text.trim()).length > 1 && "border-l-2 border-primary/30 pl-2"
                  )}
                >
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
              ))}
              {!messages.some(m => m.text.trim()) && (
                <p className="text-sm text-muted-foreground italic">Nenhuma mensagem para visualizar</p>
              )}
            </div>
          )}

          <DialogFooter>
            <Button 
              type="button"
              variant="ghost" 
              size="sm"
              onClick={() => setShowPreview(!showPreview)}
              className="mr-auto"
            >
              {showPreview ? <EyeOff className="h-4 w-4 mr-1" /> : <Eye className="h-4 w-4 mr-1" />}
              {showPreview ? 'Ocultar' : 'Visualizar'}
            </Button>
            <Button variant="outline" onClick={() => setShowDialog(false)}>
              Cancelar
            </Button>
            <Button 
              onClick={handleSave} 
              disabled={saving || !formCommand.trim() || !messages.some(m => m.text.trim())}
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
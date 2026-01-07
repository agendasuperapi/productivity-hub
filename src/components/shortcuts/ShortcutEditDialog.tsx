import { useState, useEffect, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
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
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Plus, Trash2, Loader2, Save, Eye } from 'lucide-react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { useFormDraft } from '@/hooks/useFormDraft';
import { useUserSettings } from '@/hooks/useUserSettings';
import { ShortcutPreviewDialog } from './ShortcutPreviewDialog';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface Shortcut {
  id?: string;
  command: string;
  expanded_text: string;
  category?: string;
  description?: string | null;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface Keyword {
  id: string;
  key: string;
  value: string;
}

interface ShortcutEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  shortcut?: Shortcut | null;
  keywords?: Keyword[];
  existingCommands?: string[];
  onSaved?: () => void;
}

const categories = [
  { value: 'geral', label: 'Geral' },
  { value: 'atendimento', label: 'Atendimento' },
  { value: 'vendas', label: 'Vendas' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'financeiro', label: 'Financeiro' },
];

const defaultFormValues = {
  command: '' as string,
  messages: [{ text: '', auto_send: false }] as ShortcutMessage[],
  category: 'geral' as string,
  description: '' as string,
};

export function ShortcutEditDialog({
  open,
  onOpenChange,
  shortcut,
  keywords = [],
  existingCommands = [],
  onSaved,
}: ShortcutEditDialogProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const { settings } = useUserSettings();
  const [saving, setSaving] = useState(false);
  const [showPreview, setShowPreview] = useState(false);

  const shortcutPrefix = settings.shortcuts.prefix || '/';

  // Check for duplicate command
  const cleanCommand = (command: string) => command.replace(/^[\/!#@.]/, '').trim().toLowerCase();
  
  const isDuplicate = (cmd: string): boolean => {
    const clean = cleanCommand(cmd);
    if (!clean) return false;
    // Exclude current shortcut when editing
    const otherCommands = existingCommands.filter(c => 
      !shortcut?.id || cleanCommand(c) !== cleanCommand(shortcut.command)
    );
    return otherCommands.some(c => cleanCommand(c) === clean);
  };

  const generateSuggestions = (cmd: string): string[] => {
    const clean = cleanCommand(cmd);
    if (!clean) return [];
    const suggestions: string[] = [];
    
    // Try adding numbers
    for (let i = 2; i <= 5; i++) {
      const suggestion = `${clean}${i}`;
      if (!existingCommands.some(c => cleanCommand(c) === suggestion)) {
        suggestions.push(suggestion);
        if (suggestions.length >= 3) break;
      }
    }
    
    // Try common prefixes/suffixes
    const variations = [`${clean}_novo`, `meu_${clean}`, `${clean}_2`];
    for (const variation of variations) {
      if (!existingCommands.some(c => cleanCommand(c) === variation) && !suggestions.includes(variation)) {
        suggestions.push(variation);
        if (suggestions.length >= 3) break;
      }
    }
    
    return suggestions.slice(0, 3);
  };

  const formDraft = useFormDraft('shortcut-edit-dialog', defaultFormValues);

  const command = formDraft.values.command as string;
  const messages = formDraft.values.messages as ShortcutMessage[];
  const category = formDraft.values.category as string;
  const description = formDraft.values.description as string;

  const setCommand = (v: string) => formDraft.updateValue('command', v);
  const setMessages = (v: ShortcutMessage[]) => formDraft.updateValue('messages', v);
  const setCategory = (v: string) => formDraft.updateValue('category', v);
  const setDescription = (v: string) => formDraft.updateValue('description', v);

  const isEditing = !!shortcut?.id;

  // Load shortcut data when editing
  useEffect(() => {
    if (open && shortcut) {
      const msgs =
        shortcut.messages && shortcut.messages.length > 0
          ? shortcut.messages
          : [{ text: shortcut.expanded_text, auto_send: shortcut.auto_send || false }];

      formDraft.loadValues({
        command: shortcut.command,
        messages: msgs,
        category: shortcut.category || 'geral',
        description: shortcut.description || '',
      });
    } else if (open && !shortcut) {
      // New shortcut - check for draft
      if (!formDraft.hasDraft) {
        formDraft.resetToInitial();
      }
    }
  }, [open, shortcut]);

  const resetForm = useCallback(() => {
    formDraft.resetToInitial();
  }, [formDraft]);

  const handleClose = (value: boolean) => {
    if (!value) {
      resetForm();
      formDraft.clearDraft();
    }
    onOpenChange(value);
  };

  const addMessage = () => {
    setMessages([...messages, { text: '', auto_send: false }]);
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

  const openPreviewWindow = () => {
    const validMessages = messages.filter((m) => m.text.trim());
    if (validMessages.length === 0) {
      toast({
        title: 'Nenhuma mensagem para visualizar',
        variant: 'destructive',
      });
      return;
    }
    setShowPreview(true);
  };

  const handleSave = async () => {
    if (!user) return;

    // Remove o prefixo se o usuário digitou (para manter consistência)
    const cleanedCmd = command.replace(/^[\/!#@.]/, '').trim();

    // Check for duplicates
    if (isDuplicate(command)) {
      toast({
        title: 'Comando duplicado',
        description: 'Escolha um comando diferente ou use uma das sugestões',
        variant: 'destructive',
      });
      return;
    }

    const validMessages = messages.filter((m) => m.text.trim());
    if (!cleanedCmd || validMessages.length === 0) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Preencha o comando e pelo menos uma mensagem',
        variant: 'destructive',
      });
      return;
    }

    setSaving(true);

    const firstMessage = validMessages[0];

    try {
      if (isEditing && shortcut?.id) {
        const { error } = await supabase
          .from('text_shortcuts')
          .update({
            command: cleanedCmd.toLowerCase(),
            expanded_text: firstMessage.text,
            category,
            description: description || null,
            auto_send: firstMessage.auto_send,
            messages: validMessages as unknown as import('@/integrations/supabase/types').Json,
          })
          .eq('id', shortcut.id);

        if (error) throw error;
        toast({ title: 'Atalho atualizado!' });
      } else {
        const { error } = await supabase.from('text_shortcuts').insert({
          user_id: user.id,
          command: cleanedCmd.toLowerCase(),
          expanded_text: firstMessage.text,
          category,
          description: description || null,
          auto_send: firstMessage.auto_send,
          messages: validMessages as unknown as import('@/integrations/supabase/types').Json,
        });

        if (error) {
          if (error.message.includes('duplicate')) {
            toast({
              title: 'Comando já existe',
              description: 'Escolha outro comando',
              variant: 'destructive',
            });
          } else {
            throw error;
          }
          setSaving(false);
          return;
        }
        toast({ title: 'Atalho criado!' });
      }

      handleClose(false);
      onSaved?.();
    } catch (error: any) {
      toast({
        title: 'Erro ao salvar',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {isEditing ? 'Editar Atalho' : 'Novo Atalho de Texto'}
            {formDraft.hasDraft && !isEditing && (
              <span className="text-xs font-normal text-muted-foreground flex items-center gap-1">
                <Save className="h-3 w-3" />
                Rascunho salvo
              </span>
            )}
          </DialogTitle>
          <DialogDescription>
            Crie um comando que será substituído pelo texto expandido
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="command">Comando *</Label>
            <div className="flex items-center gap-2">
              <div className="flex items-center gap-0">
                <Tooltip>
                  <TooltipTrigger asChild>
                    <span className="px-3 h-9 flex items-center justify-center bg-muted border border-r-0 rounded-l-md text-sm font-mono text-muted-foreground cursor-help">
                      {shortcutPrefix}
                    </span>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>Prefixo atual: <strong>{shortcutPrefix}</strong></p>
                    <p className="text-xs text-muted-foreground">Altere em Configurações → Atalhos</p>
                  </TooltipContent>
                </Tooltip>
                <Input
                  id="command"
                  placeholder="obg"
                  value={command}
                  onChange={(e) => setCommand(e.target.value.toLowerCase().replace(/\s/g, ''))}
                  className={`rounded-l-none ${isDuplicate(command) ? 'border-destructive focus-visible:ring-destructive' : ''}`}
                />
              </div>
              {command && !isDuplicate(command) && (
                <span className="text-sm text-muted-foreground whitespace-nowrap">
                  → <code className="bg-muted px-1.5 py-0.5 rounded font-mono">{shortcutPrefix}{command}</code>
                </span>
              )}
            </div>
            
            {/* Duplicate warning with suggestions */}
            {command && isDuplicate(command) && (
              <div className="p-3 rounded-md bg-destructive/10 border border-destructive/30 space-y-2">
                <p className="text-sm text-destructive font-medium">
                  ⚠️ O comando "{shortcutPrefix}{command}" já existe
                </p>
                {generateSuggestions(command).length > 0 && (
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Sugestões alternativas:</p>
                    <div className="flex flex-wrap gap-1.5">
                      {generateSuggestions(command).map((suggestion) => (
                        <Button
                          key={suggestion}
                          type="button"
                          variant="outline"
                          size="sm"
                          className="h-7 text-xs font-mono"
                          onClick={() => setCommand(suggestion)}
                        >
                          {shortcutPrefix}{suggestion}
                        </Button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
            
            {!isDuplicate(command) && (
              <p className="text-xs text-muted-foreground">
                O prefixo "{shortcutPrefix}" pode ser alterado nas configurações.
              </p>
            )}
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
                    onChange={(e) => updateMessage(index, 'text', e.target.value)}
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
                    onCheckedChange={(checked) => updateMessage(index, 'auto_send', checked as boolean)}
                  />
                  <Label htmlFor={`auto_send_${index}`} className="text-sm cursor-pointer">
                    Enviar automaticamente
                  </Label>
                </div>
              </div>
            ))}

            <div className="flex flex-wrap gap-1.5">
              <span className="text-xs text-muted-foreground self-center mr-1">Inserir:</span>
              {keywords.map((k) => (
                <Button
                  key={k.id}
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
              {['SAUDACAO', 'DATA', 'HORA'].map((autoKey) => (
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
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {categories.map((cat) => (
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
                placeholder="Opcional"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
            </div>
          </div>
        </div>

        <DialogFooter className="gap-2 sm:gap-0">
          <Button 
            type="button" 
            variant="secondary" 
            onClick={openPreviewWindow}
            className="mr-auto"
          >
            <Eye className="h-4 w-4 mr-2" />
            Pré-visualizar
          </Button>
          <Button variant="outline" onClick={() => handleClose(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {isEditing ? 'Salvar' : 'Criar'}
          </Button>
        </DialogFooter>
      </DialogContent>

      {/* Preview Dialog */}
      <ShortcutPreviewDialog
        open={showPreview}
        onOpenChange={setShowPreview}
        messages={messages}
        keywords={keywords}
        title={command || undefined}
      />
    </Dialog>
  );
}

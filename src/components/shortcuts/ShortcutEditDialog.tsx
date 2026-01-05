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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Plus, Trash2, Loader2, Save } from 'lucide-react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';

export interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

export interface Shortcut {
  id?: string;
  command: string;
  expanded_text: string;
  category?: string;
  description?: string | null;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

export interface Keyword {
  id?: string;
  key: string;
  value: string;
}

const categories = [
  { value: 'geral', label: 'Geral' },
  { value: 'atendimento', label: 'Atendimento' },
  { value: 'vendas', label: 'Vendas' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'financeiro', label: 'Financeiro' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'outros', label: 'Outros' },
];

interface ShortcutEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  shortcut: Shortcut | null;
  keywords: Keyword[];
  onSaved?: () => void;
  showDraftIndicator?: boolean;
}

export function ShortcutEditDialog({
  open,
  onOpenChange,
  shortcut,
  keywords,
  onSaved,
  showDraftIndicator = false,
}: ShortcutEditDialogProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [saving, setSaving] = useState(false);
  
  // Form state
  const [command, setCommand] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('geral');
  const [messages, setMessages] = useState<ShortcutMessage[]>([{ text: '', auto_send: false }]);

  const isEditing = !!shortcut?.id;

  // Reset form when dialog opens/closes or shortcut changes
  useEffect(() => {
    if (open && shortcut) {
      setCommand(shortcut.command || '');
      setDescription(shortcut.description || '');
      setCategory(shortcut.category || 'geral');
      
      if (shortcut.messages && shortcut.messages.length > 0) {
        setMessages(shortcut.messages);
      } else if (shortcut.expanded_text) {
        setMessages([{ text: shortcut.expanded_text, auto_send: shortcut.auto_send || false }]);
      } else {
        setMessages([{ text: '', auto_send: false }]);
      }
    } else if (open && !shortcut) {
      // New shortcut
      setCommand('');
      setDescription('');
      setCategory('geral');
      setMessages([{ text: '', auto_send: false }]);
    }
  }, [open, shortcut]);

  const addMessage = useCallback(() => {
    setMessages(prev => [...prev, { text: '', auto_send: false }]);
  }, []);

  const removeMessage = useCallback((index: number) => {
    setMessages(prev => {
      if (prev.length > 1) {
        return prev.filter((_, i) => i !== index);
      }
      return prev;
    });
  }, []);

  const updateMessage = useCallback((index: number, field: 'text' | 'auto_send', value: string | boolean) => {
    setMessages(prev => {
      const updated = [...prev];
      updated[index] = { ...updated[index], [field]: value };
      return updated;
    });
  }, []);

  const handleSave = async () => {
    if (!user) return;

    // Validate command starts with /
    const cmdValue = command.trim();
    if (!cmdValue.startsWith('/')) {
      toast({
        title: 'Comando inválido',
        description: 'O comando deve começar com / (ex: /ola)',
        variant: 'destructive',
      });
      return;
    }

    // Filter empty messages
    const validMessages = messages.filter(m => m.text.trim());
    if (validMessages.length === 0) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Preencha pelo menos uma mensagem',
        variant: 'destructive',
      });
      return;
    }

    setSaving(true);

    const firstMessage = validMessages[0];
    const payload = {
      command: cmdValue.toLowerCase(),
      expanded_text: firstMessage.text,
      category,
      description: description || null,
      auto_send: firstMessage.auto_send,
      messages: validMessages as unknown as import('@/integrations/supabase/types').Json,
    };

    try {
      if (isEditing && shortcut?.id) {
        const { error } = await supabase
          .from('text_shortcuts')
          .update(payload)
          .eq('id', shortcut.id);

        if (error) throw error;
        toast({ title: 'Atalho atualizado!' });
      } else {
        const { error } = await supabase
          .from('text_shortcuts')
          .insert({ ...payload, user_id: user.id });

        if (error) {
          if (error.message.includes('duplicate')) {
            toast({
              title: 'Comando já existe',
              description: 'Escolha outro comando',
              variant: 'destructive',
            });
            setSaving(false);
            return;
          }
          throw error;
        }
        toast({ title: 'Atalho criado!' });
      }

      onOpenChange(false);
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
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {isEditing ? 'Editar Atalho' : 'Novo Atalho de Texto'}
            {showDraftIndicator && !isEditing && (
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

        <div className="space-y-4 py-4 max-h-[60vh] overflow-y-auto">
          <div className="space-y-2">
            <Label htmlFor="command">Comando *</Label>
            <Input
              id="command"
              placeholder="/ola"
              value={command}
              onChange={e => setCommand(e.target.value.toLowerCase())}
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
              <Select value={category} onValueChange={setCategory}>
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
                placeholder="Opcional"
                value={description}
                onChange={e => setDescription(e.target.value)}
              />
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {isEditing ? 'Salvar' : 'Criar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

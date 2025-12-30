import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Plus, Search, Keyboard, Trash2, Pencil, Copy, FileDown, FileUp, Loader2, Save } from 'lucide-react';
import { useFormDraft } from '@/hooks/useFormDraft';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}
interface Shortcut {
  id: string;
  command: string;
  expanded_text: string;
  category: string;
  description: string | null;
  auto_send: boolean;
  messages?: ShortcutMessage[];
}
const categories = [{
  value: 'geral',
  label: 'Geral'
}, {
  value: 'atendimento',
  label: 'Atendimento'
}, {
  value: 'vendas',
  label: 'Vendas'
}, {
  value: 'suporte',
  label: 'Suporte'
}, {
  value: 'financeiro',
  label: 'Financeiro'
}];

const defaultShortcutFormValues = {
  command: '' as string,
  messages: [{ text: '', auto_send: false }] as ShortcutMessage[],
  category: 'geral' as string,
  description: '' as string,
};

export default function Shortcuts() {
  const {
    user
  } = useAuth();
  const {
    toast
  } = useToast();
  const [shortcuts, setShortcuts] = useState<Shortcut[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filterCategory, setFilterCategory] = useState('all');
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingShortcut, setEditingShortcut] = useState<Shortcut | null>(null);
  const [saving, setSaving] = useState(false);

  // Form with auto-save
  const formDraft = useFormDraft('shortcuts-form', defaultShortcutFormValues);
  
  // Derived values
  const command = formDraft.values.command as string;
  const messages = formDraft.values.messages as ShortcutMessage[];
  const category = formDraft.values.category as string;
  const description = formDraft.values.description as string;
  
  const setCommand = (v: string) => formDraft.updateValue('command', v);
  const setMessages = (v: ShortcutMessage[]) => formDraft.updateValue('messages', v);
  const setCategory = (v: string) => formDraft.updateValue('category', v);
  const setDescription = (v: string) => formDraft.updateValue('description', v);
  // Carregar dados inicial
  useEffect(() => {
    fetchShortcuts();
  }, [user]);

  // Subscription em tempo real para text_shortcuts
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('shortcuts-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'text_shortcuts' },
        () => {
          console.log('[Shortcuts] text_shortcuts changed, reloading...');
          fetchShortcuts();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user]);

  async function fetchShortcuts() {
    if (!user) return;
    const {
      data,
      error
    } = await supabase.from('text_shortcuts').select('*').order('created_at', {
      ascending: false
    });
    if (error) {
      toast({
        title: 'Erro ao carregar atalhos',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      // Converter messages de Json para ShortcutMessage[]
      const shortcuts: Shortcut[] = (data || []).map(s => ({
        ...s,
        messages: Array.isArray(s.messages) ? s.messages as unknown as ShortcutMessage[] : undefined
      }));
      setShortcuts(shortcuts);
    }
    setLoading(false);
  }
  const resetForm = useCallback(() => {
    formDraft.resetToInitial();
    setEditingShortcut(null);
  }, [formDraft]);
  function openEditDialog(shortcut: Shortcut) {
    setEditingShortcut(shortcut);
    // Carregar messages se existir, senão usar expanded_text/auto_send
    const msgs = (shortcut.messages && shortcut.messages.length > 0) 
      ? shortcut.messages 
      : [{ text: shortcut.expanded_text, auto_send: shortcut.auto_send || false }];
    
    formDraft.loadValues({
      command: shortcut.command,
      messages: msgs,
      category: shortcut.category,
      description: shortcut.description || '',
    });
    setIsDialogOpen(true);
  }

  // Funções para gerenciar múltiplas mensagens
  const addMessage = () => {
    setMessages([...messages, {
      text: '',
      auto_send: false
    }]);
  };
  const removeMessage = (index: number) => {
    if (messages.length > 1) {
      setMessages(messages.filter((_, i) => i !== index));
    }
  };
  const updateMessage = (index: number, field: 'text' | 'auto_send', value: string | boolean) => {
    const updated = [...messages];
    updated[index] = {
      ...updated[index],
      [field]: value
    };
    setMessages(updated);
  };
  async function handleSave() {
    if (!user) return;

    // Validate command starts with /
    if (!command.startsWith('/')) {
      toast({
        title: 'Comando inválido',
        description: 'O comando deve começar com / (ex: /ola)',
        variant: 'destructive'
      });
      return;
    }

    // Filtrar mensagens vazias
    const validMessages = messages.filter(m => m.text.trim());
    if (!command.trim() || validMessages.length === 0) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Preencha o comando e pelo menos uma mensagem',
        variant: 'destructive'
      });
      return;
    }
    setSaving(true);

    // Usar primeira mensagem como fallback para campos legados
    const firstMessage = validMessages[0];
    if (editingShortcut) {
      const {
        error
      } = await supabase.from('text_shortcuts').update({
        command: command.toLowerCase().trim(),
        expanded_text: firstMessage.text,
        category,
        description: description || null,
        auto_send: firstMessage.auto_send,
        messages: validMessages as unknown as import('@/integrations/supabase/types').Json
      }).eq('id', editingShortcut.id);
      if (error) {
        toast({
          title: 'Erro ao atualizar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({
          title: 'Atalho atualizado!'
        });
        setIsDialogOpen(false);
        resetForm();
        formDraft.clearDraft();
        fetchShortcuts();
      }
    } else {
      const {
        error
      } = await supabase.from('text_shortcuts').insert({
        user_id: user.id,
        command: command.toLowerCase().trim(),
        expanded_text: firstMessage.text,
        category,
        description: description || null,
        auto_send: firstMessage.auto_send,
        messages: validMessages as unknown as import('@/integrations/supabase/types').Json
      });
      if (error) {
        if (error.message.includes('duplicate')) {
          toast({
            title: 'Comando já existe',
            description: 'Escolha outro comando',
            variant: 'destructive'
          });
        } else {
          toast({
            title: 'Erro ao criar',
            description: error.message,
            variant: 'destructive'
          });
        }
      } else {
        toast({
          title: 'Atalho criado!'
        });
        setIsDialogOpen(false);
        resetForm();
        formDraft.clearDraft();
        fetchShortcuts();
      }
    }
    setSaving(false);
  }
  async function handleDelete(id: string) {
    const {
      error
    } = await supabase.from('text_shortcuts').delete().eq('id', id);
    if (error) {
      toast({
        title: 'Erro ao excluir',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      toast({
        title: 'Atalho excluído!'
      });
      fetchShortcuts();
    }
  }
  function copyToClipboard(text: string) {
    navigator.clipboard.writeText(text);
    toast({
      title: 'Texto copiado!'
    });
  }
  function exportShortcuts() {
    const data = JSON.stringify(shortcuts, null, 2);
    const blob = new Blob([data], {
      type: 'application/json'
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'atalhos.json';
    a.click();
    URL.revokeObjectURL(url);
    toast({
      title: 'Atalhos exportados!'
    });
  }
  async function importShortcuts(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file || !user) return;
    try {
      const text = await file.text();

      // Detectar formato: TXT customizado, quick_messages (externo) ou array de Shortcut (nosso)
      let shortcutsToImport: Array<{
        command: string;
        expanded_text: string;
        category: string;
        description: string | null;
      }> = [];

      // Verificar se é formato TXT (ATALHO: / MENSAGEM_COMPLETA:)
      if (text.includes('ATALHO:') && text.includes('MENSAGEM_COMPLETA:')) {
        // Formato TXT do usuário - separar por linha de traços
        const blocks = text.split(/^-{10,}$/m).filter(b => b.trim());
        
        for (const block of blocks) {
          // Extrair ATALHO
          const atalhoMatch = block.match(/^ATALHO:\s*(.+)$/m);
          // Extrair TÍTULO  
          const tituloMatch = block.match(/^T[ÍI]TULO:\s*(.+)$/m);
          // Extrair MENSAGEM_COMPLETA (tudo após o marcador até o fim do bloco)
          const mensagemMatch = block.match(/^MENSAGEM_COMPLETA:\s*\n?([\s\S]+)/m);
          
          if (atalhoMatch && mensagemMatch) {
            const command = '/' + atalhoMatch[1].trim().toLowerCase();
            const description = tituloMatch?.[1]?.trim() || null;
            const expanded_text = mensagemMatch[1].trim();
            
            shortcutsToImport.push({
              command,
              expanded_text,
              category: 'geral',
              description
            });
          }
        }
      } else {
        // Tentar parse como JSON
        const parsed = JSON.parse(text);

        if (parsed.quick_messages && Array.isArray(parsed.quick_messages)) {
          // Formato externo com quick_messages
          shortcutsToImport = parsed.quick_messages.map((item: any) => {
            // Converter |||MULTI_TEXT_SEPARATOR||| para <ENTER>
            let expandedText = item.message || '';
            expandedText = expandedText.replace(/\|\|\|MULTI_TEXT_SEPARATOR\|\|\|/g, '<ENTER>');

            // Adicionar / no início se não tiver
            let command = item.shortcut || '';
            if (!command.startsWith('/')) {
              command = '/' + command;
            }
            return {
              command: command.toLowerCase().trim(),
              expanded_text: expandedText,
              category: 'geral',
              description: item.title || null
            };
          });
        } else if (Array.isArray(parsed)) {
          // Nosso formato: array de Shortcut
          shortcutsToImport = parsed.map((s: any) => ({
            command: s.command,
            expanded_text: s.expanded_text,
            category: s.category || 'geral',
            description: s.description || null
          }));
        } else {
          throw new Error('Formato não reconhecido');
        }
      }

      let importedCount = 0;
      for (const s of shortcutsToImport) {
        if (!s.command || !s.expanded_text) continue;
        const {
          error
        } = await supabase.from('text_shortcuts').upsert({
          user_id: user.id,
          command: s.command,
          expanded_text: s.expanded_text,
          category: s.category,
          description: s.description
        }, {
          onConflict: 'user_id,command'
        });
        if (!error) importedCount++;
      }
      toast({
        title: `${importedCount} atalhos importados!`
      });
      fetchShortcuts();
    } catch (err) {
      console.error('Erro ao importar:', err);
      toast({
        title: 'Erro ao importar',
        description: 'Arquivo inválido ou formato não suportado',
        variant: 'destructive'
      });
    }
    event.target.value = '';
  }
  const filteredShortcuts = shortcuts.filter(s => {
    const matchesSearch = s.command.toLowerCase().includes(search.toLowerCase()) || s.expanded_text.toLowerCase().includes(search.toLowerCase());
    const matchesCategory = filterCategory === 'all' || s.category === filterCategory;
    return matchesSearch && matchesCategory;
  });
  return <div className="space-y-6 mx-[10px]">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Atalhos de Texto</h1>
          <p className="text-muted-foreground mt-1">
            Configure comandos /rápidos para expandir textos automaticamente
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={exportShortcuts} title="Exportar">
            <FileDown className="h-4 w-4" />
          </Button>
          <label>
            <Button variant="outline" size="icon" asChild title="Importar">
              <span><FileUp className="h-4 w-4" /></span>
            </Button>
            <input type="file" accept=".json,.txt" className="hidden" onChange={importShortcuts} />
          </label>
          <Dialog open={isDialogOpen} onOpenChange={open => {
          setIsDialogOpen(open);
          if (!open) resetForm();
        }}>
            <DialogTrigger asChild>
              <Button className="gradient-primary">
                <Plus className="mr-2 h-4 w-4" />
                Novo Atalho
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[500px]">
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2">
                  {editingShortcut ? 'Editar Atalho' : 'Novo Atalho de Texto'}
                  {formDraft.hasDraft && !editingShortcut && (
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
                  <Input id="command" placeholder="/ola" value={command} onChange={e => setCommand(e.target.value.toLowerCase())} />
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
                  
                  {messages.map((msg, index) => <div key={index} className="space-y-2 p-3 border rounded-lg bg-muted/30">
                      <div className="flex items-start gap-2">
                        <Textarea placeholder="Digite a mensagem..." value={msg.text} onChange={e => updateMessage(index, 'text', e.target.value)} rows={3} className="flex-1" />
                        {messages.length > 1 && <Button type="button" variant="ghost" size="icon" className="text-destructive hover:text-destructive shrink-0" onClick={() => removeMessage(index)}>
                            <Trash2 className="h-4 w-4" />
                          </Button>}
                      </div>
                      <div className="flex items-center space-x-2">
                        <Checkbox id={`auto_send_${index}`} checked={msg.auto_send} onCheckedChange={checked => updateMessage(index, 'auto_send', checked as boolean)} />
                        <Label htmlFor={`auto_send_${index}`} className="text-sm cursor-pointer">
                          Enviar automaticamente
                        </Label>
                      </div>
                    </div>)}
                  
                  <p className="text-xs text-muted-foreground">
                    Use variáveis: {'<NOME>'}, {'<SAUDACAO>'}, {'<DATA>'}, {'<HORA>'}
                  </p>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="category">Categoria</Label>
                    <Select value={category} onValueChange={setCategory}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {categories.map(cat => <SelectItem key={cat.value} value={cat.value}>
                            {cat.label}
                          </SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="description">Descrição</Label>
                    <Input id="description" placeholder="Opcional" value={description} onChange={e => setDescription(e.target.value)} />
                  </div>
                </div>
                </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
                  Cancelar
                </Button>
                <Button onClick={handleSave} disabled={saving}>
                  {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  {editingShortcut ? 'Salvar' : 'Criar'}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input placeholder="Buscar atalhos..." value={search} onChange={e => setSearch(e.target.value)} className="pl-10" />
        </div>
        <Select value={filterCategory} onValueChange={setFilterCategory}>
          <SelectTrigger className="w-[180px]">
            <SelectValue placeholder="Categoria" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Todas</SelectItem>
            {categories.map(cat => <SelectItem key={cat.value} value={cat.value}>
                {cat.label}
              </SelectItem>)}
          </SelectContent>
        </Select>
      </div>

      {/* Shortcuts Grid */}
      {loading ? <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div> : filteredShortcuts.length === 0 ? <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 rounded-full bg-primary/10 mb-4">
              <Keyboard className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">
              {search || filterCategory !== 'all' ? 'Nenhum atalho encontrado' : 'Nenhum atalho criado'}
            </h3>
            <p className="text-muted-foreground text-center max-w-md">
              {search || filterCategory !== 'all' ? 'Tente ajustar os filtros de busca' : 'Crie seu primeiro atalho de texto para começar'}
            </p>
          </CardContent>
        </Card> : <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {filteredShortcuts.map(shortcut => <Card key={shortcut.id} className="group hover:border-primary/50 transition-colors">
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div>
                    <CardTitle className="text-lg font-mono text-primary">
                      {shortcut.command}
                    </CardTitle>
                    <CardDescription className="mt-1">
                      {shortcut.description || categories.find(c => c.value === shortcut.category)?.label}
                    </CardDescription>
                  </div>
                  <span className="text-xs px-2 py-1 rounded-full bg-secondary text-secondary-foreground">
                    {categories.find(c => c.value === shortcut.category)?.label}
                  </span>
                </div>
              </CardHeader>
              <CardContent>
                <div className="bg-secondary/50 rounded-lg p-3 mb-4 max-h-24 overflow-hidden">
                  <p className="text-sm text-muted-foreground whitespace-pre-wrap line-clamp-3">
                    {shortcut.expanded_text}
                  </p>
                </div>
                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <Button variant="ghost" size="sm" onClick={() => copyToClipboard(shortcut.expanded_text)}>
                    <Copy className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="sm" onClick={() => openEditDialog(shortcut)}>
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={() => handleDelete(shortcut.id)}>
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>)}
        </div>}
    </div>;
}
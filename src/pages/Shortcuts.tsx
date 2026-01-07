import { useState, useEffect, useMemo, useRef } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Plus, Search, Keyboard, Trash2, Pencil, Copy, FileDown, FileUp, Loader2, Tag, Files, MessageSquare, ArrowUpDown, BarChart3, Eye, Undo2, FlaskConical } from 'lucide-react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';

import { parseShortcutsTxt } from '@/lib/shortcutParser';
import { ShortcutEditDialog } from '@/components/shortcuts/ShortcutEditDialog';
import { ShortcutPreviewDialog } from '@/components/shortcuts/ShortcutPreviewDialog';
import { ShortcutTestDialog } from '@/components/shortcuts/ShortcutTestDialog';
import { applyKeywords, applyKeywordsWithHighlight } from '@/lib/shortcuts';
import { HoverCard, HoverCardContent, HoverCardTrigger } from '@/components/ui/hover-card';
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

interface Keyword {
  id: string;
  key: string;
  value: string;
}

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
  use_count?: number;
  created_at?: string;
}

type SortOption = 'use_count' | 'command' | 'message' | 'created_at';
type SortDirection = 'asc' | 'desc';
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
  const [sortBy, setSortBy] = useState<SortOption>('use_count');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingShortcut, setEditingShortcut] = useState<Shortcut | null>(null);
  const [previewShortcut, setPreviewShortcut] = useState<Shortcut | null>(null);
  const [deleteConfirmShortcut, setDeleteConfirmShortcut] = useState<Shortcut | null>(null);
  const undoTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  
  // Keywords state
  const [keywords, setKeywords] = useState<Keyword[]>([]);
  const [newKeyword, setNewKeyword] = useState({ key: '', value: '' });
  const [editingKeyword, setEditingKeyword] = useState<Keyword | null>(null);
  const [savingKeyword, setSavingKeyword] = useState(false);
  
  // Tab state
  const [activeTab, setActiveTab] = useState('atalhos');

  // Carregar dados inicial
  useEffect(() => {
    fetchShortcuts();
    fetchKeywords();
  }, [user]);

  // Subscription em tempo real para text_shortcuts e keywords
  useEffect(() => {
    if (!user) return;

    const shortcutsChannel = supabase
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

    const keywordsChannel = supabase
      .channel('keywords-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'keywords' },
        () => {
          console.log('[Shortcuts] keywords changed, reloading...');
          fetchKeywords();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(shortcutsChannel);
      supabase.removeChannel(keywordsChannel);
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

  async function fetchKeywords() {
    if (!user) return;
    const { data, error } = await supabase
      .from('keywords')
      .select('*')
      .order('key', { ascending: true });
    
    if (error) {
      console.error('Error fetching keywords:', error);
    } else {
      setKeywords(data || []);
    }
  }

  async function handleSaveKeyword() {
    if (!user) return;
    
    const key = newKeyword.key.trim().toUpperCase();
    const value = newKeyword.value.trim();
    
    if (!key || !value) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Preencha o nome e o valor da variável',
        variant: 'destructive'
      });
      return;
    }

    setSavingKeyword(true);

    if (editingKeyword) {
      const { error } = await supabase
        .from('keywords')
        .update({ key, value })
        .eq('id', editingKeyword.id);

      if (error) {
        toast({
          title: 'Erro ao atualizar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({ title: 'Variável atualizada!' });
        setNewKeyword({ key: '', value: '' });
        setEditingKeyword(null);
        fetchKeywords();
      }
    } else {
      const { error } = await supabase
        .from('keywords')
        .insert({ user_id: user.id, key, value });

      if (error) {
        if (error.message.includes('duplicate')) {
          toast({
            title: 'Variável já existe',
            description: 'Escolha outro nome para a variável',
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
        toast({ title: 'Variável criada!' });
        setNewKeyword({ key: '', value: '' });
        fetchKeywords();
      }
    }

    setSavingKeyword(false);
  }

  async function handleDeleteKeyword(id: string) {
    const { error } = await supabase.from('keywords').delete().eq('id', id);
    if (error) {
      toast({
        title: 'Erro ao excluir',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      toast({ title: 'Variável excluída!' });
      fetchKeywords();
    }
  }

  function openEditKeyword(keyword: Keyword) {
    setEditingKeyword(keyword);
    setNewKeyword({ key: keyword.key, value: keyword.value });
  }

  function cancelEditKeyword() {
    setEditingKeyword(null);
    setNewKeyword({ key: '', value: '' });
  }

  function openEditDialog(shortcut: Shortcut) {
    setEditingShortcut(shortcut);
    setIsDialogOpen(true);
  }

  function openNewDialog() {
    setEditingShortcut(null);
    setIsDialogOpen(true);
  }

  function duplicateShortcut(shortcut: Shortcut) {
    // Criar uma cópia do atalho com comando modificado
    const duplicatedShortcut: Shortcut = {
      ...shortcut,
      id: '', // ID vazio para indicar novo atalho
      command: shortcut.command + '_copia',
      description: shortcut.description ? `${shortcut.description} (cópia)` : 'Cópia'
    };
    setEditingShortcut(duplicatedShortcut);
    setIsDialogOpen(true);
  }

  function handleDialogClose(open: boolean) {
    setIsDialogOpen(open);
    if (!open) {
      setEditingShortcut(null);
    }
  }
  async function handleDelete(shortcut: Shortcut) {
    // Armazena o atalho para possível restauração local
    const deletedShortcut = { ...shortcut };
    
    // Remove localmente primeiro (otimista)
    setShortcuts(prev => prev.filter(s => s.id !== shortcut.id));
    
    // Limpa timeout anterior se existir
    if (undoTimeoutRef.current) {
      clearTimeout(undoTimeoutRef.current);
    }

    const { dismiss } = toast({
      title: 'Atalho excluído!',
      description: (
        <div className="flex items-center gap-2">
          <span>"{shortcut.command}" foi removido</span>
          <Button
            variant="outline"
            size="sm"
            className="h-7 gap-1"
            onClick={() => {
              dismiss();
              if (undoTimeoutRef.current) {
                clearTimeout(undoTimeoutRef.current);
                undoTimeoutRef.current = null;
              }
              // Restaura o atalho localmente (ainda não foi excluído do banco)
              setShortcuts(prev => [...prev, deletedShortcut].sort((a, b) => {
                if (sortBy === 'use_count') return sortDirection === 'desc' ? (b.use_count ?? 0) - (a.use_count ?? 0) : (a.use_count ?? 0) - (b.use_count ?? 0);
                if (sortBy === 'command') return sortDirection === 'desc' ? b.command.localeCompare(a.command) : a.command.localeCompare(b.command);
                return 0;
              }));
              toast({ title: 'Atalho restaurado!' });
            }}
          >
            <Undo2 className="h-3 w-3" />
            Desfazer
          </Button>
        </div>
      ),
      duration: 5000,
    });

    // Deleta do banco após 5 segundos
    undoTimeoutRef.current = setTimeout(async () => {
      const { error } = await supabase.from('text_shortcuts').delete().eq('id', shortcut.id);
      if (error) {
        toast({
          title: 'Erro ao excluir',
          description: error.message,
          variant: 'destructive',
        });
        fetchShortcuts(); // Restaura a lista se houver erro
      }
      undoTimeoutRef.current = null;
    }, 5000);
  }
  function copyToClipboard(shortcut: Shortcut) {
    let fullText = '';
    if (shortcut.messages && shortcut.messages.length > 0) {
      fullText = shortcut.messages.map(m => m.text).join('\n\n');
    } else {
      fullText = shortcut.expanded_text;
    }
    const processedText = applyKeywords(fullText, keywords);
    navigator.clipboard.writeText(processedText);
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

      // Verificar se é formato TXT
      const isTxtFormat1 = text.includes('ATALHO:') && text.includes('MENSAGEM_COMPLETA:');
      const isTxtFormat2 = /Atalho:\s*\//.test(text) && /Mensagem:/i.test(text);
      
      if (isTxtFormat1 || isTxtFormat2) {
        // Usar parser dedicado para formato TXT
        const parsedShortcuts = parseShortcutsTxt(text);
        
        shortcutsToImport = parsedShortcuts.map(s => ({
          command: s.command.toLowerCase(),
          expanded_text: s.expanded_text.replace(/\|\|\|MULTI_TEXT_SEPARATOR\|\|\|/g, '<ENTER>'),
          category: s.category || 'geral',
          description: s.description || null
        }));
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
  const filteredShortcuts = shortcuts
    .filter(s => {
      const matchesSearch = s.command.toLowerCase().includes(search.toLowerCase()) || s.expanded_text.toLowerCase().includes(search.toLowerCase());
      const matchesCategory = filterCategory === 'all' || s.category === filterCategory;
      return matchesSearch && matchesCategory;
    })
    .sort((a, b) => {
      const direction = sortDirection === 'asc' ? 1 : -1;
      switch (sortBy) {
        case 'use_count':
          return ((b.use_count || 0) - (a.use_count || 0)) * direction;
        case 'command':
          return a.command.localeCompare(b.command) * direction;
        case 'message':
          return a.expanded_text.localeCompare(b.expanded_text) * direction;
        case 'created_at':
          return ((new Date(b.created_at || 0).getTime()) - (new Date(a.created_at || 0).getTime())) * direction;
        default:
          return 0;
      }
    });

  const sortOptions = [
    { value: 'use_count', label: 'Mais usados' },
    { value: 'command', label: 'Atalho' },
    { value: 'message', label: 'Mensagem' },
    { value: 'created_at', label: 'Data de criação' },
  ];
  const [isTestDialogOpen, setIsTestDialogOpen] = useState(false);

  return <div className="h-full overflow-y-auto space-y-6 pb-6">
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
          <Button variant="outline" onClick={() => setIsTestDialogOpen(true)}>
            <FlaskConical className="mr-2 h-4 w-4" />
            Abrir Simulador
          </Button>
          <Button className="gradient-primary" onClick={openNewDialog}>
            <Plus className="mr-2 h-4 w-4" />
            Novo Atalho
          </Button>
          <ShortcutEditDialog
            open={isDialogOpen}
            onOpenChange={handleDialogClose}
            shortcut={editingShortcut}
            keywords={keywords}
            existingShortcuts={shortcuts.map(s => ({ command: s.command, use_count: s.use_count ?? 0 }))}
          />
          <ShortcutTestDialog
            open={isTestDialogOpen}
            onOpenChange={setIsTestDialogOpen}
            shortcuts={shortcuts}
            keywords={keywords}
          />
        </div>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
        <TabsList className="grid w-full max-w-md grid-cols-2">
          <TabsTrigger value="atalhos" className="gap-2">
            <Keyboard className="h-4 w-4" />
            Atalhos
          </TabsTrigger>
          <TabsTrigger value="variaveis" className="gap-2">
            <Tag className="h-4 w-4" />
            Variáveis
          </TabsTrigger>
        </TabsList>

        {/* Atalhos Tab */}
        <TabsContent value="atalhos" className="space-y-4 mt-4">
          {/* Filters */}
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input placeholder="Buscar atalhos..." value={search} onChange={e => setSearch(e.target.value)} className="pl-10" />
            </div>
            <Select value={filterCategory} onValueChange={setFilterCategory}>
              <SelectTrigger className="w-[150px]">
                <SelectValue placeholder="Categoria" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Todas</SelectItem>
                {categories.map(cat => <SelectItem key={cat.value} value={cat.value}>
                    {cat.label}
                  </SelectItem>)}
              </SelectContent>
            </Select>
            <div className="flex gap-2">
              <Select value={sortBy} onValueChange={(v) => setSortBy(v as SortOption)}>
                <SelectTrigger className="w-[160px]">
                  <ArrowUpDown className="h-4 w-4 mr-2" />
                  <SelectValue placeholder="Ordenar por" />
                </SelectTrigger>
                <SelectContent>
                  {sortOptions.map(opt => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc')}
                title={sortDirection === 'asc' ? 'Crescente' : 'Decrescente'}
              >
                <ArrowUpDown className={`h-4 w-4 transition-transform ${sortDirection === 'asc' ? 'rotate-180' : ''}`} />
              </Button>
            </div>
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
                      <div className="flex items-center gap-2">
                        <CardTitle className="text-lg font-mono text-primary">
                          {shortcut.command}
                        </CardTitle>
                        {shortcut.messages && shortcut.messages.length > 1 && (
                          <Badge variant="secondary" className="gap-1 text-xs">
                            <MessageSquare className="h-3 w-3" />
                            {shortcut.messages.length}
                          </Badge>
                        )}
                      </div>
                      <span className="text-xs px-2 py-1 rounded-full bg-secondary text-secondary-foreground">
                        {categories.find(c => c.value === shortcut.category)?.label}
                      </span>
                    </div>
                    <CardDescription className="mt-1 flex items-center gap-2">
                      <span>{shortcut.description || categories.find(c => c.value === shortcut.category)?.label}</span>
                      {(shortcut.use_count ?? 0) > 0 && (
                        <Badge variant="outline" className="gap-1 text-xs">
                          <BarChart3 className="h-3 w-3" />
                          {shortcut.use_count}x
                        </Badge>
                      )}
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <HoverCard openDelay={300}>
                      <HoverCardTrigger asChild>
                        <div className="bg-secondary/50 rounded-lg p-3 mb-4 max-h-24 overflow-hidden cursor-help">
                          <p className="text-sm text-muted-foreground whitespace-pre-wrap line-clamp-3">
                            {shortcut.expanded_text}
                          </p>
                        </div>
                      </HoverCardTrigger>
                      <HoverCardContent className="w-96 max-h-80 overflow-auto" align="start">
                        <div className="space-y-3">
                          <div className="flex items-center gap-2">
                            <MessageSquare className="h-4 w-4 text-primary" />
                            <span className="font-medium text-sm">
                              {shortcut.messages && shortcut.messages.length > 1 
                                ? `${shortcut.messages.length} mensagens` 
                                : 'Mensagem completa'}
                            </span>
                          </div>
                          {shortcut.messages && shortcut.messages.length > 0 ? (
                            <div className="space-y-2">
                              {shortcut.messages.map((msg, idx) => (
                                <div key={idx} className="bg-secondary/50 rounded-lg p-2">
                                  <div className="flex items-center gap-2 mb-1">
                                    <Badge variant="outline" className="text-xs">
                                      {idx + 1}/{shortcut.messages!.length}
                                    </Badge>
                                    {msg.auto_send && (
                                      <Badge variant="secondary" className="text-xs">
                                        Auto-enviar
                                      </Badge>
                                    )}
                                  </div>
                                  <p className="text-sm whitespace-pre-wrap">
                                    {applyKeywordsWithHighlight(msg.text, keywords).map((part, partIdx) => (
                                      <span 
                                        key={partIdx} 
                                        className={part.isHighlighted ? 'text-primary font-medium' : ''}
                                      >
                                        {part.text}
                                      </span>
                                    ))}
                                  </p>
                                </div>
                              ))}
                            </div>
                          ) : (
                            <div className="bg-secondary/50 rounded-lg p-2">
                              <p className="text-sm whitespace-pre-wrap">
                                {applyKeywordsWithHighlight(shortcut.expanded_text, keywords).map((part, partIdx) => (
                                  <span 
                                    key={partIdx} 
                                    className={part.isHighlighted ? 'text-primary font-medium' : ''}
                                  >
                                    {part.text}
                                  </span>
                                ))}
                              </p>
                            </div>
                          )}
                        </div>
                      </HoverCardContent>
                    </HoverCard>
                    <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <Button variant="ghost" size="sm" onClick={() => setPreviewShortcut(shortcut)} title="Pré-visualizar">
                        <Eye className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => copyToClipboard(shortcut)} title="Copiar">
                        <Copy className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => duplicateShortcut(shortcut)} title="Duplicar">
                        <Files className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => openEditDialog(shortcut)} title="Editar">
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={() => setDeleteConfirmShortcut(shortcut)} title="Excluir">
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>)}
            </div>}
        </TabsContent>

        {/* Variáveis Tab */}
        <TabsContent value="variaveis" className="space-y-4 mt-4">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Tag className="h-5 w-5 text-primary" />
                <div>
                  <CardTitle className="text-lg">Variáveis Personalizadas</CardTitle>
                  <CardDescription>
                    Defina variáveis como {'<PIX>'}, {'<EMAIL>'} para substituir nos atalhos
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              {/* Form para nova variável */}
              <div className="flex flex-col sm:flex-row gap-2 mb-4">
                <Input 
                  placeholder="Nome (ex: PIX)" 
                  value={newKeyword.key} 
                  onChange={e => setNewKeyword(prev => ({ ...prev, key: e.target.value.toUpperCase() }))}
                  className="sm:w-32"
                />
                <Textarea 
                  placeholder="Valor (ex: pix@email.com) - suporta quebra de linha" 
                  value={newKeyword.value} 
                  onChange={e => setNewKeyword(prev => ({ ...prev, value: e.target.value }))}
                  className="flex-1 min-h-[38px] resize-y"
                  rows={1}
                />
                <div className="flex gap-2">
                  {editingKeyword && (
                    <Button variant="outline" onClick={cancelEditKeyword}>
                      Cancelar
                    </Button>
                  )}
                  <Button onClick={handleSaveKeyword} disabled={savingKeyword}>
                    {savingKeyword && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                    {editingKeyword ? 'Salvar' : 'Adicionar'}
                  </Button>
                </div>
              </div>

              {/* Lista de variáveis */}
              {keywords.length > 0 ? (
                <div className="space-y-2 mb-4">
                  {keywords.map(kw => (
                    <div key={kw.id} className="flex items-start gap-2 p-2 bg-muted/50 rounded-lg">
                      <span className="font-mono text-primary font-medium shrink-0 pt-0.5">&lt;{kw.key}&gt;</span>
                      <span className="text-muted-foreground shrink-0 pt-0.5">=</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm whitespace-pre-wrap break-words">{kw.value}</p>
                      </div>
                      <Button 
                        variant="ghost" 
                        size="icon" 
                        className="h-8 w-8 shrink-0"
                        onClick={() => openEditKeyword(kw)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button 
                        variant="ghost" 
                        size="icon" 
                        className="h-8 w-8 shrink-0 text-destructive hover:text-destructive"
                        onClick={() => handleDeleteKeyword(kw.id)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center py-8 text-center">
                  <div className="p-4 rounded-full bg-primary/10 mb-4">
                    <Tag className="h-8 w-8 text-primary" />
                  </div>
                  <h3 className="text-lg font-semibold mb-2">Nenhuma variável criada</h3>
                  <p className="text-muted-foreground max-w-md">
                    Crie variáveis personalizadas para substituir automaticamente nos seus atalhos
                  </p>
                </div>
              )}

              {/* Variáveis automáticas */}
              <div className="pt-4 border-t text-sm text-muted-foreground">
                <p className="font-medium mb-2">Variáveis automáticas:</p>
                <div className="grid sm:grid-cols-3 gap-1">
                  <p><span className="font-mono text-primary">&lt;SAUDACAO&gt;</span> - Bom dia / Boa tarde / Boa noite</p>
                  <p><span className="font-mono text-primary">&lt;DATA&gt;</span> - Data atual</p>
                  <p><span className="font-mono text-primary">&lt;HORA&gt;</span> - Hora atual</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
      
      {/* Preview Dialog */}
      <ShortcutPreviewDialog
        open={!!previewShortcut}
        onOpenChange={(open) => !open && setPreviewShortcut(null)}
        messages={previewShortcut?.messages && previewShortcut.messages.length > 0 
          ? previewShortcut.messages 
          : previewShortcut 
            ? [{ text: previewShortcut.expanded_text, auto_send: previewShortcut.auto_send }]
            : []
        }
        keywords={keywords}
        title={previewShortcut?.command}
      />

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={!!deleteConfirmShortcut} onOpenChange={(open) => !open && setDeleteConfirmShortcut(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir atalho?</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir o atalho "{deleteConfirmShortcut?.command}"? 
              Você terá alguns segundos para desfazer após a exclusão.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (deleteConfirmShortcut) {
                  handleDelete(deleteConfirmShortcut);
                  setDeleteConfirmShortcut(null);
                }
              }}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>;
}
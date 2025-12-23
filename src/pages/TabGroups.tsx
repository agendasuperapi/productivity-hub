import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { 
  Plus, 
  FolderOpen, 
  Trash2, 
  Pencil, 
  Globe,
  ExternalLink,
  GripVertical,
  Loader2,
  ChevronDown,
  ChevronRight
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface Tab {
  id: string;
  name: string;
  url: string;
  icon: string;
  color: string;
  zoom: number;
  position: number;
  open_as_window: boolean;
  keyboard_shortcut: string | null;
}

interface TabGroup {
  id: string;
  name: string;
  icon: string;
  color: string;
  position: number;
  tabs: Tab[];
}

const iconOptions = [
  { value: 'folder', label: 'Pasta' },
  { value: 'globe', label: 'Web' },
  { value: 'message-circle', label: 'WhatsApp' },
  { value: 'mail', label: 'Email' },
  { value: 'file-text', label: 'Documentos' },
  { value: 'calendar', label: 'Calendário' },
  { value: 'shopping-cart', label: 'Vendas' },
  { value: 'headphones', label: 'Suporte' },
  { value: 'dollar-sign', label: 'Financeiro' },
  { value: 'users', label: 'Equipe' },
];

const colorOptions = [
  { value: '#6366f1', label: 'Índigo' },
  { value: '#22d3ee', label: 'Ciano' },
  { value: '#10b981', label: 'Verde' },
  { value: '#f59e0b', label: 'Laranja' },
  { value: '#ef4444', label: 'Vermelho' },
  { value: '#8b5cf6', label: 'Roxo' },
  { value: '#ec4899', label: 'Rosa' },
  { value: '#64748b', label: 'Cinza' },
];

export default function TabGroups() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());

  // Group dialog
  const [isGroupDialogOpen, setIsGroupDialogOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<TabGroup | null>(null);
  const [groupName, setGroupName] = useState('');
  const [groupIcon, setGroupIcon] = useState('folder');
  const [groupColor, setGroupColor] = useState('#6366f1');
  const [savingGroup, setSavingGroup] = useState(false);

  // Tab dialog
  const [isTabDialogOpen, setIsTabDialogOpen] = useState(false);
  const [editingTab, setEditingTab] = useState<Tab | null>(null);
  const [selectedGroupId, setSelectedGroupId] = useState<string | null>(null);
  const [tabName, setTabName] = useState('');
  const [tabUrl, setTabUrl] = useState('');
  const [tabIcon, setTabIcon] = useState('globe');
  const [tabColor, setTabColor] = useState('#22d3ee');
  const [tabZoom, setTabZoom] = useState(100);
  const [tabOpenAsWindow, setTabOpenAsWindow] = useState(false);
  const [tabShortcut, setTabShortcut] = useState('');
  const [savingTab, setSavingTab] = useState(false);

  useEffect(() => {
    fetchGroups();
  }, [user]);

  async function fetchGroups() {
    if (!user) return;

    const { data: groupsData, error: groupsError } = await supabase
      .from('tab_groups')
      .select('*')
      .order('position', { ascending: true });

    if (groupsError) {
      toast({
        title: 'Erro ao carregar grupos',
        description: groupsError.message,
        variant: 'destructive'
      });
      setLoading(false);
      return;
    }

    const { data: tabsData, error: tabsError } = await supabase
      .from('tabs')
      .select('*')
      .order('position', { ascending: true });

    if (tabsError) {
      toast({
        title: 'Erro ao carregar abas',
        description: tabsError.message,
        variant: 'destructive'
      });
    }

    const groupsWithTabs: TabGroup[] = (groupsData || []).map(group => ({
      ...group,
      tabs: (tabsData || []).filter(tab => tab.group_id === group.id)
    }));

    setGroups(groupsWithTabs);
    
    // Auto-expand all groups on first load
    if (groupsWithTabs.length > 0 && expandedGroups.size === 0) {
      setExpandedGroups(new Set(groupsWithTabs.map(g => g.id)));
    }
    
    setLoading(false);
  }

  function toggleGroup(groupId: string) {
    setExpandedGroups(prev => {
      const next = new Set(prev);
      if (next.has(groupId)) {
        next.delete(groupId);
      } else {
        next.add(groupId);
      }
      return next;
    });
  }

  function resetGroupForm() {
    setGroupName('');
    setGroupIcon('folder');
    setGroupColor('#6366f1');
    setEditingGroup(null);
  }

  function resetTabForm() {
    setTabName('');
    setTabUrl('');
    setTabIcon('globe');
    setTabColor('#22d3ee');
    setTabZoom(100);
    setTabOpenAsWindow(false);
    setTabShortcut('');
    setEditingTab(null);
    setSelectedGroupId(null);
  }

  function openEditGroupDialog(group: TabGroup) {
    setEditingGroup(group);
    setGroupName(group.name);
    setGroupIcon(group.icon);
    setGroupColor(group.color);
    setIsGroupDialogOpen(true);
  }

  function openAddTabDialog(groupId: string) {
    setSelectedGroupId(groupId);
    resetTabForm();
    setSelectedGroupId(groupId);
    setIsTabDialogOpen(true);
  }

  function openEditTabDialog(tab: Tab, groupId: string) {
    setEditingTab(tab);
    setSelectedGroupId(groupId);
    setTabName(tab.name);
    setTabUrl(tab.url);
    setTabIcon(tab.icon);
    setTabColor(tab.color);
    setTabZoom(tab.zoom);
    setTabOpenAsWindow(tab.open_as_window);
    setTabShortcut(tab.keyboard_shortcut || '');
    setIsTabDialogOpen(true);
  }

  async function handleSaveGroup() {
    if (!user || !groupName.trim()) {
      toast({
        title: 'Nome obrigatório',
        description: 'Informe o nome do grupo',
        variant: 'destructive'
      });
      return;
    }

    setSavingGroup(true);

    if (editingGroup) {
      const { error } = await supabase
        .from('tab_groups')
        .update({
          name: groupName.trim(),
          icon: groupIcon,
          color: groupColor
        })
        .eq('id', editingGroup.id);

      if (error) {
        toast({ title: 'Erro ao atualizar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Grupo atualizado!' });
        setIsGroupDialogOpen(false);
        resetGroupForm();
        fetchGroups();
      }
    } else {
      const position = groups.length;
      const { error } = await supabase
        .from('tab_groups')
        .insert({
          user_id: user.id,
          name: groupName.trim(),
          icon: groupIcon,
          color: groupColor,
          position
        });

      if (error) {
        toast({ title: 'Erro ao criar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Grupo criado!' });
        setIsGroupDialogOpen(false);
        resetGroupForm();
        fetchGroups();
      }
    }
    setSavingGroup(false);
  }

  async function handleDeleteGroup(groupId: string) {
    const { error } = await supabase
      .from('tab_groups')
      .delete()
      .eq('id', groupId);

    if (error) {
      toast({ title: 'Erro ao excluir', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Grupo excluído!' });
      fetchGroups();
    }
  }

  async function handleSaveTab() {
    if (!user || !selectedGroupId || !tabName.trim() || !tabUrl.trim()) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Informe nome e URL da aba',
        variant: 'destructive'
      });
      return;
    }

    setSavingTab(true);

    if (editingTab) {
      const { error } = await supabase
        .from('tabs')
        .update({
          name: tabName.trim(),
          url: tabUrl.trim(),
          icon: tabIcon,
          color: tabColor,
          zoom: tabZoom,
          open_as_window: tabOpenAsWindow,
          keyboard_shortcut: tabShortcut || null
        })
        .eq('id', editingTab.id);

      if (error) {
        toast({ title: 'Erro ao atualizar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Aba atualizada!' });
        setIsTabDialogOpen(false);
        resetTabForm();
        fetchGroups();
      }
    } else {
      const group = groups.find(g => g.id === selectedGroupId);
      const position = group?.tabs.length || 0;

      const { error } = await supabase
        .from('tabs')
        .insert({
          user_id: user.id,
          group_id: selectedGroupId,
          name: tabName.trim(),
          url: tabUrl.trim(),
          icon: tabIcon,
          color: tabColor,
          zoom: tabZoom,
          open_as_window: tabOpenAsWindow,
          keyboard_shortcut: tabShortcut || null,
          position
        });

      if (error) {
        toast({ title: 'Erro ao criar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Aba criada!' });
        setIsTabDialogOpen(false);
        resetTabForm();
        fetchGroups();
      }
    }
    setSavingTab(false);
  }

  async function handleDeleteTab(tabId: string) {
    const { error } = await supabase
      .from('tabs')
      .delete()
      .eq('id', tabId);

    if (error) {
      toast({ title: 'Erro ao excluir', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Aba excluída!' });
      fetchGroups();
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Grupos de Abas</h1>
          <p className="text-muted-foreground mt-1">
            Organize suas páginas em grupos para abrir no navegador
          </p>
        </div>
        <Dialog open={isGroupDialogOpen} onOpenChange={(open) => {
          setIsGroupDialogOpen(open);
          if (!open) resetGroupForm();
        }}>
          <DialogTrigger asChild>
            <Button className="gradient-primary">
              <Plus className="mr-2 h-4 w-4" />
              Novo Grupo
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>{editingGroup ? 'Editar Grupo' : 'Novo Grupo de Abas'}</DialogTitle>
              <DialogDescription>
                Crie um grupo para organizar suas páginas
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="group-name">Nome do Grupo *</Label>
                <Input
                  id="group-name"
                  placeholder="Ex: Atendimento"
                  value={groupName}
                  onChange={(e) => setGroupName(e.target.value)}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Ícone</Label>
                  <Select value={groupIcon} onValueChange={setGroupIcon}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {iconOptions.map(icon => (
                        <SelectItem key={icon.value} value={icon.value}>
                          {icon.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Cor</Label>
                  <Select value={groupColor} onValueChange={setGroupColor}>
                    <SelectTrigger>
                      <div className="flex items-center gap-2">
                        <div 
                          className="w-4 h-4 rounded-full" 
                          style={{ backgroundColor: groupColor }}
                        />
                        <SelectValue />
                      </div>
                    </SelectTrigger>
                    <SelectContent>
                      {colorOptions.map(color => (
                        <SelectItem key={color.value} value={color.value}>
                          <div className="flex items-center gap-2">
                            <div 
                              className="w-4 h-4 rounded-full" 
                              style={{ backgroundColor: color.value }}
                            />
                            {color.label}
                          </div>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsGroupDialogOpen(false)}>
                Cancelar
              </Button>
              <Button onClick={handleSaveGroup} disabled={savingGroup}>
                {savingGroup && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {editingGroup ? 'Salvar' : 'Criar'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Tab Dialog */}
      <Dialog open={isTabDialogOpen} onOpenChange={(open) => {
        setIsTabDialogOpen(open);
        if (!open) resetTabForm();
      }}>
        <DialogContent className="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>{editingTab ? 'Editar Aba' : 'Nova Aba'}</DialogTitle>
            <DialogDescription>
              Configure os detalhes da página
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="tab-name">Nome *</Label>
              <Input
                id="tab-name"
                placeholder="Ex: WhatsApp Paulo"
                value={tabName}
                onChange={(e) => setTabName(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="tab-url">URL *</Label>
              <Input
                id="tab-url"
                placeholder="https://web.whatsapp.com"
                value={tabUrl}
                onChange={(e) => setTabUrl(e.target.value)}
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>Ícone</Label>
                <Select value={tabIcon} onValueChange={setTabIcon}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {iconOptions.map(icon => (
                      <SelectItem key={icon.value} value={icon.value}>
                        {icon.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Cor</Label>
                <Select value={tabColor} onValueChange={setTabColor}>
                  <SelectTrigger>
                    <div className="flex items-center gap-2">
                      <div 
                        className="w-4 h-4 rounded-full" 
                        style={{ backgroundColor: tabColor }}
                      />
                      <SelectValue />
                    </div>
                  </SelectTrigger>
                  <SelectContent>
                    {colorOptions.map(color => (
                      <SelectItem key={color.value} value={color.value}>
                        <div className="flex items-center gap-2">
                          <div 
                            className="w-4 h-4 rounded-full" 
                            style={{ backgroundColor: color.value }}
                          />
                          {color.label}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="tab-zoom">Zoom (%)</Label>
                <Input
                  id="tab-zoom"
                  type="number"
                  min={50}
                  max={200}
                  value={tabZoom}
                  onChange={(e) => setTabZoom(Number(e.target.value))}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="tab-shortcut">Atalho de Teclado</Label>
                <Input
                  id="tab-shortcut"
                  placeholder="Ctrl+1"
                  value={tabShortcut}
                  onChange={(e) => setTabShortcut(e.target.value)}
                />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="open-window">Abrir como janela</Label>
                <p className="text-xs text-muted-foreground">
                  Abre em janela separada sem abas
                </p>
              </div>
              <Switch
                id="open-window"
                checked={tabOpenAsWindow}
                onCheckedChange={setTabOpenAsWindow}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsTabDialogOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleSaveTab} disabled={savingTab}>
              {savingTab && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {editingTab ? 'Salvar' : 'Criar'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Groups List */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : groups.length === 0 ? (
        <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 rounded-full bg-primary/10 mb-4">
              <FolderOpen className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Nenhum grupo criado</h3>
            <p className="text-muted-foreground text-center max-w-md">
              Crie seu primeiro grupo de abas para organizar suas páginas
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {groups.map((group) => (
            <Card key={group.id} className="overflow-hidden">
              {/* Group Header */}
              <div
                className="flex items-center gap-3 p-4 cursor-pointer hover:bg-secondary/50 transition-colors"
                onClick={() => toggleGroup(group.id)}
              >
                <div 
                  className="p-2 rounded-lg"
                  style={{ backgroundColor: `${group.color}20` }}
                >
                  <FolderOpen 
                    className="h-5 w-5" 
                    style={{ color: group.color }}
                  />
                </div>
                <div className="flex-1">
                  <h3 className="font-semibold">{group.name}</h3>
                  <p className="text-sm text-muted-foreground">
                    {group.tabs.length} {group.tabs.length === 1 ? 'aba' : 'abas'}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={(e) => {
                      e.stopPropagation();
                      openAddTabDialog(group.id);
                    }}
                  >
                    <Plus className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={(e) => {
                      e.stopPropagation();
                      openEditGroupDialog(group);
                    }}
                  >
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="text-destructive hover:text-destructive"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeleteGroup(group.id);
                    }}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                  {expandedGroups.has(group.id) ? (
                    <ChevronDown className="h-4 w-4 text-muted-foreground" />
                  ) : (
                    <ChevronRight className="h-4 w-4 text-muted-foreground" />
                  )}
                </div>
              </div>

              {/* Tabs List */}
              {expandedGroups.has(group.id) && (
                <div className="border-t border-border">
                  {group.tabs.length === 0 ? (
                    <div className="p-6 text-center text-muted-foreground">
                      <Globe className="h-8 w-8 mx-auto mb-2 opacity-50" />
                      <p>Nenhuma aba neste grupo</p>
                      <Button 
                        variant="link" 
                        onClick={() => openAddTabDialog(group.id)}
                      >
                        <Plus className="mr-1 h-3 w-3" />
                        Adicionar aba
                      </Button>
                    </div>
                  ) : (
                    <div className="divide-y divide-border">
                      {group.tabs.map((tab) => (
                        <div
                          key={tab.id}
                          className="flex items-center gap-3 p-3 pl-6 hover:bg-secondary/30 transition-colors group"
                        >
                          <GripVertical className="h-4 w-4 text-muted-foreground/50" />
                          <div 
                            className="w-8 h-8 rounded-lg flex items-center justify-center"
                            style={{ backgroundColor: `${tab.color}20` }}
                          >
                            <Globe 
                              className="h-4 w-4" 
                              style={{ color: tab.color }}
                            />
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="font-medium truncate">{tab.name}</p>
                            <p className="text-xs text-muted-foreground truncate">
                              {tab.url}
                            </p>
                          </div>
                          {tab.keyboard_shortcut && (
                            <span className="text-xs px-2 py-1 rounded bg-secondary text-muted-foreground">
                              {tab.keyboard_shortcut}
                            </span>
                          )}
                          {tab.zoom !== 100 && (
                            <span className="text-xs text-muted-foreground">
                              {tab.zoom}%
                            </span>
                          )}
                          {tab.open_as_window && (
                            <ExternalLink className="h-3 w-3 text-muted-foreground" />
                          )}
                          <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8"
                              onClick={() => openEditTabDialog(tab, group.id)}
                            >
                              <Pencil className="h-3 w-3" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 text-destructive hover:text-destructive"
                              onClick={() => handleDeleteTab(tab.id)}
                            >
                              <Trash2 className="h-3 w-3" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

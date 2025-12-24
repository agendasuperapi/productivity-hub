import { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
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
  Loader2,
  ChevronDown,
  ChevronRight,
} from 'lucide-react';
import { TabUrlsEditor, TabUrl } from '@/components/tabs/TabUrlsEditor';
import { LayoutSelector, LayoutType } from '@/components/tabs/LayoutSelector';
import { SortableTab } from '@/components/tabs/SortableTab';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';

interface Tab {
  id: string;
  name: string;
  url: string;
  urls: TabUrl[];
  layout_type: string;
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
  const [tabUrls, setTabUrls] = useState<TabUrl[]>([]);
  const [tabLayoutType, setTabLayoutType] = useState<LayoutType>('single');
  const [tabIcon, setTabIcon] = useState('globe');
  const [tabColor, setTabColor] = useState('#22d3ee');
  const [tabZoom, setTabZoom] = useState(100);
  const [tabMainShortcutEnabled, setTabMainShortcutEnabled] = useState(true);
  const [tabMainZoom, setTabMainZoom] = useState(100);
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
      tabs: (tabsData || []).filter(tab => tab.group_id === group.id).map(tab => {
        // Parse urls from JSON
        let parsedUrls: TabUrl[] = [];
        if (tab.urls && Array.isArray(tab.urls)) {
          parsedUrls = (tab.urls as unknown as TabUrl[]).filter(
            u => u && typeof u === 'object' && 'url' in u
          );
        }
        return {
          ...tab,
          urls: parsedUrls,
          layout_type: tab.layout_type || 'single',
          keyboard_shortcut: tab.keyboard_shortcut || null
        };
      })
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
    setTabUrls([]);
    setTabLayoutType('single');
    setTabIcon('globe');
    setTabColor('#22d3ee');
    setTabZoom(100);
    setTabMainShortcutEnabled(true);
    setTabMainZoom(100);
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
    resetTabForm();
    setSelectedGroupId(groupId);
    setIsTabDialogOpen(true);
  }

  function openEditTabDialog(tab: Tab, groupId: string) {
    setEditingTab(tab);
    setSelectedGroupId(groupId);
    setTabName(tab.name);
    setTabUrl(tab.url);
    setTabUrls(tab.urls || []);
    setTabLayoutType((tab.layout_type as LayoutType) || 'single');
    setTabIcon(tab.icon);
    setTabColor(tab.color);
    setTabZoom(tab.zoom);
    // Parse main URL shortcut and zoom from urls array if available
    const mainUrlData = tab.urls?.[0];
    setTabMainShortcutEnabled(mainUrlData?.shortcut_enabled ?? true);
    setTabMainZoom(mainUrlData?.zoom ?? tab.zoom ?? 100);
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

    // Construir array de URLs (principal + extras) com zoom individual
    const allUrls: TabUrl[] = [
      { url: tabUrl.trim(), shortcut_enabled: tabMainShortcutEnabled, zoom: tabMainZoom },
      ...tabUrls.filter(u => u.url.trim()).map(u => ({ ...u, zoom: u.zoom ?? 100 }))
    ];

    // Determinar layout baseado na quantidade de URLs
    const effectiveLayout = allUrls.length > 1 ? tabLayoutType : 'single';

    if (editingTab) {
      const { error } = await supabase
        .from('tabs')
        .update({
          name: tabName.trim(),
          url: tabUrl.trim(),
          urls: allUrls as unknown as any,
          layout_type: effectiveLayout,
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
        .insert([{
          user_id: user.id,
          group_id: selectedGroupId,
          name: tabName.trim(),
          url: tabUrl.trim(),
          urls: allUrls as unknown as any,
          layout_type: effectiveLayout,
          icon: tabIcon,
          color: tabColor,
          zoom: tabZoom,
          open_as_window: tabOpenAsWindow,
          keyboard_shortcut: tabShortcut || null,
          position
        }]);

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

  // DnD sensors
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  // Handle tab reorder
  async function handleDragEnd(event: DragEndEvent, groupId: string) {
    const { active, over } = event;
    
    if (!over || active.id === over.id) return;

    const group = groups.find(g => g.id === groupId);
    if (!group) return;

    const oldIndex = group.tabs.findIndex(t => t.id === active.id);
    const newIndex = group.tabs.findIndex(t => t.id === over.id);

    if (oldIndex === -1 || newIndex === -1) return;

    // Update local state optimistically
    const newTabs = arrayMove(group.tabs, oldIndex, newIndex);
    setGroups(prev => prev.map(g => 
      g.id === groupId ? { ...g, tabs: newTabs } : g
    ));

    // Update positions in database
    const updates = newTabs.map((tab, index) => 
      supabase
        .from('tabs')
        .update({ position: index })
        .eq('id', tab.id)
    );

    const results = await Promise.all(updates);
    const hasError = results.some(r => r.error);

    if (hasError) {
      toast({ 
        title: 'Erro ao reordenar', 
        description: 'Algumas abas não foram reordenadas', 
        variant: 'destructive' 
      });
      fetchGroups(); // Revert on error
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
        <DialogContent className="sm:max-w-[550px] max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{editingTab ? 'Editar Aba' : 'Nova Aba'}</DialogTitle>
            <DialogDescription>
              Configure os detalhes da página
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Nome e ícone/cor em linha */}
            <div className="flex gap-3">
              <div className="flex-1 space-y-2">
                <Label htmlFor="tab-name">Nome *</Label>
                <Input
                  id="tab-name"
                  placeholder="Ex: Plim"
                  value={tabName}
                  onChange={(e) => setTabName(e.target.value)}
                />
              </div>
              <div className="flex items-end gap-2">
                <Select value={tabIcon} onValueChange={setTabIcon}>
                  <SelectTrigger className="w-14 h-10">
                    <Globe className="h-4 w-4" style={{ color: tabColor }} />
                  </SelectTrigger>
                  <SelectContent>
                    {iconOptions.map(icon => (
                      <SelectItem key={icon.value} value={icon.value}>
                        {icon.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Select value={tabColor} onValueChange={setTabColor}>
                  <SelectTrigger className="w-14 h-10">
                    <div 
                      className="w-6 h-6 rounded-full" 
                      style={{ backgroundColor: tabColor }}
                    />
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

            {/* Atalho de teclado */}
            <div className="space-y-2">
              <Label htmlFor="tab-shortcut">Atalho de Teclado (Opcional)</Label>
              <Input
                id="tab-shortcut"
                placeholder="Atalho para abrir esta aba/janela rapidamente"
                value={tabShortcut}
                onChange={(e) => setTabShortcut(e.target.value)}
              />
            </div>

            {/* Grupo */}
            <div className="space-y-2">
              <Label>Grupo</Label>
              <Select value={selectedGroupId || ''} onValueChange={setSelectedGroupId}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione um grupo" />
                </SelectTrigger>
                <SelectContent>
                  {groups.map(group => (
                    <SelectItem key={group.id} value={group.id}>
                      <div className="flex items-center gap-2">
                        <FolderOpen className="h-4 w-4" style={{ color: group.color }} />
                        {group.name}
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* URLs */}
            <TabUrlsEditor
              urls={tabUrls}
              onChange={setTabUrls}
              mainUrl={tabUrl}
              onMainUrlChange={setTabUrl}
              mainShortcutEnabled={tabMainShortcutEnabled}
              onMainShortcutEnabledChange={setTabMainShortcutEnabled}
              mainZoom={tabMainZoom}
              onMainZoomChange={setTabMainZoom}
            />

            {/* Layout Selector (só mostra se tiver mais de 1 URL) */}
            {tabUrls.length > 0 && (
              <LayoutSelector
                value={tabLayoutType}
                onChange={setTabLayoutType}
                urlCount={1 + tabUrls.filter(u => u.url.trim()).length}
              />
            )}

            {/* Abrir como janela */}
            <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
              <div>
                <Label htmlFor="open-window">Abrir como janela</Label>
                <p className="text-xs text-muted-foreground">
                  Se marcado, esta aba será aberta em uma nova janela do navegador ao invés de carregar nas abas
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
                    <DndContext
                      sensors={sensors}
                      collisionDetection={closestCenter}
                      onDragEnd={(event) => handleDragEnd(event, group.id)}
                    >
                      <SortableContext
                        items={group.tabs.map(t => t.id)}
                        strategy={verticalListSortingStrategy}
                      >
                        <div className="divide-y divide-border">
                          {group.tabs.map((tab) => (
                            <SortableTab
                              key={tab.id}
                              tab={tab}
                              groupId={group.id}
                              onEdit={openEditTabDialog}
                              onDelete={handleDeleteTab}
                            />
                          ))}
                        </div>
                      </SortableContext>
                    </DndContext>
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

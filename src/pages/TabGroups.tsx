import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '@/components/ui/alert-dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Plus, FolderOpen, Trash2, Pencil, Globe, Loader2, ChevronDown, ChevronRight, FileDown, FileUp, Save, Link } from 'lucide-react';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { TabUrlsEditor, TabUrl } from '@/components/tabs/TabUrlsEditor';
import { LayoutSelector, LayoutType } from '@/components/tabs/LayoutSelector';
import { SortableTab } from '@/components/tabs/SortableTab';
import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, DragEndEvent } from '@dnd-kit/core';
import { arrayMove, SortableContext, sortableKeyboardCoordinates, verticalListSortingStrategy } from '@dnd-kit/sortable';
import { useFormDraft } from '@/hooks/useFormDraft';
import { parseTabGroupsTxt, getLayoutForUrlCount } from '@/lib/tabGroupParser';
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
  alternative_domains: string[];
  show_link_transform_panel: boolean;
  capture_token: boolean;
  capture_token_header: string;
  webhook_url: string | null;
}
interface TabGroup {
  id: string;
  name: string;
  icon: string;
  color: string;
  position: number;
  tabs: Tab[];
}

interface GroupFormValues {
  name: string;
  icon: string;
  color: string;
}

interface TabFormValues {
  name: string;
  url: string;
  urls: TabUrl[];
  layoutType: LayoutType;
  icon: string;
  color: string;
  zoom: number;
  mainShortcutEnabled: boolean;
  mainZoom: number;
  openAsWindow: boolean;
  shortcut: string;
  groupId: string | null;
  alternativeDomains: string[];
  showLinkTransformPanel: boolean;
  captureToken: boolean;
  captureTokenHeader: string;
  webhookUrl: string;
}

import { colorOptions } from '@/lib/iconOptions';
import { IconSelect } from '@/components/ui/icon-select';

const defaultGroupValues = {
  name: '' as string,
  icon: 'folder' as string,
  color: '#6366f1' as string,
};

const defaultTabValues = {
  name: '' as string,
  url: '' as string,
  urls: [] as TabUrl[],
  layoutType: 'single' as LayoutType,
  icon: 'globe' as string,
  color: '#22d3ee' as string,
  zoom: 100 as number,
  mainShortcutEnabled: true as boolean,
  mainZoom: 100 as number,
  mainSessionGroup: '' as string,
  openAsWindow: false as boolean,
  shortcut: '' as string,
  groupId: null as string | null,
  alternativeDomains: [] as string[],
  showLinkTransformPanel: true as boolean,
  captureToken: false as boolean,
  captureTokenHeader: 'X-Access-Token' as string,
  webhookUrl: '' as string,
};

export default function TabGroups() {
  const {
    user
  } = useAuth();
  const {
    toast
  } = useToast();
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());
  const [deleteGroupConfirm, setDeleteGroupConfirm] = useState<TabGroup | null>(null);

  // Group dialog
  const [isGroupDialogOpen, setIsGroupDialogOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<TabGroup | null>(null);
  const [savingGroup, setSavingGroup] = useState(false);

  // Group form with auto-save
  const groupDraft = useFormDraft('tabgroups-group-form', defaultGroupValues);
  // Derived values for group form
  const groupName = groupDraft.values.name;
  const groupIcon = groupDraft.values.icon;
  const groupColor = groupDraft.values.color;
  const setGroupName = (v: string) => groupDraft.updateValue('name', v);
  const setGroupIcon = (v: string) => groupDraft.updateValue('icon', v);
  const setGroupColor = (v: string) => groupDraft.updateValue('color', v);

  // Tab dialog
  const [isTabDialogOpen, setIsTabDialogOpen] = useState(false);
  const [editingTab, setEditingTab] = useState<Tab | null>(null);
  const [savingTab, setSavingTab] = useState(false);

  // Tab form with auto-save
  const tabDraft = useFormDraft('tabgroups-tab-form', defaultTabValues);
  // Derived values for tab form
  const tabName = tabDraft.values.name as string;
  const tabUrl = tabDraft.values.url as string;
  const tabUrls = tabDraft.values.urls as TabUrl[];
  const tabLayoutType = tabDraft.values.layoutType as LayoutType;
  const tabIcon = tabDraft.values.icon as string;
  const tabColor = tabDraft.values.color as string;
  const tabZoom = tabDraft.values.zoom as number;
  const tabMainShortcutEnabled = tabDraft.values.mainShortcutEnabled as boolean;
  const tabMainZoom = tabDraft.values.mainZoom as number;
  const tabMainSessionGroup = tabDraft.values.mainSessionGroup as string;
  const tabOpenAsWindow = tabDraft.values.openAsWindow as boolean;
  const tabShortcut = tabDraft.values.shortcut as string;
  const selectedGroupId = tabDraft.values.groupId as string | null;
  const tabAlternativeDomains = tabDraft.values.alternativeDomains as string[];
  const tabShowLinkTransformPanel = tabDraft.values.showLinkTransformPanel as boolean;
  const tabCaptureToken = tabDraft.values.captureToken as boolean;
  const tabCaptureTokenHeader = tabDraft.values.captureTokenHeader as string;
  const tabWebhookUrl = tabDraft.values.webhookUrl as string;
  const setTabName = (v: string) => tabDraft.updateValue('name', v);
  const setTabUrl = (v: string) => tabDraft.updateValue('url', v);
  const setTabUrls = (v: TabUrl[]) => tabDraft.updateValue('urls', v);
  const setTabLayoutType = (v: LayoutType) => tabDraft.updateValue('layoutType', v);
  const setTabIcon = (v: string) => tabDraft.updateValue('icon', v);
  const setTabColor = (v: string) => tabDraft.updateValue('color', v);
  const setTabMainShortcutEnabled = (v: boolean) => tabDraft.updateValue('mainShortcutEnabled', v);
  const setTabMainZoom = (v: number) => tabDraft.updateValue('mainZoom', v);
  const setTabMainSessionGroup = (v: string) => tabDraft.updateValue('mainSessionGroup', v);
  const setTabOpenAsWindow = (v: boolean) => tabDraft.updateValue('openAsWindow', v);
  const setTabShortcut = (v: string) => tabDraft.updateValue('shortcut', v);
  const setSelectedGroupId = (v: string | null) => tabDraft.updateValue('groupId', v);
  const setTabAlternativeDomains = (v: string[]) => tabDraft.updateValue('alternativeDomains', v);
  const setTabShowLinkTransformPanel = (v: boolean) => tabDraft.updateValue('showLinkTransformPanel', v);
  const setTabCaptureToken = (v: boolean) => tabDraft.updateValue('captureToken', v);
  const setTabCaptureTokenHeader = (v: string) => tabDraft.updateValue('captureTokenHeader', v);
  const setTabWebhookUrl = (v: string) => tabDraft.updateValue('webhookUrl', v);
  
  // Coletar grupos de sessão existentes de todas as URLs
  const existingSessionGroups = [...new Set(
    groups.flatMap(g => g.tabs.flatMap(t => 
      (t.urls || []).map((u: any) => u.session_group).filter((s: any) => s)
    ))
  )];
  useEffect(() => {
    fetchGroups();
  }, [user]);
  async function fetchGroups() {
    if (!user) return;
    const {
      data: groupsData,
      error: groupsError
    } = await supabase.from('tab_groups').select('*').order('position', {
      ascending: true
    });
    if (groupsError) {
      toast({
        title: 'Erro ao carregar grupos',
        description: groupsError.message,
        variant: 'destructive'
      });
      setLoading(false);
      return;
    }
    const {
      data: tabsData,
      error: tabsError
    } = await supabase.from('tabs').select('*').order('position', {
      ascending: true
    });
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
          parsedUrls = (tab.urls as unknown as TabUrl[]).filter(u => u && typeof u === 'object' && 'url' in u);
        }
        // Parse alternative_domains from JSON
        let parsedAltDomains: string[] = [];
        if (tab.alternative_domains && Array.isArray(tab.alternative_domains)) {
          parsedAltDomains = (tab.alternative_domains as unknown as string[]).filter(d => typeof d === 'string');
        }
        return {
          ...tab,
          urls: parsedUrls,
          layout_type: tab.layout_type || 'single',
          keyboard_shortcut: tab.keyboard_shortcut || null,
          alternative_domains: parsedAltDomains,
          capture_token: tab.capture_token ?? false,
          capture_token_header: tab.capture_token_header || 'X-Access-Token',
          webhook_url: tab.webhook_url || null,
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
  const resetGroupForm = useCallback(() => {
    groupDraft.resetToInitial();
    setEditingGroup(null);
  }, [groupDraft]);

  const resetTabForm = useCallback(() => {
    tabDraft.resetToInitial();
    setEditingTab(null);
  }, [tabDraft]);

  function openEditGroupDialog(group: TabGroup) {
    setEditingGroup(group);
    groupDraft.loadValues({
      name: group.name,
      icon: group.icon,
      color: group.color,
    });
    setIsGroupDialogOpen(true);
  }

  function openAddTabDialog(groupId: string) {
    setEditingTab(null);
    // Se não tem rascunho, reseta; se tem, mantém os valores salvos
    if (!tabDraft.hasDraft) {
      tabDraft.resetToInitial();
    }
    tabDraft.updateValue('groupId', groupId);
    setIsTabDialogOpen(true);
  }

  function openEditTabDialog(tab: Tab, groupId: string) {
    setEditingTab(tab);
    // Skip the first URL in the array since it's the main URL (already in tabUrl)
    const additionalUrls = (tab.urls || []).slice(1);
    // Parse main URL shortcut and zoom from first item in urls array
    const mainUrlData = tab.urls?.[0];
    
    tabDraft.loadValues({
      name: tab.name,
      url: tab.url,
      urls: additionalUrls,
      layoutType: tab.layout_type as LayoutType || 'single',
      icon: tab.icon,
      color: tab.color,
      zoom: tab.zoom,
      mainShortcutEnabled: mainUrlData?.shortcut_enabled ?? true,
      mainZoom: mainUrlData?.zoom ?? tab.zoom ?? 100,
      mainSessionGroup: (mainUrlData as any)?.session_group || '',
      openAsWindow: tab.open_as_window,
      shortcut: tab.keyboard_shortcut || '',
      groupId: groupId,
      alternativeDomains: tab.alternative_domains || [],
      showLinkTransformPanel: tab.show_link_transform_panel ?? true,
      captureToken: tab.capture_token ?? false,
      captureTokenHeader: tab.capture_token_header || 'X-Access-Token',
      webhookUrl: tab.webhook_url || '',
    });
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
      const {
        error
      } = await supabase.from('tab_groups').update({
        name: groupName.trim(),
        icon: groupIcon,
        color: groupColor
      }).eq('id', editingGroup.id);
      if (error) {
        toast({
          title: 'Erro ao atualizar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({
          title: 'Grupo atualizado!'
        });
        setIsGroupDialogOpen(false);
        resetGroupForm();
        groupDraft.clearDraft();
        fetchGroups();
      }
    } else {
      const position = groups.length;
      const {
        error
      } = await supabase.from('tab_groups').insert({
        user_id: user.id,
        name: groupName.trim(),
        icon: groupIcon,
        color: groupColor,
        position
      });
      if (error) {
        toast({
          title: 'Erro ao criar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({
          title: 'Grupo criado!'
        });
        setIsGroupDialogOpen(false);
        resetGroupForm();
        groupDraft.clearDraft();
        fetchGroups();
      }
    }
    setSavingGroup(false);
  }
  async function handleDeleteGroup(groupId: string) {
    const {
      error
    } = await supabase.from('tab_groups').delete().eq('id', groupId);
    if (error) {
      toast({
        title: 'Erro ao excluir',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      toast({
        title: 'Grupo excluído!'
      });
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

    // Construir array de URLs (principal + extras) com zoom e session_group individual
    const allUrls: TabUrl[] = [{
      url: tabUrl.trim(),
      shortcut_enabled: tabMainShortcutEnabled,
      zoom: tabMainZoom,
      session_group: tabMainSessionGroup || undefined
    }, ...tabUrls.filter(u => u.url.trim()).map(u => ({
      ...u,
      zoom: u.zoom ?? 100,
      session_group: u.session_group || undefined
    }))];

    // Determinar layout baseado na quantidade de URLs
    const effectiveLayout = allUrls.length > 1 ? tabLayoutType : 'single';
    if (editingTab) {
      const {
        error
      } = await supabase.from('tabs').update({
        name: tabName.trim(),
        url: tabUrl.trim(),
        urls: allUrls as unknown as any,
        layout_type: effectiveLayout,
        icon: tabIcon,
        color: tabColor,
        zoom: tabZoom,
        open_as_window: tabOpenAsWindow,
        keyboard_shortcut: tabShortcut || null,
        alternative_domains: tabAlternativeDomains.filter(d => d.trim()) as unknown as any,
        show_link_transform_panel: tabShowLinkTransformPanel,
        capture_token: tabCaptureToken,
        capture_token_header: tabCaptureTokenHeader || 'X-Access-Token',
        webhook_url: tabWebhookUrl.trim() || null
      }).eq('id', editingTab.id);
      if (error) {
        toast({
          title: 'Erro ao atualizar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({
          title: 'Aba atualizada!'
        });
        setIsTabDialogOpen(false);
        resetTabForm();
        tabDraft.clearDraft();
        fetchGroups();
      }
    } else {
      const group = groups.find(g => g.id === selectedGroupId);
      const position = group?.tabs.length || 0;
      const {
        error
      } = await supabase.from('tabs').insert([{
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
        position,
        alternative_domains: tabAlternativeDomains.filter(d => d.trim()) as unknown as any,
        show_link_transform_panel: tabShowLinkTransformPanel,
        capture_token: tabCaptureToken,
        capture_token_header: tabCaptureTokenHeader || 'X-Access-Token',
        webhook_url: tabWebhookUrl.trim() || null
      }]);
      if (error) {
        toast({
          title: 'Erro ao criar',
          description: error.message,
          variant: 'destructive'
        });
      } else {
        toast({
          title: 'Aba criada!'
        });
        setIsTabDialogOpen(false);
        resetTabForm();
        tabDraft.clearDraft();
        fetchGroups();
      }
    }
    setSavingTab(false);
  }
  async function handleDeleteTab(tabId: string) {
    const {
      error
    } = await supabase.from('tabs').delete().eq('id', tabId);
    if (error) {
      toast({
        title: 'Erro ao excluir',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      toast({
        title: 'Aba excluída!'
      });
      fetchGroups();
    }
  }

  // DnD sensors
  const sensors = useSensors(useSensor(PointerSensor, {
    activationConstraint: {
      distance: 8
    }
  }), useSensor(KeyboardSensor, {
    coordinateGetter: sortableKeyboardCoordinates
  }));

  // Handle tab reorder
  async function handleDragEnd(event: DragEndEvent, groupId: string) {
    const {
      active,
      over
    } = event;
    if (!over || active.id === over.id) return;
    const group = groups.find(g => g.id === groupId);
    if (!group) return;
    const oldIndex = group.tabs.findIndex(t => t.id === active.id);
    const newIndex = group.tabs.findIndex(t => t.id === over.id);
    if (oldIndex === -1 || newIndex === -1) return;

    // Update local state optimistically
    const newTabs = arrayMove(group.tabs, oldIndex, newIndex);
    setGroups(prev => prev.map(g => g.id === groupId ? {
      ...g,
      tabs: newTabs
    } : g));

    // Update positions in database
    const updates = newTabs.map((tab, index) => supabase.from('tabs').update({
      position: index
    }).eq('id', tab.id));
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

  // Exportar grupos e abas
  function exportData() {
    const exportData = {
      exportDate: new Date().toISOString(),
      version: '1.0',
      tab_groups: groups.map(g => ({
        id: g.id,
        name: g.name,
        icon: g.icon,
        color: g.color,
        position: g.position
      })),
      tabs: groups.flatMap(g => g.tabs.map(t => ({
        id: t.id,
        group_id: g.id,
        name: t.name,
        url: t.url,
        urls: t.urls,
        layout_type: t.layout_type,
        icon: t.icon,
        color: t.color,
        zoom: t.zoom,
        position: t.position,
        open_as_window: t.open_as_window,
        keyboard_shortcut: t.keyboard_shortcut
      })))
    };
    const data = JSON.stringify(exportData, null, 2);
    const blob = new Blob([data], {
      type: 'application/json'
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'grupos-abas.json';
    a.click();
    URL.revokeObjectURL(url);
    toast({
      title: 'Dados exportados!'
    });
  }

  // Importar grupos e abas
  async function importData(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file || !user) return;
    try {
      const text = await file.text();
      
      // Mapear IDs antigos para novos
      const groupIdMap: Record<string, string> = {};
      let importedGroups = 0;
      let importedTabs = 0;

      // Verificar se é formato TXT de grupos (contém "GRUPO:" e "URL:")
      const isTabGroupsTxt = text.includes('GRUPO:') && text.includes('URL:');
      
      if (isTabGroupsTxt) {
        // Formato TXT exportado - usar parser dedicado
        const parsedGroups = parseTabGroupsTxt(text);
        
        for (const group of parsedGroups) {
          // Criar o grupo
          const { data: groupData, error: groupError } = await supabase
            .from('tab_groups')
            .insert({
              user_id: user.id,
              name: group.name,
              icon: 'folder',
              color: '#6366f1',
              position: groups.length + importedGroups
            })
            .select('id')
            .single();
          
          if (groupError || !groupData) continue;
          importedGroups++;
          
          // Criar as abas do grupo
          for (const tab of group.tabs) {
            const layoutType = getLayoutForUrlCount(tab.urls_count);
            
            const { error: tabError } = await supabase
              .from('tabs')
              .insert({
                user_id: user.id,
                group_id: groupData.id,
                name: tab.name,
                url: tab.url,
                urls: [{ url: tab.url, shortcut_enabled: true, zoom: 100 }] as unknown as any,
                layout_type: layoutType,
                icon: 'globe',
                color: '#22d3ee',
                zoom: 100,
                position: tab.position,
                keyboard_shortcut: tab.keyboard_shortcut
              });
            
            if (!tabError) importedTabs++;
          }
        }
        
        toast({
          title: `Importados: ${importedGroups} grupos e ${importedTabs} abas!`
        });
        fetchGroups();
        event.target.value = '';
        return;
      }

      // Verificar se é formato SQL (INSERT INTO TBL_NAVEGADOR_PAGINAS)
      if (text.includes('INSERT INTO') && text.includes('TBL_NAVEGADOR_PAGINAS')) {
        // Formato SQL - extrair grupos e abas
        const insertRegex = /VALUES\s*\(([^']+)\s+'([^']+)',\s*'([^']+)'\)/gi;
        
        // Map para agrupar abas por grupo
        const groupsMap = new Map<string, Array<{name: string, url: string}>>();
        
        let match;
        while ((match = insertRegex.exec(text)) !== null) {
          const groupName = match[1].trim();
          const tabName = match[2].trim();
          let url = match[3].trim();
          
          // Garantir que URL tem protocolo
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            url = 'https://' + url;
          }
          
          if (!groupsMap.has(groupName)) {
            groupsMap.set(groupName, []);
          }
          groupsMap.get(groupName)!.push({ name: tabName, url });
        }
        
        // Criar grupos e abas
        for (const [groupName, tabs] of groupsMap) {
          // Criar o grupo
          const { data: groupData, error: groupError } = await supabase
            .from('tab_groups')
            .insert({
              user_id: user.id,
              name: groupName,
              icon: 'folder',
              color: '#6366f1',
              position: groups.length + importedGroups
            })
            .select('id')
            .single();
          
          if (groupError || !groupData) continue;
          importedGroups++;
          
          // Criar as abas do grupo
          for (let i = 0; i < tabs.length; i++) {
            const tab = tabs[i];
            const { error: tabError } = await supabase
              .from('tabs')
              .insert({
                user_id: user.id,
                group_id: groupData.id,
                name: tab.name,
                url: tab.url,
                urls: [{ url: tab.url, shortcut_enabled: true, zoom: 100 }] as unknown as any,
                layout_type: 'single',
                icon: 'globe',
                color: '#22d3ee',
                zoom: 100,
                position: i
              });
            
            if (!tabError) importedTabs++;
          }
        }
        
        toast({
          title: `Importados: ${importedGroups} grupos e ${importedTabs} abas!`
        });
        fetchGroups();
        event.target.value = '';
        return;
      }

      // Formato JSON
      const parsed = JSON.parse(text);

      // Detectar formato: tabGroups (externo) ou tab_groups (nosso)
      const sourceGroups = parsed.tabGroups || parsed.tab_groups || [];
      const sourceTabs = parsed.savedTabs || parsed.tabs || [];

      // Importar grupos
      for (const group of sourceGroups) {
        const newPosition = groups.length + importedGroups;
        const {
          data,
          error
        } = await supabase.from('tab_groups').insert({
          user_id: user.id,
          name: group.name,
          icon: group.icon || 'folder',
          color: group.color || '#6366f1',
          position: newPosition
        }).select('id').single();
        if (!error && data) {
          groupIdMap[group.id] = data.id;
          importedGroups++;
        }
      }

      // Importar tabs
      for (const tab of sourceTabs) {
        const newGroupId = groupIdMap[tab.group_id];
        if (!newGroupId) continue;

        // Converter formato de URLs se necessário
        let urls: TabUrl[] = [];
        if (tab.urls && Array.isArray(tab.urls)) {
          // Formato antigo: array de strings ou array de objetos
          urls = tab.urls.map((u: any) => {
            if (typeof u === 'string') {
              return {
                url: u,
                shortcut_enabled: true,
                zoom: 100
              };
            }
            return {
              url: u.url || u,
              shortcut_enabled: u.shortcut_enabled ?? u.enable_quick_messages ?? true,
              zoom: u.zoom || 100
            };
          });
        }

        // Se não tem urls array, usar a url principal
        if (urls.length === 0 && tab.url) {
          urls.push({
            url: tab.url,
            shortcut_enabled: tab.enable_quick_messages ?? true,
            zoom: 100
          });
        }

        // Determinar layout baseado em columns/rows ou layout_type
        let layoutType = tab.layout_type || 'single';
        if (tab.columns === 2 && tab.rows === 1) layoutType = '50-50';else if (tab.columns === 3 && tab.rows === 1) layoutType = '33-33-33';else if (tab.columns === 2 && tab.rows === 2) layoutType = '2x2';
        const {
          error
        } = await supabase.from('tabs').insert({
          user_id: user.id,
          group_id: newGroupId,
          name: tab.name,
          url: tab.url,
          urls: urls as unknown as any,
          layout_type: layoutType,
          icon: tab.icon || 'globe',
          color: tab.color || '#22d3ee',
          zoom: tab.zoom || 100,
          position: tab.tab_order ?? tab.position ?? 0,
          open_as_window: tab.open_as_window || false,
          keyboard_shortcut: tab.keyboard_shortcut || null
        });
        if (!error) importedTabs++;
      }
      toast({
        title: `Importados: ${importedGroups} grupos e ${importedTabs} abas!`
      });
      fetchGroups();
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
  return <div className="flex flex-col h-full overflow-hidden mx-[10px]">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Grupos de Abas</h1>
          <p className="text-muted-foreground mt-1">
            Organize suas páginas em grupos para abrir no navegador
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={exportData} title="Exportar">
            <FileDown className="h-4 w-4" />
          </Button>
          <label>
            <Button variant="outline" size="icon" asChild title="Importar">
              <span><FileUp className="h-4 w-4" /></span>
            </Button>
            <input type="file" accept=".json,.sql,.txt" className="hidden" onChange={importData} />
          </label>
          <Dialog open={isGroupDialogOpen} onOpenChange={open => {
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
              <DialogTitle className="flex items-center gap-2">
                {editingGroup ? 'Editar Grupo' : 'Novo Grupo de Abas'}
                {groupDraft.hasDraft && !editingGroup && (
                  <span className="text-xs font-normal text-muted-foreground flex items-center gap-1">
                    <Save className="h-3 w-3" />
                    Rascunho
                  </span>
                )}
              </DialogTitle>
              <DialogDescription>
                Crie um grupo para organizar suas páginas
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="group-name">Nome do Grupo *</Label>
                <Input id="group-name" placeholder="Ex: Atendimento" value={groupName} onChange={e => setGroupName(e.target.value)} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Ícone</Label>
                  <IconSelect value={groupIcon} onValueChange={setGroupIcon} className="w-full" />
                </div>
                <div className="space-y-2">
                  <Label>Cor</Label>
                  <Select value={groupColor} onValueChange={setGroupColor}>
                    <SelectTrigger>
                      <div className="flex items-center gap-2">
                        <div className="w-4 h-4 rounded-full" style={{
                          backgroundColor: groupColor
                        }} />
                        <SelectValue />
                      </div>
                    </SelectTrigger>
                    <SelectContent className="max-h-[300px]">
                      {colorOptions.map(color => (
                        <SelectItem key={color.value} value={color.value}>
                          <div className="flex items-center gap-2">
                            <div className="w-4 h-4 rounded-full" style={{ backgroundColor: color.value }} />
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
      </div>

      {/* Tab Dialog */}
      <Dialog open={isTabDialogOpen} onOpenChange={open => {
      setIsTabDialogOpen(open);
      if (!open) resetTabForm();
    }}>
        <DialogContent className="sm:max-w-[550px] max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {editingTab ? 'Editar Aba' : 'Nova Aba'}
              {tabDraft.hasDraft && !editingTab && (
                <span className="text-xs font-normal text-muted-foreground flex items-center gap-1">
                  <Save className="h-3 w-3" />
                  Rascunho
                </span>
              )}
            </DialogTitle>
            <DialogDescription>
              Configure os detalhes da página
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {/* Nome e ícone/cor em linha */}
            <div className="flex gap-3">
              <div className="flex-1 space-y-2">
                <Label htmlFor="tab-name">Nome *</Label>
                <Input id="tab-name" placeholder="Ex: Plim" value={tabName} onChange={e => setTabName(e.target.value)} />
              </div>
              <div className="flex items-end gap-2">
                <IconSelect value={tabIcon} onValueChange={setTabIcon} color={tabColor} />
                <Select value={tabColor} onValueChange={setTabColor}>
                  <SelectTrigger className="w-14 h-10">
                    <div className="w-6 h-6 rounded-full" style={{
                    backgroundColor: tabColor
                  }} />
                  </SelectTrigger>
                  <SelectContent>
                    {colorOptions.map(color => <SelectItem key={color.value} value={color.value}>
                        <div className="flex items-center gap-2">
                          <div className="w-4 h-4 rounded-full" style={{
                        backgroundColor: color.value
                      }} />
                          {color.label}
                        </div>
                      </SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Atalho de teclado */}
            <div className="space-y-2">
              <Label htmlFor="tab-shortcut">Atalho de Teclado (Opcional)</Label>
              <Input id="tab-shortcut" placeholder="Atalho para abrir esta aba/janela rapidamente" value={tabShortcut} onChange={e => setTabShortcut(e.target.value)} />
            </div>

            {/* Grupo */}
            <div className="space-y-2">
              <Label>Grupo</Label>
              <Select value={selectedGroupId || ''} onValueChange={setSelectedGroupId}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione um grupo" />
                </SelectTrigger>
                <SelectContent>
                  {groups.map(group => <SelectItem key={group.id} value={group.id}>
                      <div className="flex items-center gap-2">
                        <FolderOpen className="h-4 w-4" style={{
                      color: group.color
                    }} />
                        {group.name}
                      </div>
                    </SelectItem>)}
                </SelectContent>
              </Select>
            </div>

            {/* URLs */}
            <TabUrlsEditor urls={tabUrls} onChange={setTabUrls} mainUrl={tabUrl} onMainUrlChange={setTabUrl} mainShortcutEnabled={tabMainShortcutEnabled} onMainShortcutEnabledChange={setTabMainShortcutEnabled} mainZoom={tabMainZoom} onMainZoomChange={setTabMainZoom} mainSessionGroup={tabMainSessionGroup} onMainSessionGroupChange={setTabMainSessionGroup} existingSessionGroups={existingSessionGroups} />

            {/* Layout Selector (só mostra se tiver mais de 1 URL) */}
            {tabUrls.length > 0 && <LayoutSelector value={tabLayoutType} onChange={setTabLayoutType} urlCount={1 + tabUrls.filter(u => u.url.trim()).length} />}

            {/* Domínios Alternativos - só mostra se "Abrir como janela" estiver marcado */}
            {tabOpenAsWindow && (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <Label className="flex items-center gap-2">
                      <Link className="h-4 w-4" />
                      Domínios Alternativos
                    </Label>
                    <p className="text-xs text-muted-foreground">
                      Configure domínios para transformação de links na janela flutuante
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => setTabAlternativeDomains([...tabAlternativeDomains, ''])}
                  >
                    <Plus className="h-3 w-3 mr-1" />
                    Adicionar
                  </Button>
                </div>
                
                {tabAlternativeDomains.length > 0 && (
                  <div className="space-y-2">
                    {tabAlternativeDomains.map((domain, index) => (
                      <div key={index} className="flex gap-2">
                        <Input
                          placeholder="http://exemplo.ddns.net"
                          value={domain}
                          onChange={(e) => {
                            const newDomains = [...tabAlternativeDomains];
                            newDomains[index] = e.target.value;
                            setTabAlternativeDomains(newDomains);
                          }}
                        />
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            const newDomains = tabAlternativeDomains.filter((_, i) => i !== index);
                            setTabAlternativeDomains(newDomains);
                          }}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    ))}
                  </div>
                )}

                {/* Mostrar painel de transformação */}
                {tabAlternativeDomains.filter(d => d.trim()).length > 0 && (
                  <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
                    <div>
                      <Label htmlFor="show-link-panel">Mostrar painel de transformação</Label>
                      <p className="text-xs text-muted-foreground">
                        Exibe um painel fixo na janela flutuante para transformar links
                      </p>
                    </div>
                    <Switch 
                      id="show-link-panel" 
                      checked={tabShowLinkTransformPanel} 
                      onCheckedChange={setTabShowLinkTransformPanel} 
                    />
                  </div>
                )}

                {/* Capturar Token */}
                <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
                  <div>
                    <Label htmlFor="capture-token">Capturar Token</Label>
                    <p className="text-xs text-muted-foreground">
                      Captura automaticamente o token de autenticação das requisições
                    </p>
                  </div>
                  <Switch 
                    id="capture-token" 
                    checked={tabCaptureToken} 
                    onCheckedChange={setTabCaptureToken} 
                  />
                </div>

                {/* Header do token - só mostra se captura estiver habilitada */}
                {tabCaptureToken && (
                  <>
                    <div className="space-y-2">
                      <Label htmlFor="capture-token-header">Nome do Header</Label>
                      <Input
                        id="capture-token-header"
                        placeholder="X-Access-Token"
                        value={tabCaptureTokenHeader}
                        onChange={(e) => setTabCaptureTokenHeader(e.target.value)}
                      />
                      <p className="text-xs text-muted-foreground">
                        Nome do header HTTP que contém o token (default: X-Access-Token)
                      </p>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="webhook-url">URL do Webhook (opcional)</Label>
                      <Input
                        id="webhook-url"
                        placeholder="https://seu-sistema.com/api/token-webhook"
                        value={tabWebhookUrl}
                        onChange={(e) => setTabWebhookUrl(e.target.value)}
                      />
                      <p className="text-xs text-muted-foreground">
                        Quando um token for capturado, ele será enviado automaticamente via POST para esta URL
                      </p>
                    </div>
                  </>
                )}
              </div>
            )}

            {/* Abrir como janela */}
            <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
              <div>
                <Label htmlFor="open-window">Abrir como janela</Label>
                <p className="text-xs text-muted-foreground">
                  Se marcado, esta aba será aberta em uma nova janela do navegador ao invés de carregar nas abas
                </p>
              </div>
              <Switch id="open-window" checked={tabOpenAsWindow} onCheckedChange={setTabOpenAsWindow} />
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
      <div className="flex-1 overflow-y-auto pb-6 mt-6">
      {loading ? <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div> : groups.length === 0 ? <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 rounded-full bg-primary/10 mb-4">
              <FolderOpen className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Nenhum grupo criado</h3>
            <p className="text-muted-foreground text-center max-w-md">
              Crie seu primeiro grupo de abas para organizar suas páginas
            </p>
          </CardContent>
        </Card> : <div className="space-y-4">
          {groups.map(group => <Card key={group.id} className="overflow-hidden">
              {/* Group Header */}
              <div className="flex items-center gap-3 p-4 cursor-pointer hover:bg-secondary/50 transition-colors" onClick={() => toggleGroup(group.id)}>
                <div className="p-2 rounded-lg" style={{
            backgroundColor: `${group.color}20`
          }}>
                  <DynamicIcon icon={group.icon || 'folder-open'} className="h-5 w-5" style={{
              color: group.color
            }} />
                </div>
                <div className="flex-1">
                  <h3 className="font-semibold">{group.name}</h3>
                  <p className="text-sm text-muted-foreground">
                    {group.tabs.length} {group.tabs.length === 1 ? 'aba' : 'abas'}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Button variant="ghost" size="icon" onClick={e => {
              e.stopPropagation();
              openAddTabDialog(group.id);
            }}>
                    <Plus className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="icon" onClick={e => {
              e.stopPropagation();
              openEditGroupDialog(group);
            }}>
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="icon" className="text-destructive hover:text-destructive" onClick={e => {
              e.stopPropagation();
              setDeleteGroupConfirm(group);
            }}>
                    <Trash2 className="h-4 w-4" />
                  </Button>
                  {expandedGroups.has(group.id) ? <ChevronDown className="h-4 w-4 text-muted-foreground" /> : <ChevronRight className="h-4 w-4 text-muted-foreground" />}
                </div>
              </div>

              {/* Tabs List */}
              {expandedGroups.has(group.id) && <div className="border-t border-border">
                  {group.tabs.length === 0 ? <div className="p-6 text-center text-muted-foreground">
                      <Globe className="h-8 w-8 mx-auto mb-2 opacity-50" />
                      <p>Nenhuma aba neste grupo</p>
                      <Button variant="link" onClick={() => openAddTabDialog(group.id)}>
                        <Plus className="mr-1 h-3 w-3" />
                        Adicionar aba
                      </Button>
                    </div> : <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={event => handleDragEnd(event, group.id)}>
                      <SortableContext items={group.tabs.map(t => t.id)} strategy={verticalListSortingStrategy}>
                        <div className="divide-y divide-border">
                          {group.tabs.map(tab => <SortableTab key={tab.id} tab={tab} groupId={group.id} onEdit={openEditTabDialog} onDelete={handleDeleteTab} />)}
                        </div>
                      </SortableContext>
                    </DndContext>}
                </div>}
            </Card>)}
        </div>}
      </div>

      {/* Delete Group Confirmation */}
      <AlertDialog open={!!deleteGroupConfirm} onOpenChange={(open) => !open && setDeleteGroupConfirm(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir grupo</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir o grupo "{deleteGroupConfirm?.name}"? 
              {deleteGroupConfirm?.tabs && deleteGroupConfirm.tabs.length > 0 && (
                <> Todas as {deleteGroupConfirm.tabs.length} aba(s) serão excluídas também.</>
              )}
              {' '}Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction 
              onClick={() => {
                if (deleteGroupConfirm) {
                  handleDeleteGroup(deleteGroupConfirm.id);
                  setDeleteGroupConfirm(null);
                }
              }} 
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>;
}
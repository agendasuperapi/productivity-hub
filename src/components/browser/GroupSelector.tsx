import { useCallback, useState, useEffect, useRef, useLayoutEffect } from 'react';
import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';
import { GripVertical, Plus, Pencil, Trash2, ChevronDown, MoreHorizontal } from 'lucide-react';
import { cn } from '@/lib/utils';
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
  horizontalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
  ContextMenuSeparator,
} from '@/components/ui/context-menu';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { colorOptions } from '@/lib/iconOptions';
import { IconSelect } from '@/components/ui/icon-select';

interface SortableGroupButtonProps {
  group: {
    id: string;
    name: string;
    icon?: string;
    color?: string;
  };
  isActive: boolean;
  isDragMode: boolean;
  onSelect: () => void;
  onEdit: () => void;
  onDelete: () => void;
}

function SortableGroupButton({ group, isActive, isDragMode, onSelect, onEdit, onDelete }: SortableGroupButtonProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: group.id, disabled: !isDragMode });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition: transition || 'transform 200ms ease, box-shadow 200ms ease',
    zIndex: isDragging ? 9999 : undefined,
    position: isDragging ? 'relative' : undefined,
    scale: isDragging ? 1.05 : 1,
    boxShadow: isDragging ? '0 8px 20px -4px rgba(0,0,0,0.3)' : undefined,
  };

  const buttonContent = (
    <Button
      ref={setNodeRef}
      variant={isActive ? "default" : "ghost"}
      size="sm"
      onClick={() => {
        if (!isDragMode) {
          onSelect();
        }
      }}
      className={cn(
        "rounded-full px-3 gap-2 h-8 transition-all duration-200",
        "hover:scale-105 hover:shadow-lg hover:shadow-primary/20",
        isActive && "shadow-md shadow-primary/30",
        isDragMode && "cursor-grab active:cursor-grabbing ring-2 ring-primary/20 hover:ring-primary/40",
        isDragging && "opacity-90 ring-2 ring-primary scale-105"
      )}
      style={{
        ...style,
        ...(group.color && !isActive ? {
          '--hover-glow': group.color,
        } as React.CSSProperties : {}),
      }}
      {...(isDragMode ? { ...attributes, ...listeners } : {})}
    >
      {isDragMode && <GripVertical className="h-3 w-3 opacity-50" />}
      <DynamicIcon 
        icon={group.icon} 
        fallback="📁" 
        className={cn(
          "h-4 w-4 transition-transform duration-200",
          !isDragMode && "group-hover:scale-110"
        )} 
        style={group.color ? { color: group.color } : undefined}
      />
      <span className="hidden sm:inline">{group.name}</span>
    </Button>
  );

  if (isDragMode) {
    return buttonContent;
  }

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        {buttonContent}
      </ContextMenuTrigger>
      <ContextMenuContent>
        <ContextMenuItem onClick={onEdit}>
          <Pencil className="mr-2 h-4 w-4" />
          Editar grupo
        </ContextMenuItem>
        <ContextMenuSeparator />
        <ContextMenuItem onClick={onDelete} className="text-destructive focus:text-destructive">
          <Trash2 className="mr-2 h-4 w-4" />
          Excluir grupo
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  );
}

export function GroupSelector() {
  const context = useBrowser();
  const navigate = useNavigate();
  const { user } = useAuth();
  
  // Refs para cálculo dinâmico de grupos visíveis
  const containerRef = useRef<HTMLDivElement>(null);
  const [visibleGroups, setVisibleGroups] = useState<Array<{ id: string; name: string; icon?: string; color?: string; position: number; tabs: any[] }>>([]);
  const [hiddenGroups, setHiddenGroups] = useState<Array<{ id: string; name: string; icon?: string; color?: string; position: number; tabs: any[] }>>([]);
  
  // Estados para diálogos
  const [isGroupDialogOpen, setIsGroupDialogOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<{ id: string; name: string; icon?: string; color?: string } | null>(null);
  const [groupName, setGroupName] = useState('');
  const [groupIcon, setGroupIcon] = useState('folder');
  const [groupColor, setGroupColor] = useState('#6366f1');
  const [saving, setSaving] = useState(false);

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

  const handleDragEnd = useCallback(async (event: DragEndEvent) => {
    const { active, over } = event;
    
    if (!over || active.id === over.id || !context || !user) return;

    const oldIndex = context.groups.findIndex(g => g.id === active.id);
    const newIndex = context.groups.findIndex(g => g.id === over.id);

    if (oldIndex === -1 || newIndex === -1) return;

    const reorderedGroups = arrayMove(context.groups, oldIndex, newIndex);
    
    // Atualizar estado local imediatamente
    context.reorderGroups(reorderedGroups);
    
    // Atualizar posições no banco de dados
    try {
      const updates = reorderedGroups.map((group, index) => 
        supabase
          .from('tab_groups')
          .update({ position: index })
          .eq('id', group.id)
          .eq('user_id', user.id)
      );
      
      await Promise.all(updates);
      
      toast.success('Ordem dos grupos atualizada');
    } catch (error) {
      console.error('Erro ao reordenar grupos:', error);
      toast.error('Erro ao reordenar grupos');
      context.refreshData();
    }
  }, [context, user]);

  const openNewGroupDialog = useCallback(() => {
    setEditingGroup(null);
    setGroupName('');
    setGroupIcon('folder');
    setGroupColor('#6366f1');
    setIsGroupDialogOpen(true);
  }, []);

  const openEditGroupDialog = useCallback((group: { id: string; name: string; icon?: string; color?: string }) => {
    setEditingGroup(group);
    setGroupName(group.name);
    setGroupIcon(group.icon || 'folder');
    setGroupColor(group.color || '#6366f1');
    setIsGroupDialogOpen(true);
  }, []);

  const handleSaveGroup = useCallback(async () => {
    if (!user || !groupName.trim()) {
      toast.error('Nome do grupo é obrigatório');
      return;
    }
    
    setSaving(true);
    
    try {
      if (editingGroup) {
        const { error } = await supabase
          .from('tab_groups')
          .update({
            name: groupName.trim(),
            icon: groupIcon,
            color: groupColor,
          })
          .eq('id', editingGroup.id)
          .eq('user_id', user.id);
        
        if (error) throw error;
        toast.success('Grupo atualizado!');
      } else {
        const position = context?.groups.length || 0;
        const { error } = await supabase
          .from('tab_groups')
          .insert({
            user_id: user.id,
            name: groupName.trim(),
            icon: groupIcon,
            color: groupColor,
            position,
          });
        
        if (error) throw error;
        toast.success('Grupo criado!');
      }
      
      setIsGroupDialogOpen(false);
      context?.refreshData();
    } catch (error: any) {
      toast.error(error.message || 'Erro ao salvar grupo');
    } finally {
      setSaving(false);
    }
  }, [user, groupName, groupIcon, groupColor, editingGroup, context]);

  const handleDeleteGroup = useCallback(async (groupId: string) => {
    if (!user || !context) return;
    
    // Encontrar o grupo e suas abas antes de excluir
    const groupToDelete = context.groups.find(g => g.id === groupId);
    if (!groupToDelete) return;
    
    // Salvar dados para possível restauração
    const groupData = {
      id: groupToDelete.id,
      name: groupToDelete.name,
      icon: groupToDelete.icon || 'folder',
      color: groupToDelete.color || '#6366f1',
      position: groupToDelete.position,
    };
    const tabsData = groupToDelete.tabs.map(tab => ({
      ...tab,
      group_id: groupId,
    }));
    
    try {
      // Excluir grupo (as abas serão excluídas em cascata pelo DB)
      const { error } = await supabase
        .from('tab_groups')
        .delete()
        .eq('id', groupId)
        .eq('user_id', user.id);
      
      if (error) throw error;
      
      // Atualizar UI
      context.refreshData();
      
      // Mostrar toast com opção de desfazer
      toast.success('Grupo excluído', {
        description: `"${groupData.name}" foi removido`,
        action: {
          label: 'Desfazer',
          onClick: async () => {
            try {
              // Restaurar grupo
              const { error: restoreGroupError } = await supabase
                .from('tab_groups')
                .insert({
                  id: groupData.id,
                  user_id: user.id,
                  name: groupData.name,
                  icon: groupData.icon,
                  color: groupData.color,
                  position: groupData.position,
                });
              
              if (restoreGroupError) throw restoreGroupError;
              
              // Restaurar abas se existiam
              if (tabsData.length > 0) {
                const tabsToRestore = tabsData.map(tab => ({
                  id: tab.id,
                  user_id: user.id,
                  group_id: groupData.id,
                  name: tab.name,
                  url: tab.url,
                  urls: tab.urls as any,
                  layout_type: tab.layout_type,
                  icon: tab.icon,
                  color: tab.color,
                  zoom: tab.zoom,
                  position: tab.position,
                  open_as_window: tab.open_as_window,
                  keyboard_shortcut: tab.keyboard_shortcut,
                  alternative_domains: tab.alternative_domains as any,
                  show_link_transform_panel: tab.show_link_transform_panel,
                  capture_token: tab.capture_token,
                  capture_token_header: tab.capture_token_header,
                }));
                
                const { error: restoreTabsError } = await supabase
                  .from('tabs')
                  .insert(tabsToRestore);
                
                if (restoreTabsError) {
                  console.error('Erro ao restaurar abas:', restoreTabsError);
                }
              }
              
              toast.success('Grupo restaurado!');
              context.refreshData();
            } catch (restoreError: any) {
              toast.error('Erro ao restaurar grupo');
              console.error(restoreError);
            }
          },
        },
        duration: 8000, // 8 segundos para dar tempo de desfazer
      });
    } catch (error: any) {
      toast.error(error.message || 'Erro ao excluir grupo');
    }
  }, [user, context]);

  const groups = context?.groups ?? [];
  const activeGroup = context?.activeGroup;
  const setActiveGroup = context?.setActiveGroup;
  const isDragMode = context?.isDragMode ?? false;
  const activeVirtualTab = context?.activeVirtualTab;
  const setActiveVirtualTab = context?.setActiveVirtualTab;
  
  // Não marcar nenhum grupo como ativo se houver aba virtual aberta
  const effectiveActiveGroupId = activeVirtualTab ? null : activeGroup?.id;
  
  // Cálculo dinâmico de grupos visíveis baseado no espaço disponível
  const calculateOverflow = useCallback(() => {
    const container = containerRef.current;
    if (!container || !groups || groups.length === 0) return;

    const containerWidth = container.clientWidth;
    // Estimativas mais precisas baseadas nos tamanhos reais do CSS
    const groupWidth = 36; // h-8 px-3 rounded-full com só ícone
    const gap = 4; // gap-1
    const addButtonWidth = 32; // h-8 w-8
    const dropdownWidth = 72; // min-w-[52px] + ícone + texto + chevron
    
    // Calcular quantos grupos cabem
    const totalGroups = groups.length;
    
    // Primeiro testar se cabem todos sem dropdown
    const widthWithAll = (totalGroups * groupWidth) + ((totalGroups - 1) * gap) + addButtonWidth;
    
    if (widthWithAll <= containerWidth) {
      // Cabem todos
      setVisibleGroups([...groups]);
      setHiddenGroups([]);
      return;
    }
    
    // Precisamos de dropdown - calcular quantos cabem
    const availableForGroups = containerWidth - dropdownWidth - addButtonWidth;
    const maxVisible = Math.max(1, Math.floor((availableForGroups + gap) / (groupWidth + gap)));
    
    setVisibleGroups(groups.slice(0, maxVisible));
    setHiddenGroups(groups.slice(maxVisible));
  }, [groups]);

  // Observe container resize
  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const observer = new ResizeObserver(() => {
      calculateOverflow();
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, [calculateOverflow]);

  // Recalcular quando grupos mudam
  useEffect(() => {
    calculateOverflow();
  }, [groups, calculateOverflow]);
  
  // Early return DEPOIS de todos os hooks
  if (!context || context.loading) {
    return null;
  }
  
  const hasHiddenGroups = hiddenGroups.length > 0;
  
  // Verificar se o grupo ativo está nos ocultos
  const activeGroupInHidden = hiddenGroups.some(g => g.id === effectiveActiveGroupId);

  const handleGroupSelect = (group: typeof groups[0]) => {
    if (activeVirtualTab) {
      setActiveVirtualTab?.(null);
    }
    setActiveGroup?.(group);
    navigate('/browser');
  };

  return (
    <>
      <div ref={containerRef} className="flex items-center gap-1 flex-1 min-w-0 overflow-hidden">
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
          <SortableContext 
            items={visibleGroups.map(g => g.id)} 
            strategy={horizontalListSortingStrategy}
          >
            {visibleGroups.map(group => (
              <SortableGroupButton
                key={group.id}
                group={group}
                isActive={effectiveActiveGroupId === group.id}
                isDragMode={isDragMode}
                onSelect={() => handleGroupSelect(group)}
                onEdit={() => openEditGroupDialog(group)}
                onDelete={() => handleDeleteGroup(group.id)}
              />
            ))}
          </SortableContext>
        </DndContext>
        
        {/* Dropdown para grupos ocultos ou botão + no mobile/tablet */}
        {hasHiddenGroups ? (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant={activeGroupInHidden ? "default" : "outline"}
                size="sm"
                className={cn(
                  "rounded-full px-2 gap-1 h-8 min-w-[52px]",
                  activeGroupInHidden && "shadow-md shadow-primary/30"
                )}
              >
                <MoreHorizontal className="h-4 w-4" />
                <span className="text-xs font-medium">+{hiddenGroups.length}</span>
                <ChevronDown className="h-3 w-3" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="max-h-64 overflow-y-auto">
              {hiddenGroups.map(group => (
                <DropdownMenuItem
                  key={group.id}
                  onClick={() => handleGroupSelect(group)}
                  className={cn(
                    "flex items-center gap-2 cursor-pointer",
                    effectiveActiveGroupId === group.id && "bg-accent"
                  )}
                >
                  <DynamicIcon 
                    icon={group.icon} 
                    fallback="📁" 
                    className="h-4 w-4" 
                    style={group.color ? { color: group.color } : undefined}
                  />
                  <span>{group.name}</span>
                </DropdownMenuItem>
              ))}
              {/* Botão de criar grupo dentro do dropdown no mobile/tablet */}
              <DropdownMenuItem
                onClick={openNewGroupDialog}
                className="flex items-center gap-2 cursor-pointer text-primary"
              >
                <Plus className="h-4 w-4" />
                <span>Novo grupo</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        ) : null}
        
        {/* Botão para criar novo grupo - só visível no desktop ou quando não tem grupos ocultos */}
        <Button
          variant="ghost"
          size="sm"
          className={cn(
            "rounded-full h-8 w-8 p-0 flex-shrink-0",
            hasHiddenGroups && "hidden lg:flex"
          )}
          onClick={openNewGroupDialog}
          title="Criar novo grupo"
        >
          <Plus className="h-4 w-4" />
        </Button>
      </div>

      {/* Dialog para criar/editar grupo */}
      <Dialog open={isGroupDialogOpen} onOpenChange={setIsGroupDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editingGroup ? 'Editar Grupo' : 'Novo Grupo'}</DialogTitle>
            <DialogDescription>
              {editingGroup ? 'Atualize as informações do grupo.' : 'Crie um novo grupo para organizar suas abas.'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="group-name">Nome</Label>
              <Input
                id="group-name"
                value={groupName}
                onChange={(e) => setGroupName(e.target.value)}
                placeholder="Nome do grupo"
              />
            </div>
            
            <div className="space-y-2">
              <Label>Ícone</Label>
              <IconSelect value={groupIcon} onValueChange={setGroupIcon} className="w-full" />
            </div>
            
            <div className="space-y-2">
              <Label>Cor</Label>
              <Select value={groupColor} onValueChange={setGroupColor}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {colorOptions.map(opt => (
                    <SelectItem key={opt.value} value={opt.value}>
                      <div className="flex items-center gap-2">
                        <div 
                          className="w-4 h-4 rounded-full" 
                          style={{ backgroundColor: opt.value }}
                        />
                        {opt.label}
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
          
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsGroupDialogOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleSaveGroup} disabled={saving}>
              {saving ? 'Salvando...' : (editingGroup ? 'Salvar' : 'Criar')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

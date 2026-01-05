import { useCallback, useState } from 'react';
import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';
import { GripVertical, Plus, Pencil, Trash2 } from 'lucide-react';
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
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

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

interface SortableGroupButtonProps {
  group: {
    id: string;
    name: string;
    icon?: string;
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
        isDragMode && "cursor-grab active:cursor-grabbing ring-2 ring-primary/20 hover:ring-primary/40",
        isDragging && "opacity-90 ring-2 ring-primary"
      )}
      style={style}
      {...(isDragMode ? { ...attributes, ...listeners } : {})}
    >
      {isDragMode && <GripVertical className="h-3 w-3 opacity-50" />}
      <DynamicIcon icon={group.icon} fallback="📁" className="h-4 w-4" />
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
  
  // Estados para diálogos
  const [isGroupDialogOpen, setIsGroupDialogOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<{ id: string; name: string; icon?: string; color?: string } | null>(null);
  const [groupName, setGroupName] = useState('');
  const [groupIcon, setGroupIcon] = useState('folder');
  const [groupColor, setGroupColor] = useState('#6366f1');
  const [saving, setSaving] = useState(false);
  const [deleteGroupId, setDeleteGroupId] = useState<string | null>(null);

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

  const handleDeleteGroup = useCallback(async () => {
    if (!deleteGroupId || !user) return;
    
    try {
      const { error } = await supabase
        .from('tab_groups')
        .delete()
        .eq('id', deleteGroupId)
        .eq('user_id', user.id);
      
      if (error) throw error;
      toast.success('Grupo excluído!');
      context?.refreshData();
    } catch (error: any) {
      toast.error(error.message || 'Erro ao excluir grupo');
    } finally {
      setDeleteGroupId(null);
    }
  }, [deleteGroupId, user, context]);

  if (!context || context.loading) {
    return null;
  }

  const { groups, activeGroup, setActiveGroup, isDragMode } = context;

  return (
    <>
      <div className="flex items-center gap-2">
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
          <SortableContext 
            items={groups.map(g => g.id)} 
            strategy={horizontalListSortingStrategy}
          >
            {groups.map(group => (
              <SortableGroupButton
                key={group.id}
                group={group}
                isActive={activeGroup?.id === group.id}
                isDragMode={isDragMode}
                onSelect={() => {
                  setActiveGroup(group);
                  navigate('/browser');
                }}
                onEdit={() => openEditGroupDialog(group)}
                onDelete={() => setDeleteGroupId(group.id)}
              />
            ))}
          </SortableContext>
        </DndContext>
        
        {/* Botão para criar novo grupo */}
        <Button
          variant="ghost"
          size="sm"
          className="rounded-full h-8 w-8 p-0"
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
              <Select value={groupIcon} onValueChange={setGroupIcon}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {iconOptions.map(opt => (
                    <SelectItem key={opt.value} value={opt.value}>
                      <div className="flex items-center gap-2">
                        <DynamicIcon icon={opt.value} className="h-4 w-4" />
                        {opt.label}
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
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

      {/* Dialog de confirmação para excluir grupo */}
      <AlertDialog open={!!deleteGroupId} onOpenChange={(open) => !open && setDeleteGroupId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir grupo?</AlertDialogTitle>
            <AlertDialogDescription>
              Isso irá excluir o grupo e todas as abas dentro dele. Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleDeleteGroup} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

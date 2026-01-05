import { useCallback } from 'react';
import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { toast } from 'sonner';
import { GripVertical } from 'lucide-react';
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

interface SortableGroupButtonProps {
  group: {
    id: string;
    name: string;
    icon?: string;
  };
  isActive: boolean;
  isDragMode: boolean;
  onSelect: () => void;
}

function SortableGroupButton({ group, isActive, isDragMode, onSelect }: SortableGroupButtonProps) {
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

  return (
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
}

export function GroupSelector() {
  const context = useBrowser();
  const navigate = useNavigate();
  const { user } = useAuth();

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
      // Em caso de erro, recarregar do banco
      context.refreshData();
    }
  }, [context, user]);

  if (!context || context.loading || context.groups.length === 0) {
    return null;
  }

  const { groups, activeGroup, setActiveGroup, isDragMode } = context;

  return (
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
            />
          ))}
        </SortableContext>
      </DndContext>
    </div>
  );
}

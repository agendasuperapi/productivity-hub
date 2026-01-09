import { useState } from 'react';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Button } from '@/components/ui/button';
import { GripVertical, LayoutGrid, ExternalLink, Pencil, Trash2 } from 'lucide-react';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { cn } from '@/lib/utils';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
} from '@/components/ui/context-menu';
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

interface TabUrl {
  url: string;
  shortcut_enabled: boolean;
  zoom?: number;
}

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

interface SortableTabProps {
  tab: Tab;
  groupId: string;
  onEdit: (tab: Tab, groupId: string) => void;
  onDelete: (tabId: string) => void;
}

export function SortableTab({ tab, groupId, onEdit, onDelete }: SortableTabProps) {
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: tab.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  const handleDelete = () => {
    onDelete(tab.id);
    setShowDeleteDialog(false);
  };

  return (
    <>
      <ContextMenu>
        <ContextMenuTrigger asChild>
          <div
            ref={setNodeRef}
            style={style}
            className={cn(
              "flex items-center gap-3 p-3 pl-6 hover:bg-secondary/30 transition-colors group",
              isDragging && "opacity-50 bg-secondary/50 z-50"
            )}
          >
            <div 
              {...attributes} 
              {...listeners}
              className="cursor-grab active:cursor-grabbing touch-none"
            >
              <GripVertical className="h-4 w-4 text-muted-foreground/50 hover:text-muted-foreground" />
            </div>
            <div 
              className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ backgroundColor: `${tab.color}20` }}
            >
              <DynamicIcon 
                icon={tab.icon || 'globe'} 
                className="h-4 w-4" 
                style={{ color: tab.color }}
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p className="font-medium truncate">{tab.name}</p>
                {tab.urls && tab.urls.length > 1 && (
                  <span className="flex items-center gap-1 text-xs px-1.5 py-0.5 rounded bg-primary/10 text-primary">
                    <LayoutGrid className="h-3 w-3" />
                    {tab.urls.length}
                  </span>
                )}
              </div>
              <p className="text-xs text-muted-foreground truncate">
                {tab.urls && tab.urls.length > 1 
                  ? `${tab.urls.length} URLs - ${tab.layout_type}` 
                  : tab.url}
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
                onClick={() => onEdit(tab, groupId)}
              >
                <Pencil className="h-3 w-3" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8 text-destructive hover:text-destructive"
                onClick={() => setShowDeleteDialog(true)}
              >
                <Trash2 className="h-3 w-3" />
              </Button>
            </div>
          </div>
        </ContextMenuTrigger>
        <ContextMenuContent className="w-48">
          <ContextMenuItem onClick={() => onEdit(tab, groupId)} className="gap-2">
            <Pencil className="h-4 w-4" />
            Editar
          </ContextMenuItem>
          <ContextMenuItem 
            onClick={() => setShowDeleteDialog(true)} 
            className="gap-2 text-destructive focus:text-destructive"
          >
            <Trash2 className="h-4 w-4" />
            Excluir
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>

      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir aba</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir a aba "{tab.name}"? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

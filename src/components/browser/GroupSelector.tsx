import { useBrowser } from '@/contexts/BrowserContext';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

export function GroupSelector() {
  const { groups, activeGroup, setActiveGroup, loading } = useBrowser();

  if (loading || groups.length === 0) {
    return null;
  }

  const handleGroupChange = (groupId: string) => {
    const group = groups.find(g => g.id === groupId);
    if (group) {
      setActiveGroup(group);
    }
  };

  return (
    <div className="flex items-center gap-2">
      <Select value={activeGroup?.id || ''} onValueChange={handleGroupChange}>
        <SelectTrigger className="w-[200px] border-0 bg-transparent font-medium text-base gap-2">
          {activeGroup && (
            <span className="text-lg">{activeGroup.icon || '📁'}</span>
          )}
          <SelectValue placeholder="Selecione um grupo" />
        </SelectTrigger>
        <SelectContent>
          {groups.map(group => (
            <SelectItem key={group.id} value={group.id}>
              <div className="flex items-center gap-2">
                <span>{group.icon || '📁'}</span>
                <span>{group.name}</span>
                <span className="text-xs text-muted-foreground ml-1">
                  ({group.tabs.length})
                </span>
              </div>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}

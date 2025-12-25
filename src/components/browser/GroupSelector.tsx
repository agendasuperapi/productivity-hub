import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';

export function GroupSelector() {
  const context = useBrowser();

  if (!context || context.loading || context.groups.length === 0) {
    return null;
  }

  const { groups, activeGroup, setActiveGroup } = context;

  return (
    <div className="flex items-center gap-2">
      {groups.map(group => (
        <Button
          key={group.id}
          variant={activeGroup?.id === group.id ? "default" : "ghost"}
          size="sm"
          onClick={() => setActiveGroup(group)}
          className="rounded-full px-3 gap-2 h-8"
        >
          <span>{group.icon || '📁'}</span>
          <span className="hidden sm:inline">{group.name}</span>
        </Button>
      ))}
    </div>
  );
}

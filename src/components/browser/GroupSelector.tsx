import { useBrowser } from '@/contexts/BrowserContext';
import { Button } from '@/components/ui/button';
import { DynamicIcon } from '@/components/ui/dynamic-icon';

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
          <DynamicIcon icon={group.icon} fallback="📁" className="h-4 w-4" />
          <span className="hidden sm:inline">{group.name}</span>
        </Button>
      ))}
    </div>
  );
}

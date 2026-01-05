import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
import { ScrollArea } from '@/components/ui/scroll-area';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { iconOptions } from '@/lib/iconOptions';
import { Search, Check } from 'lucide-react';
import { cn } from '@/lib/utils';

interface IconSelectProps {
  value: string;
  onValueChange: (value: string) => void;
  color?: string;
  className?: string;
}

export function IconSelect({ value, onValueChange, color, className }: IconSelectProps) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');

  const filteredIcons = useMemo(() => {
    if (!search.trim()) return iconOptions;
    const searchLower = search.toLowerCase();
    return iconOptions.filter(
      opt => opt.label.toLowerCase().includes(searchLower) || opt.value.toLowerCase().includes(searchLower)
    );
  }, [search]);

  const selectedIcon = iconOptions.find(opt => opt.value === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className={cn("w-14 h-10 p-0 justify-center", className)}
          style={{ color }}
        >
          <DynamicIcon icon={value} className="h-4 w-4" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-72 p-0" align="start">
        <div className="p-2 border-b">
          <div className="relative">
            <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Buscar ícone..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-8 h-9"
            />
          </div>
        </div>
        <ScrollArea className="h-[280px]">
          <div className="grid grid-cols-6 gap-1 p-2">
            {filteredIcons.map(opt => (
              <Button
                key={opt.value}
                variant="ghost"
                size="sm"
                className={cn(
                  "h-9 w-9 p-0 relative",
                  value === opt.value && "bg-primary/10 text-primary"
                )}
                onClick={() => {
                  onValueChange(opt.value);
                  setOpen(false);
                  setSearch('');
                }}
                title={opt.label}
              >
                <DynamicIcon icon={opt.value} className="h-4 w-4" />
                {value === opt.value && (
                  <Check className="absolute bottom-0 right-0 h-3 w-3 text-primary" />
                )}
              </Button>
            ))}
          </div>
          {filteredIcons.length === 0 && (
            <div className="text-center text-muted-foreground py-6 text-sm">
              Nenhum ícone encontrado
            </div>
          )}
        </ScrollArea>
      </PopoverContent>
    </Popover>
  );
}

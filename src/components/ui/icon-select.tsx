import { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';

import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { iconOptions, isEmoji } from '@/lib/iconOptions';
import { Search, Check, Smile } from 'lucide-react';
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
  const [customEmoji, setCustomEmoji] = useState('');

  const filteredIcons = useMemo(() => {
    if (!search.trim()) return iconOptions;
    const searchLower = search.toLowerCase();
    return iconOptions.filter(
      opt => opt.label.toLowerCase().includes(searchLower) || opt.value.toLowerCase().includes(searchLower)
    );
  }, [search]);

  const isCurrentValueEmoji = isEmoji(value);

  const handleEmojiSubmit = () => {
    if (customEmoji.trim()) {
      onValueChange(customEmoji.trim());
      setOpen(false);
      setCustomEmoji('');
    }
  };

  const renderIcon = () => {
    if (isCurrentValueEmoji) {
      return <span className="text-lg">{value}</span>;
    }
    return <DynamicIcon icon={value} className="h-4 w-4" />;
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className={cn("w-14 h-10 p-0 justify-center", className)}
          style={{ color: isCurrentValueEmoji ? undefined : color }}
        >
          {renderIcon()}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="start">
        <Tabs defaultValue="icons" className="w-full">
          <TabsList className="w-full grid grid-cols-2 h-10 rounded-none border-b">
            <TabsTrigger value="icons" className="rounded-none data-[state=active]:shadow-none">
              <Search className="h-4 w-4 mr-2" />
              Ícones
            </TabsTrigger>
            <TabsTrigger value="emoji" className="rounded-none data-[state=active]:shadow-none">
              <Smile className="h-4 w-4 mr-2" />
              Emoji
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="icons" className="mt-0">
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
            <div className="h-[280px] overflow-y-auto">
              <div className="grid grid-cols-4 gap-1 p-2">
                {filteredIcons.map(opt => (
                  <Button
                    key={opt.value}
                    variant="ghost"
                    size="sm"
                    className={cn(
                      "h-auto py-2 px-2 flex flex-col items-center gap-1 relative",
                      value === opt.value && "bg-primary/10 text-primary"
                    )}
                    onClick={() => {
                      onValueChange(opt.value);
                      setOpen(false);
                      setSearch('');
                    }}
                    title={opt.label}
                  >
                    <DynamicIcon icon={opt.value} className="h-5 w-5" />
                    <span className="text-[10px] truncate w-full text-center text-muted-foreground">
                      {opt.label}
                    </span>
                    {value === opt.value && (
                      <Check className="absolute top-1 right-1 h-3 w-3 text-primary" />
                    )}
                  </Button>
                ))}
              </div>
              {filteredIcons.length === 0 && (
                <div className="text-center text-muted-foreground py-6 text-sm">
                  Nenhum ícone encontrado
                </div>
              )}
            </div>
          </TabsContent>
          
          <TabsContent value="emoji" className="mt-0 p-4">
            <div className="space-y-4">
              <div className="text-sm text-muted-foreground">
                Cole ou digite um emoji para usar como ícone:
              </div>
              <div className="flex gap-2">
                <Input
                  placeholder="🚀"
                  value={customEmoji}
                  onChange={(e) => setCustomEmoji(e.target.value)}
                  className="text-2xl text-center"
                  maxLength={4}
                />
                <Button onClick={handleEmojiSubmit} disabled={!customEmoji.trim()}>
                  Usar
                </Button>
              </div>
              <div className="text-xs text-muted-foreground">
                Dica: Use o teclado de emojis do sistema (Win + . no Windows, Ctrl + Cmd + Espaço no Mac)
              </div>
              
              <div className="border-t pt-4">
                <div className="text-sm font-medium mb-2">Emojis populares:</div>
                <div className="grid grid-cols-8 gap-1">
                  {['🚀', '⭐', '💡', '🔥', '💎', '🎯', '📌', '💼', '📊', '📈', '💰', '🛒', '📧', '💬', '🔔', '⚙️'].map(emoji => (
                    <Button
                      key={emoji}
                      variant="ghost"
                      size="sm"
                      className={cn(
                        "h-9 w-9 p-0 text-xl",
                        value === emoji && "bg-primary/10"
                      )}
                      onClick={() => {
                        onValueChange(emoji);
                        setOpen(false);
                      }}
                    >
                      {emoji}
                    </Button>
                  ))}
                </div>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </PopoverContent>
    </Popover>
  );
}

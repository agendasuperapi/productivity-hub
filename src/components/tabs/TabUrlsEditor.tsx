import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Plus, Trash2, Globe, Keyboard, ZoomIn, Link2 } from 'lucide-react';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

export interface TabUrl {
  url: string;
  shortcut_enabled: boolean;
  zoom?: number;
  session_group?: string;
}

interface TabUrlsEditorProps {
  urls: TabUrl[];
  onChange: (urls: TabUrl[]) => void;
  mainUrl: string;
  onMainUrlChange: (url: string) => void;
  mainShortcutEnabled: boolean;
  onMainShortcutEnabledChange: (enabled: boolean) => void;
  mainZoom: number;
  onMainZoomChange: (zoom: number) => void;
  mainSessionGroup: string;
  onMainSessionGroupChange: (group: string) => void;
  existingSessionGroups: string[];
}

export function TabUrlsEditor({ 
  urls, 
  onChange, 
  mainUrl, 
  onMainUrlChange,
  mainShortcutEnabled,
  onMainShortcutEnabledChange,
  mainZoom,
  onMainZoomChange,
  mainSessionGroup,
  onMainSessionGroupChange,
  existingSessionGroups
}: TabUrlsEditorProps) {
  const handleAddUrl = () => {
    onChange([...urls, { url: '', shortcut_enabled: false, zoom: 100, session_group: '' }]);
  };

  const handleRemoveUrl = (index: number) => {
    const newUrls = urls.filter((_, i) => i !== index);
    onChange(newUrls);
  };

  const handleUrlChange = (index: number, url: string) => {
    const newUrls = [...urls];
    newUrls[index] = { ...newUrls[index], url };
    onChange(newUrls);
  };

  const handleShortcutToggle = (index: number, checked: boolean) => {
    const newUrls = [...urls];
    newUrls[index] = { ...newUrls[index], shortcut_enabled: checked };
    onChange(newUrls);
  };

  const handleZoomChange = (index: number, zoom: number) => {
    const newUrls = [...urls];
    newUrls[index] = { ...newUrls[index], zoom };
    onChange(newUrls);
  };

  const handleSessionGroupChange = (index: number, group: string) => {
    const newUrls = [...urls];
    newUrls[index] = { ...newUrls[index], session_group: group === '__none__' ? '' : group };
    onChange(newUrls);
  };

  // Combinar grupos existentes com novos digitados
  const allGroups = [...new Set([
    ...existingSessionGroups,
    mainSessionGroup,
    ...urls.map(u => u.session_group || '').filter(g => g)
  ])].filter(g => g);

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <Label>URLs</Label>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={handleAddUrl}
          className="text-primary"
        >
          <Plus className="mr-1 h-3 w-3" />
          Adicionar
        </Button>
      </div>

      {/* URL Principal */}
      <div className="space-y-2">
        <div className="flex items-start gap-2">
          <div className="flex items-center justify-center w-8 h-8 rounded bg-secondary text-xs font-medium shrink-0 mt-1">
            <Globe className="h-4 w-4 text-muted-foreground" />
          </div>
          <Textarea
            placeholder="https://web.whatsapp.com"
            value={mainUrl}
            onChange={(e) => onMainUrlChange(e.target.value)}
            className="flex-1 min-h-[40px] resize-none overflow-hidden"
            rows={1}
            onInput={(e) => {
              const target = e.target as HTMLTextAreaElement;
              target.style.height = 'auto';
              target.style.height = `${target.scrollHeight}px`;
            }}
          />
        </div>
      </div>

      {/* URLs adicionais */}
      {urls.map((item, index) => (
        <div key={index} className="flex items-start gap-2">
          <div className="flex items-center justify-center w-8 h-8 rounded bg-secondary text-xs font-medium text-muted-foreground shrink-0 mt-1">
            {index + 2}
          </div>
          <Textarea
            placeholder={`https://exemplo.com`}
            value={item.url}
            onChange={(e) => handleUrlChange(index, e.target.value)}
            className="flex-1 min-h-[40px] resize-none overflow-hidden"
            rows={1}
            onInput={(e) => {
              const target = e.target as HTMLTextAreaElement;
              target.style.height = 'auto';
              target.style.height = `${target.scrollHeight}px`;
            }}
          />
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="text-destructive hover:text-destructive h-8 w-8 shrink-0 mt-1"
            onClick={() => handleRemoveUrl(index)}
          >
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      ))}

      {/* Grupo de Sessão por URL */}
      <div className="mt-4 p-3 rounded-lg border border-border bg-secondary/30">
        <div className="flex items-center gap-2 mb-3">
          <Link2 className="h-4 w-4 text-muted-foreground" />
          <span className="text-sm font-medium">Grupo de Sessão por URL</span>
        </div>
        <p className="text-xs text-muted-foreground mb-3">
          URLs com o mesmo grupo compartilham cookies e login
        </p>
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <span className="text-sm font-medium w-16">URL 1</span>
            <Select 
              value={mainSessionGroup || '__none__'} 
              onValueChange={(v) => onMainSessionGroupChange(v === '__none__' ? '' : v)}
            >
              <SelectTrigger className="w-48">
                <SelectValue placeholder="Nenhum (isolado)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">Nenhum (isolado)</SelectItem>
                {allGroups.map(group => (
                  <SelectItem key={group} value={group}>{group}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Input
              placeholder="Novo grupo..."
              className="w-32"
              value={mainSessionGroup}
              onChange={(e) => onMainSessionGroupChange(e.target.value)}
            />
          </div>
          {urls.map((item, index) => (
            <div key={index} className="flex items-center gap-3">
              <span className="text-sm font-medium w-16">URL {index + 2}</span>
              <Select 
                value={item.session_group || '__none__'} 
                onValueChange={(v) => handleSessionGroupChange(index, v)}
              >
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Nenhum (isolado)" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">Nenhum (isolado)</SelectItem>
                  {allGroups.map(group => (
                    <SelectItem key={group} value={group}>{group}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Input
                placeholder="Novo grupo..."
                className="w-32"
                value={item.session_group || ''}
                onChange={(e) => handleSessionGroupChange(index, e.target.value)}
              />
            </div>
          ))}
        </div>
      </div>

      {/* Atalhos rápidos por página */}
      <div className="mt-4 p-3 rounded-lg border border-border bg-secondary/30">
        <div className="flex items-center gap-2 mb-3">
          <Keyboard className="h-4 w-4 text-muted-foreground" />
          <span className="text-sm font-medium">Atalhos rápidos por página</span>
        </div>
        <p className="text-xs text-muted-foreground mb-3">
          Configure se cada página/URL deve aceitar atalhos rápidos (ex: /x32)
        </p>
        <div className="space-y-2">
          <div className="flex items-center gap-3">
            <Checkbox 
              id="shortcut-main" 
              checked={mainShortcutEnabled}
              onCheckedChange={(checked) => onMainShortcutEnabledChange(checked as boolean)}
            />
            <label htmlFor="shortcut-main" className="text-sm flex-1 min-w-0">
              <span className="font-medium">URL 1</span>
              <span className="text-muted-foreground ml-2 text-xs break-all">
                {mainUrl || 'URL principal'}
              </span>
            </label>
          </div>
          {urls.map((item, index) => (
            <div key={index} className="flex items-center gap-3">
              <Checkbox 
                id={`shortcut-${index}`}
                checked={item.shortcut_enabled}
                onCheckedChange={(checked) => handleShortcutToggle(index, checked as boolean)}
              />
              <label htmlFor={`shortcut-${index}`} className="text-sm flex-1 min-w-0">
                <span className="font-medium">URL {index + 2}</span>
                <span className="text-muted-foreground ml-2 text-xs break-all">
                  {item.url || 'URL adicional'}
                </span>
              </label>
            </div>
          ))}
        </div>
      </div>

      {/* Zoom por página */}
      <div className="mt-4 p-3 rounded-lg border border-border bg-secondary/30">
        <div className="flex items-center gap-2 mb-3">
          <ZoomIn className="h-4 w-4 text-muted-foreground" />
          <span className="text-sm font-medium">Zoom por página (%)</span>
        </div>
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <span className="text-sm font-medium w-16">URL 1</span>
            <Input
              type="number"
              min={25}
              max={500}
              value={mainZoom}
              onChange={(e) => onMainZoomChange(parseInt(e.target.value) || 100)}
              className="w-20"
            />
            <span className="text-xs text-muted-foreground break-all flex-1 min-w-0">
              {mainUrl || 'URL principal'}
            </span>
          </div>
          {urls.map((item, index) => (
            <div key={index} className="flex items-center gap-3">
              <span className="text-sm font-medium w-16">URL {index + 2}</span>
              <Input
                type="number"
                min={25}
                max={500}
                value={item.zoom ?? 100}
                onChange={(e) => handleZoomChange(index, parseInt(e.target.value) || 100)}
                className="w-20"
              />
              <span className="text-xs text-muted-foreground break-all flex-1 min-w-0">
                {item.url || 'URL adicional'}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
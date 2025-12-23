import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Plus, Trash2, Globe, Keyboard } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface TabUrl {
  url: string;
  shortcut_enabled: boolean;
}

interface TabUrlsEditorProps {
  urls: TabUrl[];
  onChange: (urls: TabUrl[]) => void;
  mainUrl: string;
  onMainUrlChange: (url: string) => void;
}

export function TabUrlsEditor({ urls, onChange, mainUrl, onMainUrlChange }: TabUrlsEditorProps) {
  const handleAddUrl = () => {
    onChange([...urls, { url: '', shortcut_enabled: false }]);
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

  // Converter para formato com URLs (main + extras)
  const allUrls: TabUrl[] = [
    { url: mainUrl, shortcut_enabled: true },
    ...urls
  ];

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
        <div className="flex items-center gap-2">
          <div className="flex items-center justify-center w-8 h-8 rounded bg-secondary text-xs font-medium">
            <Globe className="h-4 w-4 text-muted-foreground" />
          </div>
          <Input
            placeholder="https://web.whatsapp.com"
            value={mainUrl}
            onChange={(e) => onMainUrlChange(e.target.value)}
            className="flex-1"
          />
        </div>
      </div>

      {/* URLs adicionais */}
      {urls.map((item, index) => (
        <div key={index} className="flex items-center gap-2">
          <div className="flex items-center justify-center w-8 h-8 rounded bg-secondary text-xs font-medium text-muted-foreground">
            {index + 2}
          </div>
          <Input
            placeholder={`https://exemplo.com`}
            value={item.url}
            onChange={(e) => handleUrlChange(index, e.target.value)}
            className="flex-1"
          />
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="text-destructive hover:text-destructive h-8 w-8"
            onClick={() => handleRemoveUrl(index)}
          >
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      ))}

      {/* Atalhos rápidos por página (só mostra se tiver mais de 1 URL) */}
      {urls.length > 0 && (
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
                checked={true}
                disabled
              />
              <label htmlFor="shortcut-main" className="text-sm flex-1">
                <span className="font-medium">URL 1</span>
                <span className="text-muted-foreground ml-2 text-xs truncate">
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
                <label htmlFor={`shortcut-${index}`} className="text-sm flex-1">
                  <span className="font-medium">URL {index + 2}</span>
                  <span className="text-muted-foreground ml-2 text-xs truncate">
                    {item.url || 'URL adicional'}
                  </span>
                </label>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

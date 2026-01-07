import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import { Settings2, Monitor, RotateCcw } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';
import { useLocalSettings, LocalSettings } from '@/hooks/useLocalSettings';
import { toast } from 'sonner';

interface InterfaceSettingsProps {
  settings: UserSettings['interface'];
  onUpdate: (updates: Partial<UserSettings['interface']>) => void;
}

const densityOptions = [
  { value: 'compact', label: 'Compacta', description: 'Menos espaço entre elementos' },
  { value: 'normal', label: 'Normal', description: 'Espaçamento padrão' },
  { value: 'comfortable', label: 'Confortável', description: 'Mais espaço entre elementos' },
];

export function InterfaceSettings({ settings, onUpdate }: InterfaceSettingsProps) {
  const { settings: localSettings, updateSettings: updateLocalSettings, resetSettings, defaultSettings } = useLocalSettings();

  const handleLocalSettingChange = (updates: Partial<LocalSettings>) => {
    updateLocalSettings(updates);
    toast.success('Configuração salva neste dispositivo');
  };

  const handleResetLocalSettings = () => {
    resetSettings();
    toast.success('Configurações locais restauradas para o padrão');
  };

  const isDefaultSettings = 
    localSettings.shortcuts_bar_mode === defaultSettings.shortcuts_bar_mode &&
    localSettings.shortcuts_bar_position === defaultSettings.shortcuts_bar_position;

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings2 className="h-5 w-5" />
            Interface
          </CardTitle>
          <CardDescription>
            Personalize a aparência e comportamento da interface
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* UI Density */}
          <div className="space-y-2">
            <Label htmlFor="density">Densidade da interface</Label>
            <Select
              value={settings.density}
              onValueChange={(value) => onUpdate({ density: value as UserSettings['interface']['density'] })}
            >
              <SelectTrigger id="density">
                <SelectValue placeholder="Selecione a densidade" />
              </SelectTrigger>
              <SelectContent>
                {densityOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    <div className="flex flex-col">
                      <span>{option.label}</span>
                      <span className="text-xs text-muted-foreground">{option.description}</span>
                    </div>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Animations */}
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="animations">Animações</Label>
              <p className="text-xs text-muted-foreground">
                Habilitar animações e transições na interface
              </p>
            </div>
            <Switch
              id="animations"
              checked={settings.animations_enabled}
              onCheckedChange={(checked) => onUpdate({ animations_enabled: checked })}
            />
          </div>

          {/* Sidebar Collapsed */}
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="sidebar_collapsed">Sidebar colapsada por padrão</Label>
              <p className="text-xs text-muted-foreground">
                Iniciar com a barra lateral recolhida
              </p>
            </div>
            <Switch
              id="sidebar_collapsed"
              checked={settings.sidebar_collapsed}
              onCheckedChange={(checked) => onUpdate({ sidebar_collapsed: checked })}
            />
          </div>
        </CardContent>
      </Card>

      {/* Local Device Settings Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Monitor className="h-5 w-5" />
            Configurações deste dispositivo
          </CardTitle>
          <CardDescription>
            Estas configurações são salvas apenas neste dispositivo
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Shortcuts Bar Mode */}
          <div className="space-y-2">
            <Label htmlFor="shortcuts_bar_mode">Modo da barra de atalhos</Label>
            <Select
              value={localSettings.shortcuts_bar_mode}
              onValueChange={(value) => handleLocalSettingChange({ shortcuts_bar_mode: value as LocalSettings['shortcuts_bar_mode'] })}
            >
              <SelectTrigger id="shortcuts_bar_mode">
                <SelectValue placeholder="Selecione o modo" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="fixed">
                  <div className="flex flex-col">
                    <span>Fixa</span>
                    <span className="text-xs text-muted-foreground">Barra sempre visível na lateral</span>
                  </div>
                </SelectItem>
                <SelectItem value="floating">
                  <div className="flex flex-col">
                    <span>Flutuante</span>
                    <span className="text-xs text-muted-foreground">Abre em drawer ao clicar no botão</span>
                  </div>
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Shortcuts Bar Position */}
          <div className="space-y-2">
            <Label htmlFor="shortcuts_bar_position">Posição da barra de atalhos</Label>
            <Select
              value={localSettings.shortcuts_bar_position}
              onValueChange={(value) => handleLocalSettingChange({ shortcuts_bar_position: value as LocalSettings['shortcuts_bar_position'] })}
            >
              <SelectTrigger id="shortcuts_bar_position">
                <SelectValue placeholder="Selecione a posição" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="bottom">Inferior</SelectItem>
                <SelectItem value="left">Esquerda</SelectItem>
                <SelectItem value="right">Direita</SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              Onde a barra de atalhos rápidos aparece no navegador
            </p>
          </div>

          {/* Reset Button */}
          <div className="pt-2 border-t">
            <Button
              variant="outline"
              size="sm"
              onClick={handleResetLocalSettings}
              disabled={isDefaultSettings}
              className="gap-2"
            >
              <RotateCcw className="h-4 w-4" />
              Restaurar padrão
            </Button>
            <p className="text-xs text-muted-foreground mt-2">
              Restaura as configurações deste dispositivo para os valores padrão
            </p>
          </div>
        </CardContent>
      </Card>
    </>
  );
}

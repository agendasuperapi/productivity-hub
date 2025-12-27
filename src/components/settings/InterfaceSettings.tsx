import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Settings2 } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';

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
  return (
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
  );
}

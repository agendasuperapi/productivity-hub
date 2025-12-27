import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Bell } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';

interface NotificationSettingsProps {
  settings: UserSettings['notifications'];
  onUpdate: (updates: Partial<UserSettings['notifications']>) => void;
}

const toastPositionOptions = [
  { value: 'top-left', label: 'Superior esquerdo' },
  { value: 'top-center', label: 'Superior central' },
  { value: 'top-right', label: 'Superior direito' },
  { value: 'bottom-left', label: 'Inferior esquerdo' },
  { value: 'bottom-center', label: 'Inferior central' },
  { value: 'bottom-right', label: 'Inferior direito' },
];

export function NotificationSettings({ settings, onUpdate }: NotificationSettingsProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Bell className="h-5 w-5" />
          Notificações
        </CardTitle>
        <CardDescription>
          Configure alertas e notificações do aplicativo
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Sound Notifications */}
        <div className="flex items-center justify-between">
          <div className="space-y-0.5">
            <Label htmlFor="sound_enabled">Notificações sonoras</Label>
            <p className="text-xs text-muted-foreground">
              Tocar som ao receber notificações
            </p>
          </div>
          <Switch
            id="sound_enabled"
            checked={settings.sound_enabled}
            onCheckedChange={(checked) => onUpdate({ sound_enabled: checked })}
          />
        </div>

        {/* Toast Position */}
        <div className="space-y-2">
          <Label htmlFor="toast_position">Posição das notificações</Label>
          <Select
            value={settings.toast_position}
            onValueChange={(value) => onUpdate({ toast_position: value as UserSettings['notifications']['toast_position'] })}
          >
            <SelectTrigger id="toast_position">
              <SelectValue placeholder="Selecione a posição" />
            </SelectTrigger>
            <SelectContent>
              {toastPositionOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <p className="text-xs text-muted-foreground">
            Escolha onde as notificações aparecem na tela
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

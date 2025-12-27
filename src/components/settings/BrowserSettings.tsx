import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Monitor } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';

interface BrowserSettingsProps {
  settings: UserSettings['browser'];
  onUpdate: (updates: Partial<UserSettings['browser']>) => void;
}

export function BrowserSettings({ settings, onUpdate }: BrowserSettingsProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Monitor className="h-5 w-5" />
          Navegador
        </CardTitle>
        <CardDescription>
          Configure o comportamento das janelas flutuantes
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Auto Restore Session */}
        <div className="flex items-center justify-between">
          <div className="space-y-0.5">
            <Label htmlFor="auto_restore">Auto-restaurar sessão</Label>
            <p className="text-xs text-muted-foreground">
              Restaurar automaticamente janelas flutuantes ao iniciar
            </p>
          </div>
          <Switch
            id="auto_restore"
            checked={settings.auto_restore_session}
            onCheckedChange={(checked) => onUpdate({ auto_restore_session: checked })}
          />
        </div>

        {/* Save Window Positions */}
        <div className="flex items-center justify-between">
          <div className="space-y-0.5">
            <Label htmlFor="save_positions">Salvar posição das janelas</Label>
            <p className="text-xs text-muted-foreground">
              Lembrar posição e tamanho das janelas flutuantes no monitor
            </p>
          </div>
          <Switch
            id="save_positions"
            checked={settings.save_window_positions}
            onCheckedChange={(checked) => onUpdate({ save_window_positions: checked })}
          />
        </div>

        {/* Confirm on Close */}
        <div className="flex items-center justify-between">
          <div className="space-y-0.5">
            <Label htmlFor="confirm_close">Confirmação ao fechar</Label>
            <p className="text-xs text-muted-foreground">
              Mostrar popup de confirmação ao fechar com janelas abertas
            </p>
          </div>
          <Switch
            id="confirm_close"
            checked={settings.confirm_on_close}
            onCheckedChange={(checked) => onUpdate({ confirm_on_close: checked })}
          />
        </div>
      </CardContent>
    </Card>
  );
}

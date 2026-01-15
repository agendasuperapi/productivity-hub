import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Slider } from '@/components/ui/slider';
import { Keyboard, AlertCircle, Zap, Clock, Monitor } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';
import { useLocalSettings } from '@/hooks/useLocalSettings';
import { Badge } from '@/components/ui/badge';

interface ShortcutSettingsProps {
  settings: UserSettings['shortcuts'];
  onUpdate: (updates: Partial<UserSettings['shortcuts']>) => void;
}

export function ShortcutSettings({ settings, onUpdate }: ShortcutSettingsProps) {
  const [keyError, setKeyError] = useState<string | null>(null);
  const { settings: localSettings, updateSettings: updateLocalSettings } = useLocalSettings();

  const handleActivationKeyChange = (value: string) => {
    // Limitar a 3 caracteres
    if (value.length > 3) {
      setKeyError('A tecla de ativação deve ter no máximo 3 caracteres');
      return;
    }

    setKeyError(null);
    // Salvar localmente ao invés do banco de dados
    updateLocalSettings({ activation_key: value });
  };

  const handleActivationTimeChange = (value: number[]) => {
    onUpdate({ activationTime: value[0] });
  };

  const activationKey = localSettings.activation_key || '/';

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Keyboard className="h-5 w-5" />
          Atalhos de Texto
        </CardTitle>
        <CardDescription>
          Configure como os atalhos de texto são ativados
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Activation Key */}
        <div className="space-y-2">
          <Label htmlFor="activationKey" className="flex items-center gap-2">
            <Zap className="h-4 w-4 text-primary" />
            Tecla de Ativação
            <Badge variant="outline" className="ml-2 text-xs">
              <Monitor className="h-3 w-3 mr-1" />
              Local
            </Badge>
          </Label>
          <div className="flex items-center gap-3">
            <Input
              id="activationKey"
              value={activationKey}
              onChange={(e) => handleActivationKeyChange(e.target.value)}
              className="w-20 text-center text-lg font-mono"
              maxLength={3}
              placeholder="/"
            />
            <span className="text-sm text-muted-foreground">
              Digite <Badge variant="outline" className="font-mono mx-1">{activationKey}</Badge> para ativar os atalhos
            </span>
          </div>
          {keyError && (
            <p className="text-xs text-destructive flex items-center gap-1">
              <AlertCircle className="h-3 w-3" />
              {keyError}
            </p>
          )}
          <p className="text-xs text-muted-foreground">
            Esta configuração é salva localmente neste dispositivo. 
            Cada dispositivo pode ter uma tecla diferente.
          </p>
          <p className="text-xs text-muted-foreground">
            Comum: <code className="bg-muted px-1 rounded">/</code>, <code className="bg-muted px-1 rounded">!</code>, <code className="bg-muted px-1 rounded">#</code>
          </p>
        </div>

        {/* Activation Time */}
        <div className="space-y-3">
          <Label htmlFor="activationTime" className="flex items-center gap-2">
            <Clock className="h-4 w-4 text-primary" />
            Tempo de Ativação
          </Label>
          <div className="flex items-center gap-4">
            <Slider
              id="activationTime"
              value={[settings.activationTime]}
              onValueChange={handleActivationTimeChange}
              min={3}
              max={30}
              step={1}
              className="flex-1"
            />
            <Badge variant="secondary" className="min-w-[50px] text-center font-mono">
              {settings.activationTime}s
            </Badge>
          </div>
          <p className="text-xs text-muted-foreground">
            Após digitar a tecla de ativação, os atalhos ficam ativos por este tempo.
          </p>
        </div>

        {/* Usage Example */}
        <div className="p-4 bg-muted/50 rounded-lg border">
          <p className="text-sm font-medium mb-2">Como usar:</p>
          <ol className="text-xs text-muted-foreground space-y-1 list-decimal list-inside">
            <li>Digite <Badge variant="outline" className="font-mono text-xs">{activationKey}</Badge> para ativar o modo de atalhos</li>
            <li>Um indicador com contador aparecerá ({settings.activationTime}s)</li>
            <li>Digite seu atalho (ex: <code className="bg-background px-1 rounded">ola</code>)</li>
            <li>O atalho será expandido automaticamente</li>
          </ol>
        </div>
      </CardContent>
    </Card>
  );
}

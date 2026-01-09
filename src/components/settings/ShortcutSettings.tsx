import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Keyboard, AlertCircle, Zap } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';
import { Badge } from '@/components/ui/badge';

interface ShortcutSettingsProps {
  settings: UserSettings['shortcuts'];
  onUpdate: (updates: Partial<UserSettings['shortcuts']>) => void;
}

const ACTIVATION_KEYS = [
  { value: 'Control', label: 'Ctrl', description: 'Tecla Control' },
  { value: 'Alt', label: 'Alt', description: 'Tecla Alt' },
  { value: 'Shift', label: 'Shift', description: 'Tecla Shift' },
  { value: 'Meta', label: 'Win/Cmd', description: 'Tecla Windows ou Command' },
];

export function ShortcutSettings({ settings, onUpdate }: ShortcutSettingsProps) {
  const [prefixError, setPrefixError] = useState<string | null>(null);

  const handlePrefixChange = (value: string) => {
    // Validate prefix
    if (value.length === 0) {
      setPrefixError('O prefixo não pode estar vazio');
      return;
    }
    
    if (value.length > 3) {
      setPrefixError('O prefixo deve ter no máximo 3 caracteres');
      return;
    }

    // Check for invalid characters
    const invalidChars = /[a-zA-Z0-9]/;
    if (invalidChars.test(value)) {
      setPrefixError('Use apenas caracteres especiais (/, !, @, #, etc.)');
      return;
    }

    setPrefixError(null);
    onUpdate({ prefix: value });
  };

  const handleActivationKeyChange = (value: string) => {
    onUpdate({ activationKey: value });
  };

  const selectedKey = ACTIVATION_KEYS.find(k => k.value === settings.activationKey) || ACTIVATION_KEYS[0];

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
          </Label>
          <div className="flex items-center gap-3">
            <Select value={settings.activationKey} onValueChange={handleActivationKeyChange}>
              <SelectTrigger className="w-40">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ACTIVATION_KEYS.map(key => (
                  <SelectItem key={key.value} value={key.value}>
                    <span className="flex items-center gap-2">
                      <Badge variant="secondary" className="font-mono text-xs">
                        {key.label}
                      </Badge>
                      <span className="text-muted-foreground text-xs">{key.description}</span>
                    </span>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <span className="text-sm text-muted-foreground">
              Pressione <Badge variant="outline" className="font-mono mx-1">{selectedKey.label}</Badge> para ativar os atalhos
            </span>
          </div>
          <p className="text-xs text-muted-foreground">
            Você precisa pressionar esta tecla antes de digitar um atalho. Os atalhos ficam ativos por 5 segundos após pressionar a tecla.
          </p>
        </div>

        {/* Shortcut Prefix */}
        <div className="space-y-2">
          <Label htmlFor="prefix">Prefixo de atalho</Label>
          <div className="flex items-center gap-2">
            <Input
              id="prefix"
              value={settings.prefix}
              onChange={(e) => handlePrefixChange(e.target.value)}
              className="w-20 text-center text-lg font-mono"
              maxLength={3}
            />
            <span className="text-sm text-muted-foreground">
              + comando (ex: <code className="bg-muted px-1 rounded">{settings.prefix}ola</code>)
            </span>
          </div>
          {prefixError && (
            <p className="text-xs text-destructive flex items-center gap-1">
              <AlertCircle className="h-3 w-3" />
              {prefixError}
            </p>
          )}
          <p className="text-xs text-muted-foreground">
            Caractere(s) que você digita antes do comando para ativar um atalho. 
            Comum: <code className="bg-muted px-1 rounded">/</code>, <code className="bg-muted px-1 rounded">!</code>, <code className="bg-muted px-1 rounded">#</code>
          </p>
        </div>

        {/* Usage Example */}
        <div className="p-4 bg-muted/50 rounded-lg border">
          <p className="text-sm font-medium mb-2">Como usar:</p>
          <ol className="text-xs text-muted-foreground space-y-1 list-decimal list-inside">
            <li>Pressione <Badge variant="outline" className="font-mono text-xs">{selectedKey.label}</Badge> para ativar o modo de atalhos</li>
            <li>Um indicador verde aparecerá confirmando a ativação</li>
            <li>Digite seu atalho (ex: <code className="bg-background px-1 rounded">{settings.prefix}ola</code>)</li>
            <li>O atalho será expandido automaticamente</li>
          </ol>
        </div>
      </CardContent>
    </Card>
  );
}

import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Keyboard, AlertCircle } from 'lucide-react';
import { UserSettings } from '@/hooks/useUserSettings';

interface ShortcutSettingsProps {
  settings: UserSettings['shortcuts'];
  onUpdate: (updates: Partial<UserSettings['shortcuts']>) => void;
}

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
      </CardContent>
    </Card>
  );
}

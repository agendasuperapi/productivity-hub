import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { FlaskConical, ExternalLink, Keyboard } from 'lucide-react';
import { useLocalSettings } from '@/hooks/useLocalSettings';
import { ShortcutTestDialog } from './ShortcutTestDialog';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface Shortcut {
  id: string;
  command: string;
  expanded_text: string;
  messages?: ShortcutMessage[];
}

interface Keyword {
  key: string;
  value: string;
}

interface ShortcutTestPanelProps {
  shortcuts: Shortcut[];
  keywords: Keyword[];
}

export function ShortcutTestPanel({ shortcuts, keywords }: ShortcutTestPanelProps) {
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const { settings: localSettings } = useLocalSettings();

  const activationKey = localSettings.activation_key || '/';

  return (
    <>
      <Card className="border-dashed">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <FlaskConical className="h-5 w-5 text-primary" />
              </div>
              <div>
                <CardTitle className="text-lg">Testar Atalhos</CardTitle>
                <CardDescription>
                  Simule o comportamento real dos atalhos em um ambiente de chat
                </CardDescription>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {shortcuts.length > 0 && (
                <Badge variant="secondary" className="text-xs">
                  {shortcuts.length} atalhos
                </Badge>
              )}
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center justify-between">
            <div className="flex items-center gap-4 text-sm text-muted-foreground">
              <div className="flex items-center gap-1.5">
                <Keyboard className="h-4 w-4" />
                <span>Digite <code className="bg-muted px-1 rounded">{activationKey}</code> + comando</span>
              </div>
            </div>
            <Button onClick={() => setIsDialogOpen(true)} className="gap-2">
              <ExternalLink className="h-4 w-4" />
              Abrir Simulador
            </Button>
          </div>
          
          {/* Quick preview of available shortcuts */}
          {shortcuts.length > 0 && (
            <div className="mt-4 pt-4 border-t">
              <p className="text-xs text-muted-foreground mb-2">Atalhos disponíveis para teste:</p>
              <div className="flex flex-wrap gap-1.5">
                {shortcuts.slice(0, 12).map((s) => (
                  <Badge 
                    key={s.id} 
                    variant="outline" 
                    className="text-xs font-mono cursor-pointer hover:bg-muted"
                    onClick={() => setIsDialogOpen(true)}
                  >
                    {s.command}
                  </Badge>
                ))}
                {shortcuts.length > 12 && (
                  <Badge variant="outline" className="text-xs">
                    +{shortcuts.length - 12} mais
                  </Badge>
                )}
              </div>
            </div>
          )}
          
          {shortcuts.length === 0 && (
            <div className="mt-4 p-4 rounded-lg bg-muted/50 text-center">
              <p className="text-sm text-muted-foreground">
                Nenhum atalho criado ainda. Crie atalhos para poder testá-los.
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      <ShortcutTestDialog
        open={isDialogOpen}
        onOpenChange={setIsDialogOpen}
        shortcuts={shortcuts}
        keywords={keywords}
      />
    </>
  );
}

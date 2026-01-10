import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Monitor, ExternalLink, Layers, MousePointer, FileText, Download } from 'lucide-react';
import { UserSettings, LinkClickBehavior, PdfDownloadBehavior } from '@/hooks/useUserSettings';

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
        {/* Link Click Behavior */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="space-y-0.5 flex-1 min-w-0">
            <Label htmlFor="link_behavior" className="flex items-center gap-2">
              <MousePointer className="h-4 w-4 flex-shrink-0" />
              <span>Comportamento ao clicar em links</span>
            </Label>
            <p className="text-xs text-muted-foreground">
              Define como links são abertos nas janelas flutuantes
            </p>
          </div>
          <Select
            value={settings.link_click_behavior}
            onValueChange={(value: LinkClickBehavior) => onUpdate({ link_click_behavior: value })}
          >
            <SelectTrigger className="w-full sm:w-[200px] flex-shrink-0">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="same_window">
                <span className="flex items-center gap-2">
                  <MousePointer className="h-4 w-4" />
                  Mesma janela
                </span>
              </SelectItem>
              <SelectItem value="floating_window">
                <span className="flex items-center gap-2">
                  <Layers className="h-4 w-4" />
                  Nova janela flutuante
                </span>
              </SelectItem>
              <SelectItem value="external_browser">
                <span className="flex items-center gap-2">
                  <ExternalLink className="h-4 w-4" />
                  Navegador externo
                </span>
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* PDF Download Behavior */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="space-y-0.5 flex-1 min-w-0">
            <Label htmlFor="pdf_behavior" className="flex items-center gap-2">
              <FileText className="h-4 w-4 flex-shrink-0" />
              <span>Comportamento ao baixar PDF</span>
            </Label>
            <p className="text-xs text-muted-foreground">
              Define o que acontece quando um arquivo PDF é baixado
            </p>
          </div>
          <Select
            value={settings.pdf_download_behavior || 'default'}
            onValueChange={(value: PdfDownloadBehavior) => onUpdate({ pdf_download_behavior: value })}
          >
            <SelectTrigger className="w-full sm:w-[200px] flex-shrink-0">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="default">
                <span className="flex items-center gap-2">
                  <Download className="h-4 w-4" />
                  Apenas baixar
                </span>
              </SelectItem>
              <SelectItem value="auto_open">
                <span className="flex items-center gap-2">
                  <FileText className="h-4 w-4" />
                  Abrir automaticamente
                </span>
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Auto Restore Session */}
        <div className="flex items-start sm:items-center justify-between gap-3">
          <div className="space-y-0.5 flex-1 min-w-0">
            <Label htmlFor="auto_restore">Auto-restaurar sessão</Label>
            <p className="text-xs text-muted-foreground">
              Restaurar automaticamente janelas flutuantes ao iniciar
            </p>
          </div>
          <Switch
            id="auto_restore"
            checked={settings.auto_restore_session}
            onCheckedChange={(checked) => onUpdate({ auto_restore_session: checked })}
            className="flex-shrink-0"
          />
        </div>

        {/* Save Window Positions */}
        <div className="flex items-start sm:items-center justify-between gap-3">
          <div className="space-y-0.5 flex-1 min-w-0">
            <Label htmlFor="save_positions">Salvar posição das janelas</Label>
            <p className="text-xs text-muted-foreground">
              Lembrar posição e tamanho das janelas flutuantes no monitor
            </p>
          </div>
          <Switch
            id="save_positions"
            checked={settings.save_window_positions}
            onCheckedChange={(checked) => onUpdate({ save_window_positions: checked })}
            className="flex-shrink-0"
          />
        </div>

        {/* Confirm on Close */}
        <div className="flex items-start sm:items-center justify-between gap-3">
          <div className="space-y-0.5 flex-1 min-w-0">
            <Label htmlFor="confirm_close">Confirmação ao fechar</Label>
            <p className="text-xs text-muted-foreground">
              Mostrar popup de confirmação ao fechar com janelas abertas
            </p>
          </div>
          <Switch
            id="confirm_close"
            checked={settings.confirm_on_close}
            onCheckedChange={(checked) => onUpdate({ confirm_on_close: checked })}
            className="flex-shrink-0"
          />
        </div>
      </CardContent>
    </Card>
  );
}

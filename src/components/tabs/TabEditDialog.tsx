import { useState, useCallback, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Plus, FolderOpen, Trash2, Globe, Loader2, Link } from 'lucide-react';
import { TabUrlsEditor, TabUrl } from '@/components/tabs/TabUrlsEditor';
import { LayoutSelector, LayoutType } from '@/components/tabs/LayoutSelector';

interface TabGroup {
  id: string;
  name: string;
  color: string;
}

interface TabEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  tabId: string;
  groups: TabGroup[];
  onSaved?: () => void;
}

const iconOptions = [
  { value: 'folder', label: 'Pasta' },
  { value: 'globe', label: 'Web' },
  { value: 'message-circle', label: 'WhatsApp' },
  { value: 'mail', label: 'Email' },
  { value: 'file-text', label: 'Documentos' },
  { value: 'calendar', label: 'Calendário' },
  { value: 'shopping-cart', label: 'Vendas' },
  { value: 'headphones', label: 'Suporte' },
  { value: 'dollar-sign', label: 'Financeiro' },
  { value: 'users', label: 'Equipe' },
];

const colorOptions = [
  { value: '#6366f1', label: 'Índigo' },
  { value: '#22d3ee', label: 'Ciano' },
  { value: '#10b981', label: 'Verde' },
  { value: '#f59e0b', label: 'Laranja' },
  { value: '#ef4444', label: 'Vermelho' },
  { value: '#8b5cf6', label: 'Roxo' },
  { value: '#ec4899', label: 'Rosa' },
  { value: '#64748b', label: 'Cinza' },
];

export function TabEditDialog({ 
  open, 
  onOpenChange, 
  tabId, 
  groups,
  onSaved 
}: TabEditDialogProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Form state
  const [name, setName] = useState('');
  const [url, setUrl] = useState('');
  const [urls, setUrls] = useState<TabUrl[]>([]);
  const [layoutType, setLayoutType] = useState<LayoutType>('single');
  const [icon, setIcon] = useState('globe');
  const [color, setColor] = useState('#22d3ee');
  const [mainShortcutEnabled, setMainShortcutEnabled] = useState(true);
  const [mainZoom, setMainZoom] = useState(100);
  const [openAsWindow, setOpenAsWindow] = useState(false);
  const [shortcut, setShortcut] = useState('');
  const [groupId, setGroupId] = useState<string>('');
  const [alternativeDomains, setAlternativeDomains] = useState<string[]>([]);
  const [showLinkTransformPanel, setShowLinkTransformPanel] = useState(true);
  const [captureToken, setCaptureToken] = useState(false);
  const [captureTokenHeader, setCaptureTokenHeader] = useState('X-Access-Token');
  const [webhookUrl, setWebhookUrl] = useState('');
  const [sessionGroup, setSessionGroup] = useState('');

  // Load tab data when dialog opens
  useEffect(() => {
    async function loadTab() {
      if (!open || !tabId) return;
      
      setLoading(true);
      const { data: tab, error } = await supabase
        .from('tabs')
        .select('*')
        .eq('id', tabId)
        .single();

      if (error || !tab) {
        toast({ title: 'Erro ao carregar aba', variant: 'destructive' });
        onOpenChange(false);
        return;
      }

      // Parse URLs
      let parsedUrls: TabUrl[] = [];
      if (tab.urls && Array.isArray(tab.urls)) {
        parsedUrls = (tab.urls as unknown as TabUrl[]).filter(
          u => u && typeof u === 'object' && 'url' in u
        );
      }

      // Parse alternative domains
      let parsedAltDomains: string[] = [];
      if (tab.alternative_domains && Array.isArray(tab.alternative_domains)) {
        parsedAltDomains = (tab.alternative_domains as unknown as string[]).filter(
          d => typeof d === 'string'
        );
      }

      const mainUrlData = parsedUrls[0];
      const additionalUrls = parsedUrls.slice(1);

      setName(tab.name);
      setUrl(tab.url);
      setUrls(additionalUrls);
      setLayoutType((tab.layout_type as LayoutType) || 'single');
      setIcon(tab.icon || 'globe');
      setColor(tab.color || '#22d3ee');
      setMainShortcutEnabled(mainUrlData?.shortcut_enabled ?? true);
      setMainZoom(mainUrlData?.zoom ?? tab.zoom ?? 100);
      setOpenAsWindow(tab.open_as_window || false);
      setShortcut(tab.keyboard_shortcut || '');
      setGroupId(tab.group_id);
      setAlternativeDomains(parsedAltDomains);
      setShowLinkTransformPanel(tab.show_link_transform_panel ?? true);
      setCaptureToken(tab.capture_token ?? false);
      setCaptureTokenHeader(tab.capture_token_header || 'X-Access-Token');
      setWebhookUrl(tab.webhook_url || '');
      setSessionGroup((tab as any).session_group || '');

      setLoading(false);
    }

    loadTab();
  }, [open, tabId, toast, onOpenChange]);

  const handleSave = async () => {
    if (!user || !name.trim() || !url.trim() || !groupId) {
      toast({
        title: 'Campos obrigatórios',
        description: 'Informe nome e URL da aba',
        variant: 'destructive',
      });
      return;
    }

    setSaving(true);

    // Build URLs array
    const allUrls: TabUrl[] = [
      { url: url.trim(), shortcut_enabled: mainShortcutEnabled, zoom: mainZoom },
      ...urls.filter(u => u.url.trim()).map(u => ({ ...u, zoom: u.zoom ?? 100 })),
    ];

    const effectiveLayout = allUrls.length > 1 ? layoutType : 'single';

    const { error } = await supabase
      .from('tabs')
      .update({
        name: name.trim(),
        url: url.trim(),
        urls: allUrls as unknown as any,
        layout_type: effectiveLayout,
        icon,
        color,
        open_as_window: openAsWindow,
        keyboard_shortcut: shortcut || null,
        group_id: groupId,
        alternative_domains: alternativeDomains.filter(d => d.trim()) as unknown as any,
        show_link_transform_panel: showLinkTransformPanel,
        capture_token: captureToken,
        capture_token_header: captureTokenHeader || 'X-Access-Token',
        webhook_url: webhookUrl.trim() || null,
        session_group: sessionGroup.trim() || null,
      } as any)
      .eq('id', tabId);

    if (error) {
      toast({ title: 'Erro ao atualizar', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Aba atualizada!' });
      onOpenChange(false);
      onSaved?.();
    }

    setSaving(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[550px] max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Editar Aba</DialogTitle>
          <DialogDescription>Configure os detalhes da página</DialogDescription>
        </DialogHeader>

        {loading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : (
          <div className="space-y-4 py-4">
            {/* Nome e ícone/cor */}
            <div className="flex gap-3">
              <div className="flex-1 space-y-2">
                <Label htmlFor="tab-name">Nome *</Label>
                <Input
                  id="tab-name"
                  placeholder="Ex: WhatsApp"
                  value={name}
                  onChange={e => setName(e.target.value)}
                />
              </div>
              <div className="flex items-end gap-2">
                <Select value={icon} onValueChange={setIcon}>
                  <SelectTrigger className="w-14 h-10">
                    <Globe className="h-4 w-4" style={{ color }} />
                  </SelectTrigger>
                  <SelectContent>
                    {iconOptions.map(opt => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Select value={color} onValueChange={setColor}>
                  <SelectTrigger className="w-14 h-10">
                    <div className="w-6 h-6 rounded-full" style={{ backgroundColor: color }} />
                  </SelectTrigger>
                  <SelectContent>
                    {colorOptions.map(opt => (
                      <SelectItem key={opt.value} value={opt.value}>
                        <div className="flex items-center gap-2">
                          <div className="w-4 h-4 rounded-full" style={{ backgroundColor: opt.value }} />
                          {opt.label}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Atalho de teclado */}
            <div className="space-y-2">
              <Label htmlFor="tab-shortcut">Atalho de Teclado (Opcional)</Label>
              <Input
                id="tab-shortcut"
                placeholder="Atalho para abrir esta aba/janela rapidamente"
                value={shortcut}
                onChange={e => setShortcut(e.target.value)}
              />
            </div>

            {/* Grupo */}
            <div className="space-y-2">
              <Label>Grupo</Label>
              <Select value={groupId} onValueChange={setGroupId}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione um grupo" />
                </SelectTrigger>
                <SelectContent>
                  {groups.map(group => (
                    <SelectItem key={group.id} value={group.id}>
                      <div className="flex items-center gap-2">
                        <FolderOpen className="h-4 w-4" style={{ color: group.color }} />
                        {group.name}
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Grupo de Sessão */}
            <div className="space-y-2">
              <Label htmlFor="session-group">Grupo de Sessão (Opcional)</Label>
              <Input
                id="session-group"
                placeholder="Ex: dashboard-compartilhado"
                value={sessionGroup}
                onChange={e => setSessionGroup(e.target.value)}
              />
              <p className="text-xs text-muted-foreground">
                Abas com o mesmo grupo compartilham cookies e login
              </p>
            </div>

            {/* URLs */}
            <TabUrlsEditor
              urls={urls}
              onChange={setUrls}
              mainUrl={url}
              onMainUrlChange={setUrl}
              mainShortcutEnabled={mainShortcutEnabled}
              onMainShortcutEnabledChange={setMainShortcutEnabled}
              mainZoom={mainZoom}
              onMainZoomChange={setMainZoom}
            />

            {/* Layout Selector */}
            {urls.length > 0 && (
              <LayoutSelector
                value={layoutType}
                onChange={setLayoutType}
                urlCount={1 + urls.filter(u => u.url.trim()).length}
              />
            )}

            {/* Domínios Alternativos */}
            {openAsWindow && (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <Label className="flex items-center gap-2">
                      <Link className="h-4 w-4" />
                      Domínios Alternativos
                    </Label>
                    <p className="text-xs text-muted-foreground">
                      Configure domínios para transformação de links
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => setAlternativeDomains([...alternativeDomains, ''])}
                  >
                    <Plus className="h-3 w-3 mr-1" />
                    Adicionar
                  </Button>
                </div>

                {alternativeDomains.length > 0 && (
                  <div className="space-y-2">
                    {alternativeDomains.map((domain, index) => (
                      <div key={index} className="flex gap-2">
                        <Input
                          placeholder="http://exemplo.ddns.net"
                          value={domain}
                          onChange={e => {
                            const newDomains = [...alternativeDomains];
                            newDomains[index] = e.target.value;
                            setAlternativeDomains(newDomains);
                          }}
                        />
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            const newDomains = alternativeDomains.filter((_, i) => i !== index);
                            setAlternativeDomains(newDomains);
                          }}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    ))}
                  </div>
                )}

                {/* Mostrar painel de transformação */}
                {alternativeDomains.filter(d => d.trim()).length > 0 && (
                  <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
                    <div>
                      <Label htmlFor="show-link-panel">Mostrar painel de transformação</Label>
                      <p className="text-xs text-muted-foreground">
                        Exibe um painel fixo na janela flutuante
                      </p>
                    </div>
                    <Switch
                      id="show-link-panel"
                      checked={showLinkTransformPanel}
                      onCheckedChange={setShowLinkTransformPanel}
                    />
                  </div>
                )}

                {/* Capturar Token */}
                <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
                  <div>
                    <Label htmlFor="capture-token">Capturar Token</Label>
                    <p className="text-xs text-muted-foreground">
                      Captura automaticamente o token de autenticação
                    </p>
                  </div>
                  <Switch
                    id="capture-token"
                    checked={captureToken}
                    onCheckedChange={setCaptureToken}
                  />
                </div>

                {captureToken && (
                  <>
                    <div className="space-y-2">
                      <Label htmlFor="capture-token-header">Nome do Header</Label>
                      <Input
                        id="capture-token-header"
                        placeholder="X-Access-Token"
                        value={captureTokenHeader}
                        onChange={e => setCaptureTokenHeader(e.target.value)}
                      />
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="webhook-url">URL do Webhook (opcional)</Label>
                      <Input
                        id="webhook-url"
                        placeholder="https://seu-sistema.com/api/token-webhook"
                        value={webhookUrl}
                        onChange={e => setWebhookUrl(e.target.value)}
                      />
                    </div>
                  </>
                )}
              </div>
            )}

            {/* Abrir como janela */}
            <div className="flex items-center justify-between p-3 rounded-lg border border-border bg-secondary/30">
              <div>
                <Label htmlFor="open-window">Abrir como janela</Label>
                <p className="text-xs text-muted-foreground">
                  Se marcado, esta aba será aberta em uma nova janela do navegador
                </p>
              </div>
              <Switch id="open-window" checked={openAsWindow} onCheckedChange={setOpenAsWindow} />
            </div>
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={saving || loading}>
            {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

import { useState, useCallback, useEffect, useRef } from 'react';
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
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Plus, FolderOpen, Trash2, Globe, Loader2, Link, Key, Cookie } from 'lucide-react';
import { TabUrlsEditor, TabUrl } from '@/components/tabs/TabUrlsEditor';
import { LayoutSelector, LayoutType } from '@/components/tabs/LayoutSelector';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { IconSelect } from '@/components/ui/icon-select';

interface TabGroup {
  id: string;
  name: string;
  color: string;
}

interface TabEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  tabId: string; // 'new' para criar nova aba
  groups: TabGroup[];
  defaultGroupId?: string; // grupo padrão para nova aba
  onSaved?: () => void;
}
import { colorOptions } from '@/lib/iconOptions';

export function TabEditDialog({ 
  open, 
  onOpenChange, 
  tabId, 
  groups,
  defaultGroupId,
  onSaved 
}: TabEditDialogProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  
  const isNewTab = tabId === 'new';

  // Form state
  const [name, setName] = useState('');
  const [url, setUrl] = useState('');
  const [urls, setUrls] = useState<TabUrl[]>([]);
  const [layoutType, setLayoutType] = useState<LayoutType>('single');
  const [icon, setIcon] = useState('globe');
  const [color, setColor] = useState('#22d3ee');
  const [mainShortcutEnabled, setMainShortcutEnabled] = useState(true);
  const [mainZoom, setMainZoom] = useState(100);
  const [mainSessionGroup, setMainSessionGroup] = useState('');
  const [openAsWindow, setOpenAsWindow] = useState(false);
  const [shortcut, setShortcut] = useState('');
  const [groupId, setGroupId] = useState<string>('');
  const [alternativeDomains, setAlternativeDomains] = useState<string[]>([]);
  const [showLinkTransformPanel, setShowLinkTransformPanel] = useState(true);
  const [captureToken, setCaptureToken] = useState(false);
  const [captureTokenHeader, setCaptureTokenHeader] = useState('X-Access-Token');
  const [webhookUrl, setWebhookUrl] = useState('');
  const [sessionGroup, setSessionGroup] = useState('');
  const [existingSessionGroups, setExistingSessionGroups] = useState<string[]>([]);

  const initKeyRef = useRef<string | null>(null);

  // Reset form for new tab or load existing tab data
  // Importante: não depender de `groups` aqui para evitar perder o que foi digitado
  // quando o BrowserContext faz refresh/polling em background.
  useEffect(() => {
    if (!open) {
      initKeyRef.current = null;
      return;
    }

    // Evita reinicializar o formulário enquanto o usuário está digitando.
    // Só reinicia quando abrir o dialog ou trocar o tabId.
    if (initKeyRef.current === tabId) return;
    initKeyRef.current = tabId;

    let cancelled = false;

    async function loadTab() {
      // Reset form values
      setName('');
      setUrl('');
      setUrls([]);
      setLayoutType('single');
      setIcon('globe');
      setColor('#22d3ee');
      setMainShortcutEnabled(true);
      setMainZoom(100);
      setMainSessionGroup('');
      setOpenAsWindow(false);
      setShortcut('');
      setGroupId(defaultGroupId || '');
      setAlternativeDomains([]);
      setShowLinkTransformPanel(true);
      setCaptureToken(false);
      setCaptureTokenHeader('X-Access-Token');
      setWebhookUrl('');
      setSessionGroup('');

      // Se é nova aba, não precisa carregar nada
      if (isNewTab) {
        if (!cancelled) setLoading(false);
        return;
      }

      // Carregar aba existente
      setLoading(true);
      const { data: tab, error } = await supabase
        .from('tabs')
        .select('*')
        .eq('id', tabId)
        .single();

      if (cancelled) return;

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
      setMainSessionGroup((mainUrlData as any)?.session_group || '');
      setOpenAsWindow(tab.open_as_window || false);
      setShortcut(tab.keyboard_shortcut || '');
      setGroupId(tab.group_id);
      setAlternativeDomains(parsedAltDomains);
      setShowLinkTransformPanel(tab.show_link_transform_panel ?? true);
      setCaptureToken(tab.capture_token ?? false);
      setCaptureTokenHeader(tab.capture_token_header || 'X-Access-Token');
      setWebhookUrl(tab.webhook_url || '');
      setSessionGroup((tab as any).session_group || '');

      // Fetch existing session groups from all tabs
      const { data: allTabs } = await supabase
        .from('tabs')
        .select('urls')
        .eq('user_id', user?.id);

      if (cancelled) return;

      if (allTabs) {
        const sessionGroups = new Set<string>();
        allTabs.forEach((t: any) => {
          if (t.urls && Array.isArray(t.urls)) {
            t.urls.forEach((u: any) => {
              if (u.session_group) sessionGroups.add(u.session_group);
            });
          }
        });
        setExistingSessionGroups([...sessionGroups]);
      }

      setLoading(false);
    }

    loadTab();

    return () => {
      cancelled = true;
    };
  }, [open, tabId, isNewTab, defaultGroupId, toast, onOpenChange, user?.id]);

  // Se abrir o dialog para nova aba antes de carregar os grupos, preenche o groupId quando eles chegarem.
  // Não reseta o formulário inteiro — só define o grupo se ainda estiver vazio.
  useEffect(() => {
    if (!open || !isNewTab) return;
    if (groupId) return;

    const nextGroupId = defaultGroupId || (groups.length > 0 ? groups[0].id : '');
    if (nextGroupId) setGroupId(nextGroupId);
  }, [open, isNewTab, groupId, defaultGroupId, groups]);

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

    // Build URLs array with session_group per URL
    const allUrls: TabUrl[] = [
      { url: url.trim(), shortcut_enabled: mainShortcutEnabled, zoom: mainZoom, session_group: mainSessionGroup || undefined },
      ...urls.filter(u => u.url.trim()).map(u => ({ ...u, zoom: u.zoom ?? 100, session_group: u.session_group || undefined })),
    ];

    const effectiveLayout = allUrls.length > 1 ? layoutType : 'single';
    
    const tabData = {
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
    };

    let error;
    
    if (isNewTab) {
      // Criar nova aba
      // Buscar posição para a nova aba
      const { data: existingTabs } = await supabase
        .from('tabs')
        .select('position')
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .order('position', { ascending: false })
        .limit(1);
      
      const newPosition = existingTabs && existingTabs.length > 0 ? existingTabs[0].position + 1 : 0;
      
      const result = await supabase
        .from('tabs')
        .insert({
          ...tabData,
          user_id: user.id,
          position: newPosition,
        } as any);
      
      error = result.error;
      
      if (!error) {
        toast({ title: 'Aba criada!' });
      }
    } else {
      // Atualizar aba existente
      const result = await supabase
        .from('tabs')
        .update(tabData as any)
        .eq('id', tabId);
      
      error = result.error;
      
      if (!error) {
        toast({ title: 'Aba atualizada!' });
      }
    }

    if (error) {
      toast({ title: isNewTab ? 'Erro ao criar' : 'Erro ao atualizar', description: error.message, variant: 'destructive' });
    } else {
      onOpenChange(false);
      onSaved?.();
    }

    setSaving(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[550px] max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isNewTab ? 'Nova Aba' : 'Editar Aba'}</DialogTitle>
          <DialogDescription>{isNewTab ? 'Configure os detalhes da nova página' : 'Configure os detalhes da página'}</DialogDescription>
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
                <IconSelect value={icon} onValueChange={setIcon} color={color} />
                <Select value={color} onValueChange={setColor}>
                  <SelectTrigger className="w-14 h-10">
                    <div className="w-6 h-6 rounded-full" style={{ backgroundColor: color }} />
                  </SelectTrigger>
                  <SelectContent className="max-h-[300px]">
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
              mainSessionGroup={mainSessionGroup}
              onMainSessionGroupChange={setMainSessionGroup}
              existingSessionGroups={existingSessionGroups}
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

            {/* Gerenciamento de Dados - Só mostra para abas que abrem como janela */}
            {openAsWindow && (
              <div className="space-y-3 pt-4 border-t border-border">
                <Label className="text-destructive flex items-center gap-2">
                  <Trash2 className="h-4 w-4" />
                  Gerenciamento de Dados
                </Label>
                
                <div className="flex gap-2 flex-wrap">
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button type="button" variant="outline" size="sm" className="text-destructive border-destructive/50 hover:bg-destructive/10">
                        <Key className="h-3 w-3 mr-1" />
                        Excluir Senhas
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Excluir Senhas Salvas</AlertDialogTitle>
                        <AlertDialogDescription>
                          Isso irá remover todas as senhas salvas para o domínio desta aba. Esta ação não pode ser desfeita.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                          className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                          onClick={async () => {
                            try {
                              const domain = new URL(url).hostname;
                              
                              // Limpar do Supabase
                              await supabase
                                .from('saved_credentials')
                                .delete()
                                .eq('user_id', user?.id)
                                .ilike('domain', `%${domain}%`);
                              
                              // Limpar do electron-store via IPC (se disponível)
                              // eslint-disable-next-line @typescript-eslint/no-explicit-any
                              const api = (window as any).electronAPI;
                              if (api?.deleteCredentialsByDomain) {
                                await api.deleteCredentialsByDomain(domain);
                              }
                              
                              toast({ title: 'Senhas excluídas', description: `Senhas para ${domain} foram removidas.` });
                            } catch (error) {
                              console.error('Erro ao excluir senhas:', error);
                              toast({ title: 'Erro ao excluir senhas', variant: 'destructive' });
                            }
                          }}
                        >
                          Excluir
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                  
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button type="button" variant="outline" size="sm" className="text-destructive border-destructive/50 hover:bg-destructive/10">
                        <Cookie className="h-3 w-3 mr-1" />
                        Excluir Cache/Cookies
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Excluir Cache e Cookies</AlertDialogTitle>
                        <AlertDialogDescription>
                          Isso irá remover cookies, localStorage e cache para esta aba. Você será deslogado de sites e precisará fazer login novamente.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                          className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                          onClick={async () => {
                            try {
                              // eslint-disable-next-line @typescript-eslint/no-explicit-any
                              const api = (window as any).electronAPI;
                              if (api?.clearSessionData) {
                                // Determinar a partition correta (padronizado com persist:session-${grupo})
                                const normalizeGroup = (g: string) => g.trim().toLowerCase().replace(/\s+/g, '-');
                                const partitionName = mainSessionGroup 
                                  ? `persist:session-${normalizeGroup(mainSessionGroup)}` 
                                  : sessionGroup 
                                    ? `persist:session-${normalizeGroup(sessionGroup)}` 
                                    : `persist:floating-webview`;
                                
                                const result = await api.clearSessionData(partitionName);
                                if (result.success) {
                                  toast({ title: 'Cache limpo', description: 'Cookies e dados de sessão foram removidos. Reinicie a janela para aplicar.' });
                                } else {
                                  throw new Error(result.error || 'Erro desconhecido');
                                }
                              } else {
                                toast({ 
                                  title: 'Disponível apenas no app desktop', 
                                  description: 'Esta funcionalidade requer o aplicativo desktop.',
                                  variant: 'destructive' 
                                });
                              }
                            } catch (error) {
                              console.error('Erro ao limpar cache:', error);
                              toast({ title: 'Erro ao limpar cache', variant: 'destructive' });
                            }
                          }}
                        >
                          Excluir
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </div>
                
                <p className="text-xs text-muted-foreground">
                  Limpa dados salvos para o domínio principal desta aba.
                </p>
              </div>
            )}
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

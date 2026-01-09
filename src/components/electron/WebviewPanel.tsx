import { useEffect, useRef, useState } from 'react';
import { DynamicIcon } from '@/components/ui/dynamic-icon';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { 
  ArrowLeft, 
  ArrowRight, 
  RotateCw, 
  ZoomIn, 
  ZoomOut, 
  X,
  ExternalLink,
  Loader2,
  ChevronUp,
  SlidersHorizontal,
  Save,
  Key,
  Settings
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from '@/components/ui/resizable';
import { useElectron, ElectronAPI } from '@/hooks/useElectron';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { DownloadsPopover } from './DownloadsPopover';
import { toast } from 'sonner';
import { useWebviewCredentials } from './CredentialManager';
import { useFormFieldManager } from './FormFieldManager';
import { WebviewContextMenu } from './WebviewContextMenu';

interface TabUrl {
  url: string;
  shortcut_enabled?: boolean;
  zoom?: number;
  session_group?: string;
}

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

export interface ShortcutConfig {
  activationKey: string;
  activationTime: number;
}

interface WebviewPanelProps {
  tab: {
    id: string;
    name: string;
    url: string;
    urls?: TabUrl[];
    layout_type?: string;
    zoom?: number;
    icon?: string;
    color?: string;
    panel_sizes?: number[] | null;
    session_group?: string | null;
  };
  textShortcuts?: { command: string; expanded_text: string; auto_send?: boolean; messages?: ShortcutMessage[] }[];
  keywords?: { key: string; value: string }[];
  shortcutConfig?: ShortcutConfig;
  onClose: () => void;
  onNotificationChange?: (count: number) => void;
  onEditTab?: () => void;
}

type LayoutType = 'single' | '2x1' | '1x2' | '2x2' | '3x1' | '1x3';

const defaultShortcutConfig: ShortcutConfig = { activationKey: '/', activationTime: 10 };

export function WebviewPanel({ tab, textShortcuts = [], keywords = [], shortcutConfig = defaultShortcutConfig, onClose, onNotificationChange, onEditTab }: WebviewPanelProps) {
  const { user } = useAuth();
  const { isElectron, openExternal } = useElectron();
  const [loading, setLoading] = useState<boolean[]>([]);
  const [showToolbars, setShowToolbars] = useState(false);
  const [clipboardDomains, setClipboardDomains] = useState<string[]>(['whatsapp.com']);
  const [panelSizes, setPanelSizes] = useState<number[]>(tab.panel_sizes || []);
  const [contextMenu, setContextMenu] = useState<{ visible: boolean; x: number; y: number; url: string } | null>(null);
  const [shortcutModeActive, setShortcutModeActive] = useState(false);
  const shortcutModeTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const webviewRefs = useRef<HTMLElement[]>([]);
  const saveTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  // Credential manager hook
  const { 
    handleCredentialCapture, 
    autoFillCredentials, 
    getCredentialDetectionScript,
    SaveCredentialDialog 
  } = useWebviewCredentials();
  
  // Form field manager hook
  const { getFormFieldScript, handleFormFieldMessage } = useFormFieldManager();
  
  // Rastrear quais webviews já tiveram dom-ready
  const webviewReadyRef = useRef<boolean[]>([]);
  
  // Refs para manter a versão mais atual dos shortcuts/keywords
  const textShortcutsRef = useRef(textShortcuts);
  const keywordsRef = useRef(keywords);
  const clipboardDomainsRef = useRef(clipboardDomains);

  const layout = (tab.layout_type as LayoutType) || 'single';

  // Função para salvar tamanhos dos painéis no banco
  const savePanelSizes = async (sizes: number[]) => {
    if (!user) return;
    
    // Debounce para não salvar a cada pequeno movimento
    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }
    
    saveTimeoutRef.current = setTimeout(async () => {
      console.log('[WebviewPanel] Salvando tamanhos dos painéis:', sizes);
      const { error } = await supabase
        .from('tabs')
        .update({ panel_sizes: sizes })
        .eq('id', tab.id);
      
      if (error) {
        console.error('[WebviewPanel] Erro ao salvar tamanhos:', error);
      }
    }, 500);
  };

  // Handler para mudança de layout
  const handleLayoutChange = (sizes: number[]) => {
    setPanelSizes(sizes);
    savePanelSizes(sizes);
  };

  // Carregar domínios configurados para modo clipboard
  useEffect(() => {
    if (!user) return;
    
    async function loadClipboardDomains() {
      const { data } = await supabase
        .from('clipboard_domains')
        .select('domain')
        .eq('user_id', user.id);
      
      if (data && data.length > 0) {
        setClipboardDomains(data.map(d => d.domain));
      }
    }
    
    loadClipboardDomains();
  }, [user]);

  // Extrair URLs com informação de atalhos habilitados e session_group
  const urls: { url: string; zoom: number; shortcut_enabled: boolean; session_group?: string }[] = [];
  if (tab.urls && tab.urls.length > 0) {
    tab.urls.forEach((item) => {
      if (typeof item === 'string') {
        urls.push({ url: item, zoom: tab.zoom || 100, shortcut_enabled: true });
      } else if (item && typeof item === 'object' && item.url) {
        urls.push({ 
          url: item.url, 
          zoom: item.zoom || tab.zoom || 100, 
          shortcut_enabled: item.shortcut_enabled !== false, // default true
          session_group: item.session_group
        });
      }
    });
  }
  if (urls.length === 0) {
    urls.push({ url: tab.url, zoom: tab.zoom || 100, shortcut_enabled: true });
  }
  
  // Função para obter a partição correta para cada URL
  // IMPORTANTE: URLs com "Nenhum (isolado)" devem ter partições únicas por URL
  const getPartition = (urlIndex: number): string => {
    const urlData = urls[urlIndex];
    
    // Se a URL tem um session_group definido, usar partição do grupo
    if (urlData?.session_group && urlData.session_group.trim()) {
      const normalizedGroup = urlData.session_group.trim().toLowerCase().replace(/\s+/g, '-');
      return `persist:session-${normalizedGroup}`;
    }
    
    // Fallback para session_group a nível de tab (compatibilidade com tabs antigos)
    if (tab.session_group && tab.session_group.trim()) {
      const normalizedGroup = tab.session_group.trim().toLowerCase().replace(/\s+/g, '-');
      return `persist:session-${normalizedGroup}`;
    }
    
    // Caso "Nenhum (isolado)": partição única por URL dentro da aba
    // Isso garante que cada URL tenha cookies/storage independentes
    return `persist:tab-${tab.id}-url-${urlIndex}`;
  };

  // Estado individual de URL e zoom para cada webview
  const [webviewStates, setWebviewStates] = useState(
    urls.map(u => ({ currentUrl: u.url, zoom: u.zoom }))
  );

  // Número de webviews baseado no layout
  const webviewCount = layout === 'single' ? 1 :
    layout === '2x1' || layout === '1x2' ? 2 :
    layout === '2x2' ? 4 :
    layout === '3x1' || layout === '1x3' ? 3 : 1;

  // Inicializar loading states e resetar webviewReady
  useEffect(() => {
    setLoading(Array(webviewCount).fill(true));
    // Resetar o estado de pronto para todos os webviews quando mudar
    webviewReadyRef.current = Array(webviewCount).fill(false);
  }, [webviewCount, tab.id]);

  // Manter refs atualizadas
  useEffect(() => {
    textShortcutsRef.current = textShortcuts;
    keywordsRef.current = keywords;
    clipboardDomainsRef.current = clipboardDomains;
  }, [textShortcuts, keywords, clipboardDomains]);

  // Escutar eventos de navegação dos botões laterais do mouse
  useEffect(() => {
    if (!isElectron) return;
    
    const api = window.electronAPI;
    if (!api?.onNavigateBack || !api?.onNavigateForward) return;
    
    const unsubBack = api.onNavigateBack(() => {
      // Encontrar o primeiro webview disponível
      const webview = webviewRefs.current.find(wv => wv && (wv as any).canGoBack?.());
      if (webview && (webview as any).canGoBack?.()) {
        (webview as any).goBack();
      }
    });
    
    const unsubForward = api.onNavigateForward(() => {
      const webview = webviewRefs.current.find(wv => wv && (wv as any).canGoForward?.());
      if (webview && (webview as any).canGoForward?.()) {
        (webview as any).goForward();
      }
    });
    
    return () => {
      unsubBack?.();
      unsubForward?.();
    };
  }, [isElectron]);

  // Re-injetar atalhos quando eles mudam (inclui tecla/prefixo) e já temos webviews carregados
  useEffect(() => {
    if (!isElectron) return;

    console.log('[GerenciaZap] Config/atalhos mudaram, re-injetando em webviews existentes...');

    webviewRefs.current.forEach((webview, index) => {
      // IMPORTANTE: Só re-injetar se o webview já teve dom-ready
      if (!webviewReadyRef.current[index]) {
        console.log(`[GerenciaZap] Webview ${index} ainda não está pronto, pulando re-injeção`);
        return;
      }

      if (webview && typeof (webview as any).executeJavaScript === 'function') {
        console.log(`[GerenciaZap] Re-injetando atalhos no webview ${index}`);
        injectShortcuts(webview, index);
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    isElectron,
    textShortcuts,
    keywords,
    clipboardDomains,
    shortcutConfig?.activationKey,
    shortcutConfig?.activationTime,
  ]);


  // Registrar event listeners manualmente para o webview
  useEffect(() => {
    if (!isElectron) return;

    const cleanupFunctions: (() => void)[] = [];
    const loadingTimeouts: NodeJS.Timeout[] = [];

    // Aguardar os webviews estarem disponíveis
    const timeout = setTimeout(() => {
      webviewRefs.current.forEach((webview, index) => {
        if (!webview) {
          console.log(`[GerenciaZap] Webview ${index} não disponível`);
          return;
        }

        console.log(`[GerenciaZap] Registrando eventos para webview ${index}`);

        // Função para limpar timeout de loading
        const clearLoadingTimeout = (idx: number) => {
          if (loadingTimeouts[idx]) {
            clearTimeout(loadingTimeouts[idx]);
            loadingTimeouts[idx] = undefined as any;
          }
        };

        // Função para iniciar timeout de fallback (10 segundos)
        const startLoadingTimeout = (idx: number) => {
          clearLoadingTimeout(idx);
          loadingTimeouts[idx] = setTimeout(() => {
            console.log(`[GerenciaZap] Timeout de loading atingido para webview ${idx}`);
            // Verificar estado real do webview
            const wv = webviewRefs.current[idx] as any;
            if (wv && typeof wv.isLoading === 'function') {
              if (!wv.isLoading()) {
                console.log(`[GerenciaZap] Webview ${idx} não está mais carregando (verificação isLoading)`);
                setLoadingForIndex(idx, false);
              } else {
                console.log(`[GerenciaZap] Webview ${idx} ainda está carregando, forçando parada do spinner`);
                setLoadingForIndex(idx, false);
              }
            } else {
              // Se não conseguir verificar, desabilitar loading por segurança
              setLoadingForIndex(idx, false);
            }
          }, 10000); // 10 segundos de timeout
        };

        const handleDomReady = () => {
          console.log(`[GerenciaZap] dom-ready disparado para webview ${index}`);
          // Marcar este webview como pronto
          webviewReadyRef.current[index] = true;
          injectShortcuts(webview, index);
          
          // Injetar script de detecção de credenciais
          const credScript = getCredentialDetectionScript();
          (webview as any).executeJavaScript?.(credScript).catch(() => {});
          
          // Injetar script de sugestões de formulários
          const formScript = getFormFieldScript();
          (webview as any).executeJavaScript?.(formScript).catch(() => {});
          
          // Injetar script de context menu para links
          const contextMenuScript = `
            (function() {
              if (window.__gerenciazapContextMenuInjected) return;
              window.__gerenciazapContextMenuInjected = true;
              
              document.addEventListener('contextmenu', function(e) {
                var link = e.target.closest('a[href]');
                if (link && link.href && !link.href.startsWith('javascript:')) {
                  e.preventDefault();
                  e.stopPropagation();
                  var data = {
                    url: link.href,
                    text: (link.textContent || '').trim().substring(0, 100) || link.href,
                    x: e.clientX,
                    y: e.clientY
                  };
                  console.warn('__GERENCIAZAP_CONTEXT_MENU__:' + JSON.stringify(data));
                }
              }, true);
            })();
          `;
          (webview as any).executeJavaScript?.(contextMenuScript).catch(() => {});
          
          // Tentar auto-preencher credenciais
          const currentUrl = (webview as any).getURL?.() || urls[index]?.url;
          if (currentUrl) {
            autoFillCredentials(webview, currentUrl);
          }
        };

        const handleDidStartLoading = () => {
          console.log(`[GerenciaZap] did-start-loading disparado para webview ${index}`);
          setLoadingForIndex(index, true);
          startLoadingTimeout(index);
        };

        const handleDidStopLoading = () => {
          console.log(`[GerenciaZap] did-stop-loading disparado para webview ${index}`);
          clearLoadingTimeout(index);
          setLoadingForIndex(index, false);
          
          // Aplicar zoom se necessário
          const urlData = urls[index] || urls[0];
          if (urlData.zoom !== 100 && (webview as any).setZoomFactor) {
            (webview as any).setZoomFactor(urlData.zoom / 100);
          }
          
          injectShortcuts(webview, index);
        };

        const handleDidFailLoad = (e: any) => {
          console.log(`[GerenciaZap] did-fail-load disparado para webview ${index}`, e?.errorCode, e?.errorDescription);
          clearLoadingTimeout(index);
          setLoadingForIndex(index, false);
        };

        const handleDidNavigate = (e: any) => {
          console.log(`[GerenciaZap] did-navigate disparado para webview ${index}`, e?.url);
          if (e?.url) {
            updateWebviewState(index, { currentUrl: e.url });
          }
        };

        // Handler para detectar notificações pelo título da página
        const handlePageTitleUpdated = (e: any) => {
          const title = e?.title || '';
          // Extrair número de notificações do formato "(N) Título" ou "Título (N)"
          const match = title.match(/^\((\d+)\)/) || title.match(/\((\d+)\)$/);
          const count = match ? parseInt(match[1], 10) : 0;
          onNotificationChange?.(count);
        };

        // Handler para mensagens do console - captura clipboard IPC e credenciais
        const handleConsoleMessage = async (e: any) => {
          const message = e?.message || '';
          const level = e?.level || 0; // 0=log, 1=warn, 2=error
          
          // Log all GerenciaZap messages for debugging
          if (message.includes('[GerenciaZap]') || message.includes('__GERENCIAZAP_')) {
            console.log(`[WebviewPanel] Console message (level ${level}):`, message);
          }
          
          // Capturar estado do modo atalho
          if (message.includes('__GERENCIAZAP_SHORTCUT_MODE__:ACTIVE')) {
            console.log('[WebviewPanel] Modo atalho ATIVADO');
            if (shortcutModeTimeoutRef.current) {
              clearTimeout(shortcutModeTimeoutRef.current);
            }
            setShortcutModeActive(true);
            return;
          }
          if (message.includes('__GERENCIAZAP_SHORTCUT_MODE__:INACTIVE')) {
            console.log('[WebviewPanel] Modo atalho DESATIVADO');
            setShortcutModeActive(false);
            return;
          }
          
          // Verificar se é uma mensagem de clipboard do GerenciaZap
          if (message.startsWith('__GERENCIAZAP_CLIPBOARD__:')) {
            try {
              const jsonStr = message.replace('__GERENCIAZAP_CLIPBOARD__:', '');
              const data = JSON.parse(jsonStr);
              
              console.log('[GerenciaZap] Recebido pedido de clipboard via IPC:', data.command);
              
              // Copiar para clipboard via Electron IPC
              const api = window.electronAPI as ElectronAPI | undefined;
              if (api?.writeToClipboard) {
                const wv = webviewRefs.current[index];
                
                // Helper functions para simular teclas
                const sendCtrlA = async () => {
                  if (wv && typeof (wv as any).sendInputEvent === 'function') {
                    console.log('[GerenciaZap] Simulando Ctrl+A...');
                    (wv as any).sendInputEvent({ type: 'keyDown', keyCode: 'A', modifiers: ['control'] });
                    (wv as any).sendInputEvent({ type: 'keyUp', keyCode: 'A', modifiers: ['control'] });
                    await new Promise(r => setTimeout(r, 30));
                  }
                };
                
                const sendCtrlV = async () => {
                  if (wv && typeof (wv as any).sendInputEvent === 'function') {
                    console.log('[GerenciaZap] Simulando Ctrl+V...');
                    (wv as any).sendInputEvent({ type: 'keyDown', keyCode: 'V', modifiers: ['control'] });
                    (wv as any).sendInputEvent({ type: 'keyUp', keyCode: 'V', modifiers: ['control'] });
                    await new Promise(r => setTimeout(r, 50));
                  }
                };
                
                const sendEnter = async () => {
                  if (wv && typeof (wv as any).executeJavaScript === 'function') {
                    console.log('[GerenciaZap] Clicando no botão de enviar...');
                    try {
                      await (wv as any).executeJavaScript(`
                        (function() {
                          const sendButton = document.querySelector('[data-testid="send"]') 
                            || document.querySelector('[aria-label*="Send"]')
                            || document.querySelector('[aria-label*="Enviar"]')
                            || document.querySelector('button[aria-label*="send"]')
                            || document.querySelector('span[data-icon="send"]')?.closest('button');
                          
                          if (sendButton) {
                            console.log('[GerenciaZap] Botão de enviar encontrado, clicando...');
                            sendButton.click();
                            return true;
                          } else {
                            console.error('[GerenciaZap] Botão de enviar não encontrado');
                            return false;
                          }
                        })();
                      `);
                    } catch (err) {
                      console.error('[GerenciaZap] Erro ao clicar no botão:', err);
                    }
                    await new Promise(r => setTimeout(r, 200));
                  }
                };
                
                const showToast = (message: string) => {
                  (wv as any).executeJavaScript?.(`
                    (function() {
                      const container = document.getElementById('gerenciazap-toast-container');
                      if (container) {
                        container.innerHTML = '';
                        
                        const toast = document.createElement('div');
                        toast.style.cssText = \`
                          background: linear-gradient(135deg, #25D366 0%, #128C7E 100%);
                          color: white;
                          padding: 14px 20px;
                          border-radius: 10px;
                          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                          font-size: 14px;
                          box-shadow: 0 4px 16px rgba(37, 211, 102, 0.5);
                          display: flex;
                          align-items: center;
                          gap: 10px;
                          opacity: 0;
                          transform: translateY(20px);
                          transition: all 0.3s ease;
                          pointer-events: auto;
                        \`;
                        
                        toast.innerHTML = \`
                          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                            <polyline points="22 4 12 14.01 9 11.01"/>
                          </svg>
                          <span>\${message}</span>
                        \`;
                        
                        container.appendChild(toast);
                        requestAnimationFrame(() => {
                          toast.style.opacity = '1';
                          toast.style.transform = 'translateY(0)';
                        });
                        
                        setTimeout(() => {
                          toast.style.opacity = '0';
                          toast.style.transform = 'translateY(20px)';
                          setTimeout(() => toast.remove(), 300);
                        }, 2500);
                      }
                    })();
                  `).catch(() => {});
                };
                
                // Processar múltiplas mensagens
                const messages = data.messages || [{ text: data.text || '', auto_send: false }];
                console.log('[GerenciaZap] Processando', messages.length, 'mensagem(ns)');
                
                for (let i = 0; i < messages.length; i++) {
                  const msg = messages[i];
                  const cleanText = msg.text.replace(/\\n/g, '\n');
                  const isLast = i === messages.length - 1;
                  
                  console.log(`[GerenciaZap] Mensagem ${i + 1}/${messages.length}:`, cleanText.substring(0, 50), 'auto_send:', msg.auto_send);
                  
                  // Copiar para clipboard
                  const result = await api.writeToClipboard(cleanText);
                  if (!result.success) {
                    console.error('[GerenciaZap] Falha ao copiar:', result.error);
                    continue;
                  }
                  console.log('[GerenciaZap] Texto copiado para clipboard com sucesso!');
                  
                  // Colar no campo
                  await new Promise(r => setTimeout(r, 50));
                  await sendCtrlA();
                  await sendCtrlV();
                  
                  // Se auto_send, enviar a mensagem
                  if (msg.auto_send) {
                    await new Promise(r => setTimeout(r, 100));
                    await sendEnter();
                    console.log('[GerenciaZap] Mensagem enviada (auto_send)');
                    
                    // Aguardar um pouco antes da próxima mensagem
                    if (!isLast) {
                      await new Promise(r => setTimeout(r, 300));
                    }
                  }
                }
                
                // Mostrar toast final
                const sentCount = messages.filter((m: { auto_send: boolean }) => m.auto_send).length;
                if (sentCount > 0) {
                  setTimeout(() => {
                    showToast(`<strong>${data.command}</strong> ${sentCount} mensagem(ns) enviada(s)!`);
                  }, 100);
                } else {
                  setTimeout(() => {
                    showToast(`<strong>${data.command}</strong> expandido!`);
                  }, 100);
                }
              } else {
                console.error('[GerenciaZap] writeToClipboard não disponível');
              }
            } catch (err) {
              console.error('[GerenciaZap] Erro ao processar mensagem de clipboard:', err);
            }
          }
          
          // Verificar se é uma mensagem de credenciais detectadas
          if (message.startsWith('__GERENCIAZAP_CREDENTIAL__:')) {
            try {
              const jsonStr = message.replace('__GERENCIAZAP_CREDENTIAL__:', '');
              const data = JSON.parse(jsonStr);
              console.log('[GerenciaZap] Credenciais detectadas para:', data.url);
              handleCredentialCapture(data);
            } catch (err) {
              console.error('[GerenciaZap] Erro ao processar credenciais:', err);
            }
          }
          
          // Verificar se é uma mensagem de formulário (usar .includes para pegar qualquer nível)
          if (message.includes('__GERENCIAZAP_FORM_FIELD_')) {
            console.log('[WebviewPanel] Mensagem de FormField detectada:', message.substring(0, 100));
            const wv = webviewRefs.current[index];
            handleFormFieldMessage(message, wv);
          }
          
          // Verificar se é uma mensagem de context menu
          if (message.includes('__GERENCIAZAP_CONTEXT_MENU__:')) {
            try {
              const jsonStr = message.split('__GERENCIAZAP_CONTEXT_MENU__:')[1];
              const data = JSON.parse(jsonStr);
              console.log('[WebviewPanel] Context menu para link:', data.url);
              
              // Obter posição do webview para ajustar coordenadas
              const wv = webviewRefs.current[index];
              const rect = wv?.getBoundingClientRect?.() || { left: 0, top: 0 };
              
              setContextMenu({
                visible: true,
                x: data.x + rect.left,
                y: data.y + rect.top,
                url: data.url
              });
            } catch (err) {
              console.error('[WebviewPanel] Erro ao processar context menu:', err);
            }
          }
        };

        webview.addEventListener('dom-ready', handleDomReady);
        webview.addEventListener('did-start-loading', handleDidStartLoading);
        webview.addEventListener('did-stop-loading', handleDidStopLoading);
        webview.addEventListener('did-fail-load', handleDidFailLoad);
        webview.addEventListener('did-navigate', handleDidNavigate);
        webview.addEventListener('console-message', handleConsoleMessage);
        webview.addEventListener('page-title-updated', handlePageTitleUpdated);

        cleanupFunctions.push(() => {
          clearLoadingTimeout(index);
          webview.removeEventListener('dom-ready', handleDomReady);
          webview.removeEventListener('did-start-loading', handleDidStartLoading);
          webview.removeEventListener('did-stop-loading', handleDidStopLoading);
          webview.removeEventListener('did-fail-load', handleDidFailLoad);
          webview.removeEventListener('did-navigate', handleDidNavigate);
          webview.removeEventListener('console-message', handleConsoleMessage);
          webview.removeEventListener('page-title-updated', handlePageTitleUpdated);
        });
      });
    }, 100);

    return () => {
      clearTimeout(timeout);
      loadingTimeouts.forEach(t => t && clearTimeout(t));
      cleanupFunctions.forEach(fn => fn());
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isElectron]);

  // Se não está no Electron, mostrar iframe ou mensagem
  if (!isElectron) {
    return (
      <div className="h-full flex flex-col bg-background">
        <div className="flex items-center gap-2 p-2 border-b bg-muted/50">
          <div 
            className="w-8 h-8 rounded flex items-center justify-center text-white shrink-0"
            style={{ backgroundColor: tab.color || '#00a4a4' }}
          >
            <DynamicIcon icon={tab.icon} fallback="🌐" className="h-4 w-4" style={{ color: 'white' }} />
          </div>
          <span className="font-medium truncate flex-1">{tab.name}</span>
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => openExternal(tab.url)}
          >
            <ExternalLink className="h-4 w-4 mr-1" />
            Abrir no navegador
          </Button>
          <Button variant="ghost" size="icon" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>
        <div className="flex-1 flex items-center justify-center p-8">
          <div className="text-center max-w-md">
            <div className="p-4 rounded-full bg-primary/10 w-fit mx-auto mb-4">
              <ExternalLink className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Visualização no navegador</h3>
            <p className="text-muted-foreground mb-4">
              A visualização de webviews está disponível apenas no aplicativo Electron. 
              Clique no botão acima para abrir no navegador externo.
            </p>
            <div className="flex gap-2 justify-center flex-wrap">
              {urls.map((u, i) => (
                <Button 
                  key={i}
                  variant="outline" 
                  size="sm"
                  onClick={() => openExternal(u.url)}
                >
                  Abrir URL {i + 1}
                </Button>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Renderizar webviews no Electron - usar painéis redimensionáveis para layouts multi-painel
  const isResizableLayout = layout !== 'single';
  const resizeDirection = (layout === '1x2' || layout === '1x3') ? 'vertical' : 'horizontal';

  const updateWebviewState = (index: number, updates: Partial<{ currentUrl: string; zoom: number }>) => {
    setWebviewStates(prev => {
      const newStates = [...prev];
      newStates[index] = { ...newStates[index], ...updates };
      return newStates;
    });
  };

  // Salvar zoom no banco de dados
  const saveZoomToDatabase = async (index: number, newZoom: number) => {
    if (!user) return;
    
    // Debounce para não salvar a cada pequeno movimento
    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }
    
    saveTimeoutRef.current = setTimeout(async () => {
      console.log('[WebviewPanel] Salvando zoom:', newZoom, 'para URL', index);
      
      // Se for layout single ou só tem uma URL, atualizar o zoom geral da aba
      if (urls.length <= 1) {
        await supabase
          .from('tabs')
          .update({ zoom: newZoom })
          .eq('id', tab.id);
      } else {
        // Atualizar o array de URLs com o zoom específico
        const updatedUrls = urls.map((u, i) => ({
          url: u.url,
          shortcut_enabled: u.shortcut_enabled,
          zoom: i === index ? newZoom : u.zoom
        }));
        
        await supabase
          .from('tabs')
          .update({ urls: updatedUrls as unknown as any })
          .eq('id', tab.id);
      }
    }, 500);
  };

  const handleZoomIn = (index: number) => {
    const newZoom = Math.min((webviewStates[index]?.zoom || 100) + 2, 200);
    updateWebviewState(index, { zoom: newZoom });
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).setZoomFactor) {
      (wv as any).setZoomFactor(newZoom / 100);
    }
    saveZoomToDatabase(index, newZoom);
  };

  const handleZoomOut = (index: number) => {
    const newZoom = Math.max((webviewStates[index]?.zoom || 100) - 2, 50);
    updateWebviewState(index, { zoom: newZoom });
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).setZoomFactor) {
      (wv as any).setZoomFactor(newZoom / 100);
    }
    saveZoomToDatabase(index, newZoom);
  };

  const handleBack = (index: number) => {
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).goBack) {
      (wv as any).goBack();
    }
  };

  const handleForward = (index: number) => {
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).goForward) {
      (wv as any).goForward();
    }
  };

  const handleRefresh = (index: number) => {
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).reload) {
      (wv as any).reload();
    }
  };

  const handleUrlSubmit = (e: React.FormEvent, index: number) => {
    e.preventDefault();
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).loadURL) {
      let url = webviewStates[index]?.currentUrl || '';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url;
      }
      (wv as any).loadURL(url);
    }
  };

  const handleDownload = (index: number) => {
    const url = webviewStates[index]?.currentUrl;
    if (url) {
      openExternal(url);
    }
  };

  const setLoadingForIndex = (index: number, value: boolean) => {
    setLoading(prev => {
      const newLoading = [...prev];
      newLoading[index] = value;
      return newLoading;
    });
  };

  // Injetar script de atalhos
  const injectShortcuts = (webview: any, webviewIndex: number) => {
    // Usar refs para ter sempre os valores mais recentes
    const currentShortcuts = textShortcutsRef.current;
    const currentKeywords = keywordsRef.current;
    const currentClipboardDomains = clipboardDomainsRef.current;
    
    // Verificar se atalhos estão habilitados para esta URL
    const urlData = urls[webviewIndex] || urls[0];
    if (!urlData.shortcut_enabled) {
      console.log(`[GerenciaZap] Atalhos DESABILITADOS para webview ${webviewIndex} (${urlData.url})`);
      
      // Remover listeners se existirem
      webview.executeJavaScript?.(`
        (function() {
          if (window.__gerenciazapInputHandler) {
            document.removeEventListener('input', window.__gerenciazapInputHandler, true);
            document.removeEventListener('keyup', window.__gerenciazapKeyHandler, true);
            window.__gerenciazapInputHandler = null;
            window.__gerenciazapKeyHandler = null;
            window.__gerenciazapInjected = false;
            console.log('[GerenciaZap] Atalhos removidos (desabilitados para este site)');
          }
          return 'disabled';
        })();
      `).catch(() => {});
      return;
    }
    
    console.log('[GerenciaZap] injectShortcuts chamado, textShortcuts:', currentShortcuts.length, 'keywords:', currentKeywords.length);
    console.log('[GerenciaZap] Domínios com clipboard mode:', currentClipboardDomains);
    
    if (!webview) {
      console.log('[GerenciaZap] Webview não disponível');
      return;
    }

    // Verificar se o webview tem o método executeJavaScript
    if (typeof webview.executeJavaScript !== 'function') {
      console.log('[GerenciaZap] executeJavaScript não disponível, aguardando...');
      // Tentar novamente após delay
      setTimeout(() => {
        if (typeof webview.executeJavaScript === 'function') {
          injectShortcuts(webview, webviewIndex);
        }
      }, 500);
      return;
    }

    // Criar mapa de atalhos com suporte a múltiplas mensagens
    const shortcutsMap: Record<string, { messages: Array<{ text: string; auto_send: boolean }> }> = {};
    currentShortcuts.forEach(s => {
      // Se tem messages, usar; senão criar array com expanded_text
      if (s.messages && s.messages.length > 0) {
        shortcutsMap[s.command] = { messages: s.messages };
      } else {
        shortcutsMap[s.command] = { 
          messages: [{ text: s.expanded_text, auto_send: s.auto_send || false }] 
        };
      }
    });

    const keywordsMap: Record<string, string> = {};
    currentKeywords.forEach(k => {
      keywordsMap[`<${k.key}>`] = k.value;
    });

    console.log('[GerenciaZap] Mapa de atalhos:', JSON.stringify(shortcutsMap));
    console.log('[GerenciaZap] Mapa de keywords:', JSON.stringify(keywordsMap));

    const script = `
      (function() {
        // Limpar estado anterior se existir
        if (window.__gerenciazapInjected) {
          console.log('[GerenciaZap] Atualizando atalhos...');
          if (window.__gerenciazapActivationCleanup) {
            window.__gerenciazapActivationCleanup();
          }
        }
        window.__gerenciazapInjected = true;
        
         // Usar variáveis globais para permitir atualização dinâmica
         window.__gerenciazapShortcuts = ${JSON.stringify(shortcutsMap)};
         window.__gerenciazapKeywords = ${JSON.stringify(keywordsMap)};
         window.__gerenciazapClipboardDomains = ${JSON.stringify(currentClipboardDomains)};
         const activationKey = ${JSON.stringify(shortcutConfig.activationKey || '/')};
         const ACTIVATION_DURATION = ${(shortcutConfig.activationTime || 10) * 1000}; // em milissegundos
        
        // Estado de ativação dos atalhos
        let isShortcutModeActive = false;
        let activationTimeout = null;
        let countdownInterval = null;
        let remainingSeconds = ${shortcutConfig.activationTime || 10};
        
        // Aliases locais para compatibilidade
        const shortcuts = window.__gerenciazapShortcuts;
        const keywords = window.__gerenciazapKeywords;
        const clipboardDomains = window.__gerenciazapClipboardDomains;
        
        // Verificar se o domínio atual usa modo clipboard
        const hostname = window.location.hostname;
        const useClipboardMode = clipboardDomains.some(d => hostname.includes(d));
        
        console.log('[GerenciaZap] Atalhos carregados:', Object.keys(shortcuts).length);
        console.log('[GerenciaZap] Keywords carregadas:', Object.keys(keywords).length);
        console.log('[GerenciaZap] Domínio atual:', hostname);
        console.log('[GerenciaZap] Modo clipboard:', useClipboardMode);
        console.log('[GerenciaZap] Tecla de ativação:', activationKey);
        console.log('[GerenciaZap] Tempo de ativação:', ACTIVATION_DURATION / 1000, 's');
        
        // Debounce para evitar notificações duplicadas
        let lastToastTime = 0;
        let lastToastCommand = '';
        const TOAST_DEBOUNCE_MS = 1000;
        
        // Container de notificações
        function createToastContainer() {
          let container = document.getElementById('gerenciazap-toast-container');
          if (!container) {
            container = document.createElement('div');
            container.id = 'gerenciazap-toast-container';
            container.style.cssText = \`
              position: fixed;
              bottom: 20px;
              right: 20px;
              z-index: 999999;
              display: flex;
              flex-direction: column;
              gap: 8px;
              pointer-events: none;
            \`;
            document.body.appendChild(container);
          }
          return container;
        }
        
        // Criar indicador de ativação
        function createActivationIndicator() {
          let indicator = document.getElementById('gerenciazap-activation-indicator');
          if (!indicator) {
            indicator = document.createElement('div');
            indicator.id = 'gerenciazap-activation-indicator';
            indicator.style.cssText = \`
              position: fixed;
              top: 10px;
              right: 10px;
              z-index: 999999;
              background: linear-gradient(135deg, hsl(120, 80%, 35%) 0%, hsl(120, 80%, 25%) 100%);
              color: white;
              padding: 8px 14px;
              border-radius: 20px;
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              font-size: 12px;
              font-weight: 600;
              box-shadow: 0 4px 12px rgba(0, 200, 0, 0.4);
              display: flex;
              align-items: center;
              gap: 6px;
              opacity: 0;
              transform: translateY(-10px);
              transition: all 0.2s ease;
              pointer-events: none;
            \`;
            indicator.innerHTML = \`
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
              </svg>
              <span>Atalhos Ativos</span>
            \`;
            document.body.appendChild(indicator);
          }
          return indicator;
        }
        
        // Mostrar/ocultar indicador de ativação
        function showActivationIndicator() {
          const indicator = createActivationIndicator();
          indicator.style.opacity = '1';
          indicator.style.transform = 'translateY(0)';
        }
        
        function hideActivationIndicator() {
          const indicator = document.getElementById('gerenciazap-activation-indicator');
          if (indicator) {
            indicator.style.opacity = '0';
            indicator.style.transform = 'translateY(-10px)';
          }
        }
        
        // Ativar modo de atalhos
        function activateShortcutMode() {
          if (isShortcutModeActive) {
            // Resetar timer se já está ativo
            clearTimeout(activationTimeout);
          } else {
            isShortcutModeActive = true;
            showActivationIndicator();
            console.log('__GERENCIAZAP_SHORTCUT_MODE__:ACTIVE');
            console.log('[GerenciaZap] Modo de atalhos ATIVADO');
          }
          
          // Desativar após o tempo limite
          activationTimeout = setTimeout(() => {
            deactivateShortcutMode();
          }, ACTIVATION_DURATION);
        }
        
        function deactivateShortcutMode() {
          isShortcutModeActive = false;
          hideActivationIndicator();
          clearTimeout(activationTimeout);
          console.log('__GERENCIAZAP_SHORTCUT_MODE__:INACTIVE');
          console.log('[GerenciaZap] Modo de atalhos DESATIVADO');
        }
        
        // Listener para tecla de ativação
        function handleActivationKey(e) {
          if (e.key === activationKey || e.code === activationKey) {
            activateShortcutMode();
          }
          // Escape desativa o modo
          if (e.key === 'Escape' && isShortcutModeActive) {
            deactivateShortcutMode();
          }
        }
        
        document.addEventListener('keydown', handleActivationKey, true);
        
        // Expor função de desativação para chamada externa
        window.__gerenciazapDeactivateShortcutMode = deactivateShortcutMode;
        
        // Cleanup function
        window.__gerenciazapActivationCleanup = () => {
          document.removeEventListener('keydown', handleActivationKey, true);
          hideActivationIndicator();
          clearTimeout(activationTimeout);
        };
        
        // Toast para modo automático (com debounce)
        function showShortcutToast(command) {
          const now = Date.now();
          if (command === lastToastCommand && now - lastToastTime < TOAST_DEBOUNCE_MS) {
            console.log('[GerenciaZap] Toast ignorado (debounce):', command);
            return;
          }
          lastToastTime = now;
          lastToastCommand = command;
          
          const container = createToastContainer();
          
          const toast = document.createElement('div');
          toast.style.cssText = \`
            background: linear-gradient(135deg, hsl(180, 100%, 25%) 0%, hsl(180, 100%, 18%) 100%);
            color: hsl(180, 100%, 95%);
            padding: 10px 16px;
            border-radius: 8px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 13px;
            box-shadow: 0 4px 12px rgba(0, 164, 164, 0.4);
            display: flex;
            align-items: center;
            gap: 8px;
            opacity: 0;
            transform: translateX(20px);
            transition: all 0.3s ease;
            pointer-events: auto;
          \`;
          
          toast.innerHTML = \`
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22 4 12 14.01 9 11.01"/>
            </svg>
            <span><strong>\${command}</strong> expandido</span>
          \`;
          
          container.appendChild(toast);
          requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateX(0)';
          });
          
          setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(20px)';
            setTimeout(() => toast.remove(), 300);
          }, 2500);
        }
        
        // Toast especial para modo clipboard (mostra temporariamente enquanto processa)
        function showClipboardToast(command) {
          const container = createToastContainer();
          
          const toast = document.createElement('div');
          toast.style.cssText = \`
            background: linear-gradient(135deg, #25D366 0%, #128C7E 100%);
            color: white;
            padding: 14px 20px;
            border-radius: 10px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 14px;
            box-shadow: 0 4px 16px rgba(37, 211, 102, 0.5);
            display: flex;
            align-items: center;
            gap: 10px;
            opacity: 0;
            transform: translateY(20px);
            transition: all 0.3s ease;
            pointer-events: auto;
          \`;
          
          toast.innerHTML = \`
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="animation: spin 1s linear infinite;">
              <style>@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }</style>
              <circle cx="12" cy="12" r="10" stroke-dasharray="31.4" stroke-dashoffset="10"/>
            </svg>
            <span><strong>\${command}</strong> processando...</span>
          \`;
          
          container.appendChild(toast);
          requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateY(0)';
          });
        }
        
        function getAutoKeywords() {
          const now = new Date();
          const hour = now.getHours();
          
          let greeting = 'Olá';
          if (hour >= 5 && hour < 12) greeting = 'Bom dia';
          else if (hour >= 12 && hour < 18) greeting = 'Boa tarde';
          else greeting = 'Boa noite';
          
          return {
            '<SAUDACAO>': greeting,
            '<DATA>': now.toLocaleDateString('pt-BR'),
            '<HORA>': now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
          };
        }
        
        function replaceKeywords(text) {
          let result = text;
          
          // Usar variáveis globais para pegar valores atualizados
          const currentKeywords = window.__gerenciazapKeywords || {};
          for (const [key, value] of Object.entries(currentKeywords)) {
            result = result.split(key).join(value);
          }
          
          const autoKeywords = getAutoKeywords();
          for (const [key, value] of Object.entries(autoKeywords)) {
            result = result.split(key).join(value);
          }
          
          return result;
        }
        
        async function processInput(element) {
          if (!element) return;
          
          // Verificar se o modo de atalhos está ativo
          if (!isShortcutModeActive) {
            return; // Não processar se a tecla de ativação não foi pressionada
          }
          
          let text = '';
          let isContentEditable = false;
          
          if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
            text = element.value;
          } else if (element.isContentEditable || element.contentEditable === 'true') {
            text = element.textContent || element.innerText || '';
            isContentEditable = true;
          } else {
            return;
          }
          
          // Usar variáveis globais para pegar valores atualizados
          const currentShortcuts = window.__gerenciazapShortcuts || {};
          const currentClipboardDomains = window.__gerenciazapClipboardDomains || [];
          const currentUseClipboardMode = currentClipboardDomains.some(d => hostname.includes(d));
          
           const textLower = text.toLowerCase();

           for (const [command, shortcutData] of Object.entries(currentShortcuts)) {
             const commandStr = String(command);
             const commandLower = commandStr.toLowerCase();
             if (!commandLower || !textLower.includes(commandLower)) continue;

             console.log('[GerenciaZap] Atalho encontrado:', commandStr);

             const messages = shortcutData.messages || [];
             if (messages.length === 0) continue;

             // MODO CLIPBOARD - para domínios configurados (WhatsApp, etc)
             if (currentUseClipboardMode && isContentEditable) {
               console.log('[GerenciaZap] Usando modo clipboard via IPC para:', hostname, 'com', messages.length, 'mensagens');

               // Enviar todas as mensagens via console.log para o React capturar
               console.log('__GERENCIAZAP_CLIPBOARD__:' + JSON.stringify({ 
                 messages: messages.map(m => ({
                   text: replaceKeywords(m.text).replace(/<ENTER>/g, '\\n'),
                   auto_send: m.auto_send
                 })),
                 command: commandStr 
               }));

               // Limpar o campo do comando
               element.focus();
               while (element.firstChild) {
                 element.removeChild(element.firstChild);
               }

               showClipboardToast(commandStr);
               return;
             }

             // MODO AUTOMÁTICO - para outros sites (usa primeira mensagem apenas)
             let replacement = replaceKeywords(messages[0].text);
             replacement = replacement.replace(/<ENTER>/g, '\\n');

             // Substituir o comando independente de maiúsculas/minúsculas
             var escapeRegex = new RegExp('[.*+?^' + String.fromCharCode(36) + '{}()|[\\\\]\\\\\\\\]', 'g');
             var escaped = commandStr.replace(escapeRegex, '\\\\' + String.fromCharCode(36) + '&');
             var commandRegex = new RegExp(escaped, 'gi');
             text = text.replace(commandRegex, function() { return replacement; });

             if (isContentEditable) {
               const spans = element.querySelectorAll('span');
               if (spans.length > 0) {
                 element.innerHTML = '';
                 const textNode = document.createTextNode(text);
                 element.appendChild(textNode);
               } else {
                 element.textContent = text;
               }

               const selection = window.getSelection();
               if (selection && element.childNodes.length > 0) {
                 const range = document.createRange();
                 range.selectNodeContents(element);
                 range.collapse(false);
                 selection.removeAllRanges();
                 selection.addRange(range);
               }

               element.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true }));
               showShortcutToast(commandStr);
             } else {
               const cursorPos = element.selectionStart;
               const diff = text.length - element.value.length;
               element.value = text;
               element.setSelectionRange(cursorPos + diff, cursorPos + diff);
               element.dispatchEvent(new Event('input', { bubbles: true }));
               showShortcutToast(commandStr);
             }

             element.dispatchEvent(new Event('change', { bubbles: true }));
             console.log('[GerenciaZap] Texto substituído com sucesso');
             break;
           }
        }
        
        if (window.__gerenciazapInputHandler) {
          document.removeEventListener('input', window.__gerenciazapInputHandler, true);
          document.removeEventListener('keyup', window.__gerenciazapKeyHandler, true);
        }
        
        window.__gerenciazapInputHandler = (e) => {
          clearTimeout(window.__gerenciazapDebounce);
          window.__gerenciazapDebounce = setTimeout(() => {
            processInput(e.target);
          }, 50);
        };
        
        window.__gerenciazapKeyHandler = (e) => {
          if (e.key === ' ' || e.key === 'Tab') {
            processInput(e.target);
          }
        };
        
        document.addEventListener('input', window.__gerenciazapInputHandler, true);
        document.addEventListener('keyup', window.__gerenciazapKeyHandler, true);
        
        console.log('[GerenciaZap] Listeners de atalhos registrados com sucesso');
        
        return 'ok';
      })();
    `;

    webview.executeJavaScript(script)
      .then((result: string) => {
        console.log('[GerenciaZap] Script injetado com sucesso:', result);
      })
      .catch((err: Error) => {
        console.error('[GerenciaZap] Erro ao injetar script:', err);
      });
  };

  // Salvar posição/zoom da janela no banco
  const saveWindowPosition = async () => {
    if (!user) return;
    
    const currentZoom = webviewStates[0]?.zoom || 100;
    
    const { error } = await supabase
      .from('tabs')
      .update({ zoom: currentZoom })
      .eq('id', tab.id);
    
    if (error) {
      console.error('[WebviewPanel] Erro ao salvar posição:', error);
      toast.error('Erro ao salvar posição');
    } else {
      toast.success('Posição e zoom salvos');
    }
  };

  // Componente de toolbar individual para cada webview
  const WebviewToolbar = ({ index }: { index: number }) => {
    const state = webviewStates[index] || { currentUrl: '', zoom: 100 };
    
    return (
      <div className="flex items-center gap-1 px-2 py-1 border-b bg-muted/30 text-xs">
        <div className="flex items-center gap-0.5">
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleBack(index)}>
            <ArrowLeft className="h-3 w-3" />
          </Button>
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleForward(index)}>
            <ArrowRight className="h-3 w-3" />
          </Button>
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleRefresh(index)}>
            {loading[index] ? <Loader2 className="h-3 w-3 animate-spin" /> : <RotateCw className="h-3 w-3" />}
          </Button>
        </div>

        <form onSubmit={(e) => handleUrlSubmit(e, index)} className="flex-1">
          <Input
            value={state.currentUrl}
            onChange={(e) => updateWebviewState(index, { currentUrl: e.target.value })}
            placeholder="URL..."
            className="h-6 text-xs px-2"
          />
        </form>

        <div className="flex items-center gap-0.5">
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleZoomOut(index)}>
            <ZoomOut className="h-3 w-3" />
          </Button>
          <span className="w-8 text-center text-[10px]">{state.zoom}%</span>
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleZoomIn(index)}>
            <ZoomIn className="h-3 w-3" />
          </Button>
        </div>

        <Button 
          variant="ghost" 
          size="icon" 
          className="h-6 w-6" 
          onClick={saveWindowPosition}
          title="Salvar posição e zoom"
        >
          <Save className="h-3 w-3" />
        </Button>

        <DownloadsPopover />

        {onEditTab && (
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={onEditTab} title="Configurações da aba">
            <Settings className="h-3 w-3" />
          </Button>
        )}

        <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleDownload(index)}>
          <ExternalLink className="h-3 w-3" />
        </Button>

        <Button variant="ghost" size="icon" className="h-6 w-6" onClick={onClose}>
          <X className="h-3 w-3" />
        </Button>
      </div>
    );
  };

  // Mapear tecla de ativação para label legível
  const activationKeyLabel = (() => {
    const key = shortcutConfig?.activationKey || 'Control';
    const map: Record<string, string> = { Control: 'Ctrl', Alt: 'Alt', Shift: 'Shift', Meta: 'Win' };
    return map[key] || key;
  })();

  return (
    <div className="h-full flex flex-col bg-background relative">
      {/* Indicador de modo atalho ativo - visível na UI principal */}
      {shortcutModeActive && (
        <div className="fixed top-3 left-1/2 -translate-x-1/2 z-[99999] animate-in fade-in slide-in-from-top-2 duration-200">
          <button
            type="button"
            onClick={() => {
              setShortcutModeActive(false);
              // Enviar comando para desativar no webview também
              webviewRefs.current.forEach((wv) => {
                if (wv && typeof (wv as any).executeJavaScript === 'function') {
                  (wv as any).executeJavaScript(`
                    if (window.__gerenciazapDeactivateShortcutMode) {
                      window.__gerenciazapDeactivateShortcutMode();
                    }
                  `).catch(() => {});
                }
              });
            }}
            className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary text-primary-foreground text-xs font-semibold shadow-lg shadow-primary/30 ring-1 ring-primary/20 hover:bg-primary/90 transition-colors"
            title="Clique para desativar (ou pressione Esc)"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
            </svg>
            <span>Modo Atalho • {activationKeyLabel}</span>
            <X className="h-3 w-3 ml-1 opacity-70" />
          </button>
        </div>
      )}

      {/* Botão para mostrar/ocultar toolbars */}
      <Button
        variant="ghost"
        size="icon"
        className="absolute top-1 left-1 z-10 h-6 w-6 bg-background/80 hover:bg-background"
        onClick={() => setShowToolbars(!showToolbars)}
        title={showToolbars ? "Ocultar barra de ferramentas" : "Mostrar barra de ferramentas (zoom, navegação)"}
      >
        {showToolbars ? <ChevronUp className="h-3 w-3" /> : <SlidersHorizontal className="h-3 w-3" />}
      </Button>

      {/* Container de webviews - com painéis redimensionáveis */}
      {isResizableLayout ? (
        <ResizablePanelGroup 
          direction={resizeDirection} 
          className="flex-1"
          onLayout={handleLayoutChange}
        >
          {Array.from({ length: webviewCount }).flatMap((_, index) => {
            const urlData = urls[index] || urls[0];
            // Usar tamanho salvo ou calcular padrão
            const savedSize = panelSizes[index];
            const defaultSize = savedSize !== undefined ? savedSize : (100 / webviewCount);
            const elements = [
              <ResizablePanel key={`panel-${index}`} defaultSize={defaultSize} minSize={15}>
                <div className="h-full relative bg-white flex flex-col overflow-hidden">
                  {/* Toolbar individual - só aparece quando showToolbars = true */}
                  {showToolbars && <WebviewToolbar index={index} />}
                  
                  {/* Webview */}
                  <div className="flex-1 relative">
                    {/* eslint-disable-next-line */}
                    {/* @ts-ignore - webview é uma tag especial do Electron */}
                    <webview
                      key={`wv-${tab.id}-${index}-${getPartition(index)}`}
                      ref={(el) => {
                        if (el) webviewRefs.current[index] = el;
                      }}
                      src={urlData.url}
                      style={{ width: '100%', height: '100%' }}
                      partition={getPartition(index)}
                      useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                    />
                  </div>
                </div>
              </ResizablePanel>
            ];
            
            // Adicionar handle entre painéis (não depois do último)
            if (index < webviewCount - 1) {
              elements.push(<ResizableHandle key={`handle-${index}`} withHandle />);
            }
            
            return elements;
          })}
        </ResizablePanelGroup>
      ) : (
        /* Layout single - sem resize */
        <div className="flex-1">
          {(() => {
            const urlData = urls[0] || { url: tab.url, zoom: tab.zoom || 100 };
            return (
              <div className="h-full relative bg-white flex flex-col overflow-hidden">
                {showToolbars && <WebviewToolbar index={0} />}
                <div className="flex-1 relative">
                  {/* eslint-disable-next-line */}
                  {/* @ts-ignore - webview é uma tag especial do Electron */}
                  <webview
                    key={`wv-${tab.id}-0-${getPartition(0)}`}
                    ref={(el) => {
                      if (el) webviewRefs.current[0] = el;
                    }}
                    src={urlData.url}
                    style={{ width: '100%', height: '100%' }}
                    partition={getPartition(0)}
                    useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                  />
                </div>
              </div>
            );
          })()}
        </div>
      )}
      
      {/* Dialog para salvar credenciais */}
      <SaveCredentialDialog />
      
      {/* Menu de contexto para links */}
      {contextMenu?.visible && (
        <WebviewContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          url={contextMenu.url}
          onOpenFloating={() => {
            window.electronAPI?.createWindow?.({ 
              id: `link-${Date.now()}`, 
              url: contextMenu.url, 
              name: 'Link' 
            });
            setContextMenu(null);
          }}
          onOpenBrowser={() => {
            openExternal(contextMenu.url);
            setContextMenu(null);
          }}
          onCopyLink={async () => {
            await navigator.clipboard.writeText(contextMenu.url);
            toast.success('Link copiado!');
            setContextMenu(null);
          }}
          onClose={() => setContextMenu(null)}
        />
      )}
    </div>
  );
}

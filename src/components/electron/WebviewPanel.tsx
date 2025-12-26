import { useEffect, useRef, useState } from 'react';
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
  SlidersHorizontal
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useElectron, ElectronAPI } from '@/hooks/useElectron';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';

interface TabUrl {
  url: string;
  shortcut_enabled?: boolean;
  zoom?: number;
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
  };
  textShortcuts?: { command: string; expanded_text: string }[];
  keywords?: { key: string; value: string }[];
  onClose: () => void;
}

type LayoutType = 'single' | '2x1' | '1x2' | '2x2' | '3x1' | '1x3';

export function WebviewPanel({ tab, textShortcuts = [], keywords = [], onClose }: WebviewPanelProps) {
  const { user } = useAuth();
  const { isElectron, openExternal } = useElectron();
  const [loading, setLoading] = useState<boolean[]>([]);
  const [showToolbars, setShowToolbars] = useState(false);
  const [clipboardDomains, setClipboardDomains] = useState<string[]>(['whatsapp.com']);
  const webviewRefs = useRef<HTMLElement[]>([]);

  const layout = (tab.layout_type as LayoutType) || 'single';

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

  // Extrair URLs com informação de atalhos habilitados
  const urls: { url: string; zoom: number; shortcut_enabled: boolean }[] = [];
  if (tab.urls && tab.urls.length > 0) {
    tab.urls.forEach((item) => {
      if (typeof item === 'string') {
        urls.push({ url: item, zoom: tab.zoom || 100, shortcut_enabled: true });
      } else if (item && typeof item === 'object' && item.url) {
        urls.push({ 
          url: item.url, 
          zoom: item.zoom || tab.zoom || 100, 
          shortcut_enabled: item.shortcut_enabled !== false // default true
        });
      }
    });
  }
  if (urls.length === 0) {
    urls.push({ url: tab.url, zoom: tab.zoom || 100, shortcut_enabled: true });
  }

  // Estado individual de URL e zoom para cada webview
  const [webviewStates, setWebviewStates] = useState(
    urls.map(u => ({ currentUrl: u.url, zoom: u.zoom }))
  );

  // Número de webviews baseado no layout
  const webviewCount = layout === 'single' ? 1 :
    layout === '2x1' || layout === '1x2' ? 2 :
    layout === '2x2' ? 4 :
    layout === '3x1' || layout === '1x3' ? 3 : 1;

  // Inicializar loading states
  useEffect(() => {
    setLoading(Array(webviewCount).fill(true));
  }, [webviewCount]);

  // Registrar event listeners manualmente para o webview
  useEffect(() => {
    if (!isElectron) return;

    const cleanupFunctions: (() => void)[] = [];

    // Aguardar os webviews estarem disponíveis
    const timeout = setTimeout(() => {
      webviewRefs.current.forEach((webview, index) => {
        if (!webview) {
          console.log(`[GerenciaZap] Webview ${index} não disponível`);
          return;
        }

        console.log(`[GerenciaZap] Registrando eventos para webview ${index}`);

        const handleDomReady = () => {
          console.log(`[GerenciaZap] dom-ready disparado para webview ${index}`);
          injectShortcuts(webview, index);
        };

        const handleDidStartLoading = () => {
          console.log(`[GerenciaZap] did-start-loading disparado para webview ${index}`);
          setLoadingForIndex(index, true);
        };

        const handleDidStopLoading = () => {
          console.log(`[GerenciaZap] did-stop-loading disparado para webview ${index}`);
          setLoadingForIndex(index, false);
          
          // Aplicar zoom se necessário
          const urlData = urls[index] || urls[0];
          if (urlData.zoom !== 100 && (webview as any).setZoomFactor) {
            (webview as any).setZoomFactor(urlData.zoom / 100);
          }
          
          injectShortcuts(webview, index);
        };

        const handleDidNavigate = (e: any) => {
          console.log(`[GerenciaZap] did-navigate disparado para webview ${index}`, e?.url);
          if (e?.url) {
            updateWebviewState(index, { currentUrl: e.url });
          }
        };

        // Handler para mensagens do console - captura clipboard IPC
        const handleConsoleMessage = async (e: any) => {
          const message = e?.message || '';
          
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
                  if (wv && typeof (wv as any).sendInputEvent === 'function') {
                    console.log('[GerenciaZap] Simulando Enter...');
                    (wv as any).sendInputEvent({ type: 'keyDown', keyCode: 'Return' });
                    (wv as any).sendInputEvent({ type: 'keyUp', keyCode: 'Return' });
                    await new Promise(r => setTimeout(r, 100));
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
                
                // Verificar se o texto contém <ENTER>
                const hasEnter = data.text.includes('<ENTER>');
                
                if (hasEnter) {
                  // Dividir o texto pelo primeiro <ENTER>
                  const parts = data.text.split('<ENTER>');
                  const textToSend = parts[0].replace(/\\n$/, '').trim();
                  const textToKeep = parts.slice(1).join('<ENTER>').replace(/^\\n/, '').trim();
                  
                  // Substituir \n por quebras de linha reais
                  const textToSendClean = textToSend.replace(/\\n/g, '\n');
                  const textToKeepClean = textToKeep.replace(/\\n/g, '\n');
                  
                  console.log('[GerenciaZap] Modo <ENTER> detectado');
                  console.log('[GerenciaZap] Texto para enviar:', textToSendClean);
                  console.log('[GerenciaZap] Texto para manter:', textToKeepClean);
                  
                  // 1. Copiar primeira parte e colar
                  const result1 = await api.writeToClipboard(textToSendClean);
                  if (result1.success) {
                    await new Promise(r => setTimeout(r, 50));
                    await sendCtrlA();
                    await sendCtrlV();
                    
                    // 2. Simular Enter para enviar
                    await new Promise(r => setTimeout(r, 100));
                    await sendEnter();
                    
                    // 3. Se tiver texto para manter, copiar e colar
                    if (textToKeepClean) {
                      await new Promise(r => setTimeout(r, 200));
                      const result2 = await api.writeToClipboard(textToKeepClean);
                      if (result2.success) {
                        await sendCtrlV();
                      }
                    }
                    
                    // 4. Mostrar toast "enviado"
                    setTimeout(() => {
                      showToast(`<strong>${data.command}</strong> enviado!`);
                    }, 100);
                  }
                } else {
                  // Comportamento normal: apenas expandir sem enviar
                  // Substituir \n por quebras reais
                  const cleanText = data.text.replace(/\\n/g, '\n');
                  
                  const result = await api.writeToClipboard(cleanText);
                  if (result.success) {
                    console.log('[GerenciaZap] Texto copiado para clipboard com sucesso!');
                    
                    if (wv && typeof (wv as any).sendInputEvent === 'function') {
                      await new Promise(r => setTimeout(r, 50));
                      await sendCtrlA();
                      await sendCtrlV();
                      
                      // Atualizar o toast no webview para "expandido"
                      setTimeout(() => {
                        showToast(`<strong>${data.command}</strong> expandido!`);
                      }, 100);
                    }
                  } else {
                    console.error('[GerenciaZap] Falha ao copiar:', result.error);
                  }
                }
              } else {
                console.error('[GerenciaZap] writeToClipboard não disponível');
              }
            } catch (err) {
              console.error('[GerenciaZap] Erro ao processar mensagem de clipboard:', err);
            }
          }
        };

        webview.addEventListener('dom-ready', handleDomReady);
        webview.addEventListener('did-start-loading', handleDidStartLoading);
        webview.addEventListener('did-stop-loading', handleDidStopLoading);
        webview.addEventListener('did-navigate', handleDidNavigate);
        webview.addEventListener('console-message', handleConsoleMessage);

        cleanupFunctions.push(() => {
          webview.removeEventListener('dom-ready', handleDomReady);
          webview.removeEventListener('did-start-loading', handleDidStartLoading);
          webview.removeEventListener('did-stop-loading', handleDidStopLoading);
          webview.removeEventListener('did-navigate', handleDidNavigate);
          webview.removeEventListener('console-message', handleConsoleMessage);
        });
      });
    }, 100);

    return () => {
      clearTimeout(timeout);
      cleanupFunctions.forEach(fn => fn());
    };
  }, [isElectron, urls, textShortcuts, keywords]);

  // Se não está no Electron, mostrar iframe ou mensagem
  if (!isElectron) {
    return (
      <div className="h-full flex flex-col bg-background">
        <div className="flex items-center gap-2 p-2 border-b bg-muted/50">
          <div 
            className="w-8 h-8 rounded flex items-center justify-center text-white shrink-0"
            style={{ backgroundColor: tab.color || '#00a4a4' }}
          >
            {tab.icon || '🌐'}
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

  // Renderizar webviews no Electron
  const layoutClass = cn(
    "flex-1 grid gap-0",
    layout === 'single' && "grid-cols-1",
    layout === '2x1' && "grid-cols-2",
    layout === '1x2' && "grid-rows-2",
    layout === '2x2' && "grid-cols-2 grid-rows-2",
    layout === '3x1' && "grid-cols-3",
    layout === '1x3' && "grid-rows-3"
  );

  const updateWebviewState = (index: number, updates: Partial<{ currentUrl: string; zoom: number }>) => {
    setWebviewStates(prev => {
      const newStates = [...prev];
      newStates[index] = { ...newStates[index], ...updates };
      return newStates;
    });
  };

  const handleZoomIn = (index: number) => {
    const newZoom = Math.min((webviewStates[index]?.zoom || 100) + 10, 200);
    updateWebviewState(index, { zoom: newZoom });
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).setZoomFactor) {
      (wv as any).setZoomFactor(newZoom / 100);
    }
  };

  const handleZoomOut = (index: number) => {
    const newZoom = Math.max((webviewStates[index]?.zoom || 100) - 10, 50);
    updateWebviewState(index, { zoom: newZoom });
    const wv = webviewRefs.current[index];
    if (wv && (wv as any).setZoomFactor) {
      (wv as any).setZoomFactor(newZoom / 100);
    }
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
    
    console.log('[GerenciaZap] injectShortcuts chamado, textShortcuts:', textShortcuts.length, 'keywords:', keywords.length);
    console.log('[GerenciaZap] Domínios com clipboard mode:', clipboardDomains);
    
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

    const shortcutsMap: Record<string, string> = {};
    textShortcuts.forEach(s => {
      shortcutsMap[s.command] = s.expanded_text;
    });

    const keywordsMap: Record<string, string> = {};
    keywords.forEach(k => {
      keywordsMap[`<${k.key}>`] = k.value;
    });

    console.log('[GerenciaZap] Mapa de atalhos:', JSON.stringify(shortcutsMap));
    console.log('[GerenciaZap] Mapa de keywords:', JSON.stringify(keywordsMap));

    const script = `
      (function() {
        if (window.__gerenciazapInjected) {
          console.log('[GerenciaZap] Atualizando atalhos...');
        }
        window.__gerenciazapInjected = true;
        
        const shortcuts = ${JSON.stringify(shortcutsMap)};
        const keywords = ${JSON.stringify(keywordsMap)};
        const clipboardDomains = ${JSON.stringify(clipboardDomains)};
        
        // Verificar se o domínio atual usa modo clipboard
        const hostname = window.location.hostname;
        const useClipboardMode = clipboardDomains.some(d => hostname.includes(d));
        
        console.log('[GerenciaZap] Atalhos carregados:', Object.keys(shortcuts).length);
        console.log('[GerenciaZap] Keywords carregadas:', Object.keys(keywords).length);
        console.log('[GerenciaZap] Domínio atual:', hostname);
        console.log('[GerenciaZap] Modo clipboard:', useClipboardMode);
        
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
          
          for (const [key, value] of Object.entries(keywords)) {
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
          
          for (const [command, expandedText] of Object.entries(shortcuts)) {
            if (text.includes(command)) {
              console.log('[GerenciaZap] Atalho encontrado:', command);
              let replacement = replaceKeywords(expandedText);
              replacement = replacement.replace(/<ENTER>/g, '\\n');
              
              // MODO CLIPBOARD - para domínios configurados (WhatsApp, etc)
              // Envia mensagem via console.log para o React capturar e copiar via IPC
              if (useClipboardMode && isContentEditable) {
                console.log('[GerenciaZap] Usando modo clipboard via IPC para:', hostname);
                
                // Enviar dados via console.log com prefixo especial para o React
                console.log('__GERENCIAZAP_CLIPBOARD__:' + JSON.stringify({ 
                  text: replacement, 
                  command: command 
                }));
                
                // Limpar o campo do comando
                element.focus();
                while (element.firstChild) {
                  element.removeChild(element.firstChild);
                }
                
                // Mostrar toast de "copiado" (o React vai copiar para clipboard)
                showClipboardToast(command);
                
                return;
              }
              
              // MODO AUTOMÁTICO - para outros sites
              text = text.split(command).join(replacement);
              
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
                showShortcutToast(command);
              } else {
                const cursorPos = element.selectionStart;
                const diff = text.length - element.value.length;
                element.value = text;
                element.setSelectionRange(cursorPos + diff, cursorPos + diff);
                element.dispatchEvent(new Event('input', { bubbles: true }));
                showShortcutToast(command);
              }
              
              element.dispatchEvent(new Event('change', { bubbles: true }));
              console.log('[GerenciaZap] Texto substituído com sucesso');
              break;
            }
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

        <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => handleDownload(index)}>
          <ExternalLink className="h-3 w-3" />
        </Button>

        <Button variant="ghost" size="icon" className="h-6 w-6" onClick={onClose}>
          <X className="h-3 w-3" />
        </Button>
      </div>
    );
  };

  return (
    <div className="h-full flex flex-col bg-background relative">
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

      {/* Container de webviews */}
      <div className={layoutClass}>
        {Array.from({ length: webviewCount }).map((_, index) => {
          const urlData = urls[index] || urls[0];
          return (
            <div key={index} className="relative bg-white flex flex-col overflow-hidden">
              {/* Toolbar individual - só aparece quando showToolbars = true */}
              {showToolbars && <WebviewToolbar index={index} />}
              
              {/* Webview */}
              <div className="flex-1 relative">
              {/* eslint-disable-next-line */}
              {/* @ts-ignore - webview é uma tag especial do Electron */}
              <webview
                ref={(el) => {
                  if (el) webviewRefs.current[index] = el;
                }}
                src={urlData.url}
                style={{ width: '100%', height: '100%' }}
                partition={`persist:tab-${tab.id}`}
                useragent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
              />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

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
  ChevronDown,
  ChevronUp,
  Settings2
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useElectron } from '@/hooks/useElectron';

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
  const { isElectron, openExternal } = useElectron();
  const [loading, setLoading] = useState<boolean[]>([]);
  const [showToolbars, setShowToolbars] = useState(false);
  const webviewRefs = useRef<HTMLElement[]>([]);

  const layout = (tab.layout_type as LayoutType) || 'single';

  // Extrair URLs
  const urls: { url: string; zoom: number }[] = [];
  if (tab.urls && tab.urls.length > 0) {
    tab.urls.forEach((item) => {
      if (typeof item === 'string') {
        urls.push({ url: item, zoom: tab.zoom || 100 });
      } else if (item && typeof item === 'object' && item.url) {
        urls.push({ url: item.url, zoom: item.zoom || tab.zoom || 100 });
      }
    });
  }
  if (urls.length === 0) {
    urls.push({ url: tab.url, zoom: tab.zoom || 100 });
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
          injectShortcuts(webview);
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
          
          injectShortcuts(webview);
        };

        const handleDidNavigate = (e: any) => {
          console.log(`[GerenciaZap] did-navigate disparado para webview ${index}`, e?.url);
          if (e?.url) {
            updateWebviewState(index, { currentUrl: e.url });
          }
        };

        webview.addEventListener('dom-ready', handleDomReady);
        webview.addEventListener('did-start-loading', handleDidStartLoading);
        webview.addEventListener('did-stop-loading', handleDidStopLoading);
        webview.addEventListener('did-navigate', handleDidNavigate);

        cleanupFunctions.push(() => {
          webview.removeEventListener('dom-ready', handleDomReady);
          webview.removeEventListener('did-start-loading', handleDidStartLoading);
          webview.removeEventListener('did-stop-loading', handleDidStopLoading);
          webview.removeEventListener('did-navigate', handleDidNavigate);
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
  const injectShortcuts = (webview: any) => {
    console.log('[GerenciaZap] injectShortcuts chamado, textShortcuts:', textShortcuts.length, 'keywords:', keywords.length);
    
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
          injectShortcuts(webview);
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
        // Remover injeção anterior para atualizar
        if (window.__gerenciazapInjected) {
          console.log('[GerenciaZap] Atualizando atalhos...');
        }
        window.__gerenciazapInjected = true;
        
        const shortcuts = ${JSON.stringify(shortcutsMap)};
        const keywords = ${JSON.stringify(keywordsMap)};
        
        console.log('[GerenciaZap] Atalhos carregados:', Object.keys(shortcuts).length);
        console.log('[GerenciaZap] Keywords carregadas:', Object.keys(keywords).length);
        
        function replaceKeywords(text) {
          let result = text;
          for (const [key, value] of Object.entries(keywords)) {
            result = result.split(key).join(value);
          }
          return result;
        }
        
        function processInput(element) {
          if (!element) return;
          let text = '';
          let isContentEditable = false;
          
          if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
            text = element.value;
          } else if (element.isContentEditable) {
            text = element.textContent || element.innerText || '';
            isContentEditable = true;
          } else {
            return;
          }
          
          for (const [command, expandedText] of Object.entries(shortcuts)) {
            if (text.includes(command)) {
              console.log('[GerenciaZap] Atalho encontrado:', command);
              let replacement = replaceKeywords(expandedText);
              text = text.split(command).join(replacement);
              
              if (isContentEditable) {
                // Para contentEditable, precisamos usar execCommand ou manipular diretamente
                const selection = window.getSelection();
                const range = selection?.getRangeAt(0);
                
                // Salvar posição do cursor
                element.textContent = text;
                
                // Mover cursor para o final
                if (selection && element.firstChild) {
                  const newRange = document.createRange();
                  newRange.selectNodeContents(element);
                  newRange.collapse(false);
                  selection.removeAllRanges();
                  selection.addRange(newRange);
                }
              } else {
                const cursorPos = element.selectionStart;
                const diff = replacement.length - command.length;
                element.value = text;
                // Restaurar posição do cursor
                element.setSelectionRange(cursorPos + diff, cursorPos + diff);
              }
              
              // Disparar eventos para frameworks React/Vue/Angular
              element.dispatchEvent(new Event('input', { bubbles: true }));
              element.dispatchEvent(new Event('change', { bubbles: true }));
              
              console.log('[GerenciaZap] Texto substituído com sucesso');
            }
          }
        }
        
        // Remover listeners antigos se existirem
        if (window.__gerenciazapInputHandler) {
          document.removeEventListener('input', window.__gerenciazapInputHandler, true);
          document.removeEventListener('keyup', window.__gerenciazapKeyHandler, true);
        }
        
        // Criar handlers
        window.__gerenciazapInputHandler = (e) => processInput(e.target);
        window.__gerenciazapKeyHandler = (e) => {
          if (e.key === ' ' || e.key === 'Enter' || e.key === 'Tab') {
            processInput(e.target);
          }
        };
        
        // Adicionar listeners
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
      >
        {showToolbars ? <ChevronUp className="h-3 w-3" /> : <Settings2 className="h-3 w-3" />}
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

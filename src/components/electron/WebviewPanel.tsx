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
  Loader2
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
  const [currentUrl, setCurrentUrl] = useState(tab.url);
  const [zoom, setZoom] = useState(tab.zoom || 100);
  const [loading, setLoading] = useState(true);
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

  // Número de webviews baseado no layout
  const webviewCount = layout === 'single' ? 1 :
    layout === '2x1' || layout === '1x2' ? 2 :
    layout === '2x2' ? 4 :
    layout === '3x1' || layout === '1x3' ? 3 : 1;

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
    "flex-1 grid gap-1 p-1",
    layout === 'single' && "grid-cols-1",
    layout === '2x1' && "grid-cols-2",
    layout === '1x2' && "grid-rows-2",
    layout === '2x2' && "grid-cols-2 grid-rows-2",
    layout === '3x1' && "grid-cols-3",
    layout === '1x3' && "grid-rows-3"
  );

  const handleZoomIn = () => {
    const newZoom = Math.min(zoom + 10, 200);
    setZoom(newZoom);
    webviewRefs.current.forEach(wv => {
      if (wv && (wv as any).setZoomFactor) {
        (wv as any).setZoomFactor(newZoom / 100);
      }
    });
  };

  const handleZoomOut = () => {
    const newZoom = Math.max(zoom - 10, 50);
    setZoom(newZoom);
    webviewRefs.current.forEach(wv => {
      if (wv && (wv as any).setZoomFactor) {
        (wv as any).setZoomFactor(newZoom / 100);
      }
    });
  };

  const handleBack = () => {
    const wv = webviewRefs.current[0];
    if (wv && (wv as any).goBack) {
      (wv as any).goBack();
    }
  };

  const handleForward = () => {
    const wv = webviewRefs.current[0];
    if (wv && (wv as any).goForward) {
      (wv as any).goForward();
    }
  };

  const handleRefresh = () => {
    webviewRefs.current.forEach(wv => {
      if (wv && (wv as any).reload) {
        (wv as any).reload();
      }
    });
  };

  const handleUrlSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const wv = webviewRefs.current[0];
    if (wv && (wv as any).loadURL) {
      let url = currentUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url;
      }
      (wv as any).loadURL(url);
    }
  };

  // Injetar script de atalhos
  const injectShortcuts = (webview: any) => {
    if (!webview || typeof webview.executeJavaScript !== 'function') return;

    const shortcutsMap: Record<string, string> = {};
    textShortcuts.forEach(s => {
      shortcutsMap[s.command] = s.expanded_text;
    });

    const keywordsMap: Record<string, string> = {};
    keywords.forEach(k => {
      keywordsMap[`<${k.key}>`] = k.value;
    });

    const script = `
      (function() {
        if (window.__gerenciazapInjected) return;
        window.__gerenciazapInjected = true;
        
        const shortcuts = ${JSON.stringify(shortcutsMap)};
        const keywords = ${JSON.stringify(keywordsMap)};
        
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
            text = element.textContent || '';
            isContentEditable = true;
          } else {
            return;
          }
          
          for (const [command, expandedText] of Object.entries(shortcuts)) {
            if (text.includes(command)) {
              let replacement = replaceKeywords(expandedText);
              text = text.split(command).join(replacement);
              
              if (isContentEditable) {
                element.textContent = text;
                const range = document.createRange();
                const sel = window.getSelection();
                range.selectNodeContents(element);
                range.collapse(false);
                sel.removeAllRanges();
                sel.addRange(range);
              } else {
                element.value = text;
              }
              element.dispatchEvent(new Event('input', { bubbles: true }));
            }
          }
        }
        
        document.addEventListener('input', (e) => processInput(e.target), true);
        document.addEventListener('keyup', (e) => {
          if (e.key === ' ' || e.key === 'Enter') processInput(e.target);
        }, true);
      })();
    `;

    webview.executeJavaScript(script).catch(() => {});
  };

  return (
    <div className="h-full flex flex-col bg-background">
      {/* Barra de navegação */}
      <div className="flex items-center gap-2 p-2 border-b bg-muted/50">
        <div 
          className="w-8 h-8 rounded flex items-center justify-center text-white shrink-0"
          style={{ backgroundColor: tab.color || '#00a4a4' }}
        >
          {tab.icon || '🌐'}
        </div>
        <span className="font-medium truncate max-w-[150px]">{tab.name}</span>

        <div className="flex items-center gap-1">
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleBack}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleForward}>
            <ArrowRight className="h-4 w-4" />
          </Button>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleRefresh}>
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RotateCw className="h-4 w-4" />}
          </Button>
        </div>

        <form onSubmit={handleUrlSubmit} className="flex-1 max-w-xl">
          <Input
            value={currentUrl}
            onChange={(e) => setCurrentUrl(e.target.value)}
            placeholder="Digite a URL..."
            className="h-8 text-sm"
          />
        </form>

        <div className="flex items-center gap-1">
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleZoomOut}>
            <ZoomOut className="h-4 w-4" />
          </Button>
          <span className="text-xs w-10 text-center">{zoom}%</span>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={handleZoomIn}>
            <ZoomIn className="h-4 w-4" />
          </Button>
        </div>

        <Button variant="ghost" size="icon" className="h-8 w-8" onClick={onClose}>
          <X className="h-4 w-4" />
        </Button>
      </div>

      {/* Container de webviews */}
      <div className={layoutClass}>
        {Array.from({ length: webviewCount }).map((_, index) => {
          const urlData = urls[index] || urls[0];
          return (
            <div key={index} className="relative bg-white rounded overflow-hidden">
              {/* eslint-disable-next-line */}
              {/* @ts-ignore - webview é uma tag especial do Electron */}
              <webview
                ref={(el) => {
                  if (el) webviewRefs.current[index] = el;
                }}
                src={urlData.url}
                style={{ width: '100%', height: '100%' }}
                partition={`persist:tab-${tab.id}`}
                // @ts-ignore
                onDidStartLoading={() => index === 0 && setLoading(true)}
                // @ts-ignore
                onDidStopLoading={() => {
                  if (index === 0) setLoading(false);
                  const wv = webviewRefs.current[index];
                  if (wv) {
                    if (urlData.zoom !== 100 && (wv as any).setZoomFactor) {
                      (wv as any).setZoomFactor(urlData.zoom / 100);
                    }
                    injectShortcuts(wv);
                  }
                }}
                // @ts-ignore
                onDidNavigate={(e: any) => {
                  if (index === 0 && e?.url) setCurrentUrl(e.url);
                }}
                // @ts-ignore
                onDomReady={() => {
                  const wv = webviewRefs.current[index];
                  if (wv) injectShortcuts(wv);
                }}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
}

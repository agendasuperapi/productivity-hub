import { useState, useEffect, useCallback, useRef } from 'react';
import { Download, FolderOpen, AppWindow, ExternalLink } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useElectron, DownloadItem } from '@/hooks/useElectron';
import { useLocalSettings, PdfOpenMode } from '@/hooks/useLocalSettings';
import { cn } from '@/lib/utils';

export function DownloadsPopover() {
  const {
    isElectron,
    getRecentDownloads,
    openDownloadedFile,
    showInFolder,
    onDownloadCompleted,
    removeAllListeners,
    createWindow,
  } = useElectron();
  const { settings: localSettings } = useLocalSettings();
  const [downloads, setDownloads] = useState<DownloadItem[]>([]);
  const [hasNewDownload, setHasNewDownload] = useState(false);
  const [open, setOpen] = useState(false);

  // Usar ref para sempre ter o valor mais atual das configurações
  const pdfOpenModeRef = useRef<PdfOpenMode>(localSettings.pdf_open_mode);

  // Atualizar ref quando settings mudam
  useEffect(() => {
    pdfOpenModeRef.current = localSettings.pdf_open_mode;
  }, [localSettings.pdf_open_mode]);

  // Verifica se é um arquivo PDF
  const isPdfFile = useCallback((filename: string) => {
    return filename.toLowerCase().endsWith('.pdf');
  }, []);

  const toFileUrl = useCallback((filePath: string) => {
    // Windows: "C:\\Users\\...\\file.pdf" -> "file:///C:/Users/.../file.pdf"
    // Unix: "/home/.../file.pdf" -> "file:///home/.../file.pdf"
    if (/^file:\/\//i.test(filePath)) return filePath;

    const normalized = filePath.replace(/\\/g, '/');

    // Windows drive letter
    if (/^[a-zA-Z]:\//.test(normalized)) {
      return `file:///${encodeURI(normalized)}`;
    }

    // Absolute unix path
    if (normalized.startsWith('/')) {
      return `file://${encodeURI(normalized)}`;
    }

    // Fallback
    return `file:///${encodeURI(normalized)}`;
  }, []);

  const openDownloadInAppWindow = useCallback(
    async (download: DownloadItem) => {
      console.log('[DownloadsPopover] openDownloadInAppWindow chamado');
      console.log('[DownloadsPopover] -> filename:', download.filename);
      console.log('[DownloadsPopover] -> path:', download.path);
      
      const fileUrl = toFileUrl(download.path);
      console.log('[DownloadsPopover] -> fileUrl gerado:', fileUrl);
      
      const windowConfig = {
        id: `pdf-${Date.now()}`,
        name: download.filename,
        url: fileUrl,
        window_width: 900,
        window_height: 700,
        zoom: 100,
      };
      console.log('[DownloadsPopover] -> windowConfig:', JSON.stringify(windowConfig));
      
      const result = await createWindow(windowConfig);
      console.log('[DownloadsPopover] -> createWindow result:', JSON.stringify(result));

      if (!result?.success) {
        console.error('[DownloadsPopover] Falha ao abrir na janela do app:', result?.error);
        toast.error(result?.error || 'Não foi possível abrir o PDF na janela do app');
      } else {
        console.log('[DownloadsPopover] Janela criada com sucesso');
      }
    },
    [createWindow, toFileUrl]
  );

  const openInSystem = useCallback(
    async (download: DownloadItem) => {
      console.log('[DownloadsPopover] openInSystem chamado');
      console.log('[DownloadsPopover] -> filename:', download.filename);
      console.log('[DownloadsPopover] -> path:', download.path);
      
      const result = await openDownloadedFile(download.path);
      console.log('[DownloadsPopover] -> openDownloadedFile result:', JSON.stringify(result));
      
      if (!result?.success) {
        console.error('[DownloadsPopover] Falha ao abrir no sistema:', result?.error);
        toast.error(result?.error || 'Não foi possível abrir o arquivo no Windows');
      } else {
        console.log('[DownloadsPopover] Arquivo aberto com sucesso no sistema');
      }
    },
    [openDownloadedFile]
  );

  const handleOpenDownload = useCallback(
    async (download: DownloadItem) => {
      // Clique do usuário: respeitar app_window para PDFs; caso contrário abrir no sistema.
      if (isPdfFile(download.filename) && pdfOpenModeRef.current === 'app_window') {
        await openDownloadInAppWindow(download);
        return;
      }

      await openInSystem(download);
    },
    [isPdfFile, openDownloadInAppWindow, openInSystem]
  );

  // Carregar downloads recentes ao montar
  useEffect(() => {
    console.log('[DownloadsPopover] Inicializando, isElectron:', isElectron);
    if (!isElectron) return;

    console.log('[DownloadsPopover] Carregando downloads recentes...');
    getRecentDownloads().then((recentDownloads) => {
      console.log('[DownloadsPopover] Downloads recentes carregados:', recentDownloads?.length || 0);
      setDownloads(recentDownloads);
    });
  }, [isElectron, getRecentDownloads]);

  // Escutar novos downloads
  useEffect(() => {
    console.log('[DownloadsPopover] Configurando listener de downloads, isElectron:', isElectron);
    if (!isElectron) return;

    console.log('[DownloadsPopover] Registrando onDownloadCompleted listener...');
    console.log('[DownloadsPopover] createWindow disponível:', typeof createWindow);
    console.log('[DownloadsPopover] openDownloadedFile disponível:', typeof openDownloadedFile);

    onDownloadCompleted((download) => {
      console.log('[DownloadsPopover] ========== NOVO DOWNLOAD COMPLETADO ==========');
      console.log('[DownloadsPopover] Arquivo:', download.filename);
      console.log('[DownloadsPopover] Path:', download.path);
      console.log('[DownloadsPopover] Timestamp:', new Date(download.completedAt).toISOString());
      
      setDownloads((prev) => [download, ...prev].slice(0, 20));
      setHasNewDownload(true);

      // Auto-abrir PDF baseado na configuração local (usando ref para valor atual)
      if (isPdfFile(download.filename)) {
        const currentMode = pdfOpenModeRef.current;
        console.log('[DownloadsPopover] É PDF! Modo atual:', currentMode);
        console.log('[DownloadsPopover] createWindow type:', typeof createWindow);
        console.log('[DownloadsPopover] openDownloadedFile type:', typeof openDownloadedFile);

        if (currentMode === 'system') {
          console.log('[DownloadsPopover] Tentando abrir no sistema:', download.path);
          openInSystem(download).then(() => {
            console.log('[DownloadsPopover] openInSystem finalizado');
          }).catch((err) => {
            console.error('[DownloadsPopover] Erro ao abrir no sistema:', err);
          });
        } else if (currentMode === 'app_window') {
          console.log('[DownloadsPopover] Tentando abrir em janela do app:', download.path);
          openDownloadInAppWindow(download).then(() => {
            console.log('[DownloadsPopover] openDownloadInAppWindow finalizado');
          }).catch((err) => {
            console.error('[DownloadsPopover] Erro ao abrir em janela do app:', err);
          });
        } else {
          console.log('[DownloadsPopover] Auto-open desabilitado (mode:', currentMode, ')');
        }
      } else {
        console.log('[DownloadsPopover] Não é PDF, ignorando auto-open');
      }
      console.log('[DownloadsPopover] ========================================');
    });

    console.log('[DownloadsPopover] Listener registrado com sucesso');

    return () => {
      console.log('[DownloadsPopover] Removendo listener download:completed');
      removeAllListeners('download:completed');
    };
  }, [
    isElectron,
    onDownloadCompleted,
    removeAllListeners,
    isPdfFile,
    openDownloadInAppWindow,
    openInSystem,
    createWindow,
    openDownloadedFile,
  ]);

  // Limpar indicador de novo download ao abrir
  useEffect(() => {
    if (open) {
      setHasNewDownload(false);
    }
  }, [open]);

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);

    if (diffMins < 1) return 'Agora';
    if (diffMins < 60) return `${diffMins} min`;
    if (diffHours < 24) return `${diffHours}h`;
    return date.toLocaleDateString('pt-BR');
  };

  const getFileIcon = (filename: string) => {
    const ext = filename.split('.').pop()?.toLowerCase();
    if (['pdf'].includes(ext || '')) return '📄';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext || '')) return '🖼️';
    if (['mp4', 'mov', 'avi'].includes(ext || '')) return '🎬';
    if (['mp3', 'wav', 'ogg'].includes(ext || '')) return '🎵';
    if (['zip', 'rar', '7z'].includes(ext || '')) return '📦';
    if (['doc', 'docx'].includes(ext || '')) return '📝';
    if (['xls', 'xlsx'].includes(ext || '')) return '📊';
    return '📎';
  };

  if (!isElectron) return null;

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className={cn('h-6 w-6 relative', hasNewDownload && 'text-primary')}
          title="Downloads recentes"
        >
          <Download className="h-3 w-3" />
          {hasNewDownload && (
            <span className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-red-500 rounded-full animate-pulse" />
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="end">
        <div className="p-3 border-b">
          <h4 className="font-semibold text-sm flex items-center gap-2">
            <Download className="h-4 w-4" />
            Downloads Recentes
          </h4>
        </div>

        <ScrollArea className="max-h-[300px]">
          {downloads.length === 0 ? (
            <div className="p-4 text-center text-muted-foreground text-sm">
              Nenhum download recente
            </div>
          ) : (
            <div className="divide-y">
              {downloads.map((download, index) => (
                <div
                  key={`${download.path}-${index}`}
                  className="p-2 hover:bg-muted/50 transition-colors group"
                >
                  <div className="flex items-start gap-2">
                    <span className="text-lg shrink-0">{getFileIcon(download.filename)}</span>
                    <div className="flex-1 min-w-0">
                      <p
                        className="text-sm font-medium truncate"
                        title={download.filename}
                      >
                        {download.filename}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatTime(download.completedAt)}
                      </p>
                      {/* Botões de ação */}
                      <div className="flex items-center gap-1 mt-1.5">
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="outline"
                              size="sm"
                              className="h-6 px-2 text-xs gap-1"
                              onClick={(e) => {
                                e.stopPropagation();
                                void openDownloadInAppWindow(download);
                              }}
                            >
                              <AppWindow className="h-3 w-3" />
                              App
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>Abrir em janela do app</TooltipContent>
                        </Tooltip>
                        
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="outline"
                              size="sm"
                              className="h-6 px-2 text-xs gap-1"
                              onClick={(e) => {
                                e.stopPropagation();
                                void openInSystem(download);
                              }}
                            >
                              <ExternalLink className="h-3 w-3" />
                              Windows
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>Abrir no app padrão do Windows</TooltipContent>
                        </Tooltip>
                        
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-6 w-6 shrink-0"
                              onClick={(e) => {
                                e.stopPropagation();
                                void showInFolder(download.path);
                              }}
                            >
                              <FolderOpen className="h-3 w-3" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>Mostrar na pasta</TooltipContent>
                        </Tooltip>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </ScrollArea>
      </PopoverContent>
    </Popover>
  );
}


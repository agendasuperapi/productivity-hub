import { useState, useEffect, useCallback, useRef } from 'react';
import { Download, FolderOpen } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
import { ScrollArea } from '@/components/ui/scroll-area';
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
    (download: DownloadItem) => {
      const fileUrl = toFileUrl(download.path);
      createWindow({
        id: `pdf-${Date.now()}`,
        name: download.filename,
        url: fileUrl,
        window_width: 900,
        window_height: 700,
        zoom: 100,
      });
    },
    [createWindow, toFileUrl]
  );

  const handleOpenDownload = useCallback(
    (download: DownloadItem) => {
      // Clique do usuário: respeitar app_window para PDFs; caso contrário abrir no sistema.
      if (isPdfFile(download.filename) && pdfOpenModeRef.current === 'app_window') {
        openDownloadInAppWindow(download);
        return;
      }

      openDownloadedFile(download.path);
    },
    [isPdfFile, openDownloadedFile, openDownloadInAppWindow]
  );

  // Carregar downloads recentes ao montar
  useEffect(() => {
    if (!isElectron) return;

    getRecentDownloads().then(setDownloads);
  }, [isElectron, getRecentDownloads]);

  // Escutar novos downloads
  useEffect(() => {
    if (!isElectron) return;

    onDownloadCompleted((download) => {
      setDownloads((prev) => [download, ...prev].slice(0, 20));
      setHasNewDownload(true);

      // Auto-abrir PDF baseado na configuração local (usando ref para valor atual)
      if (isPdfFile(download.filename)) {
        const currentMode = pdfOpenModeRef.current;
        console.log('[DownloadsPopover] PDF downloaded, mode:', currentMode);

        if (currentMode === 'system') {
          // Abrir no aplicativo padrão do sistema
          console.log('[DownloadsPopover] Opening in system app:', download.path);
          openDownloadedFile(download.path);
        } else if (currentMode === 'app_window') {
          // Abrir em uma janela do próprio app
          console.log('[DownloadsPopover] Opening in app window:', download.path);
          openDownloadInAppWindow(download);
        } else {
          console.log('[DownloadsPopover] PDF auto-open disabled');
        }
      }
    });

    return () => {
      removeAllListeners('download:completed');
    };
  }, [
    isElectron,
    onDownloadCompleted,
    removeAllListeners,
    isPdfFile,
    openDownloadedFile,
    openDownloadInAppWindow,
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
                  className="p-2 hover:bg-muted/50 transition-colors cursor-pointer group"
                  onClick={() => handleOpenDownload(download)}
                  title="Clique para abrir"
                >
                  <div className="flex items-start gap-2">
                    <span className="text-lg shrink-0">{getFileIcon(download.filename)}</span>
                    <div className="flex-1 min-w-0">
                      <p
                        className="text-sm font-medium truncate group-hover:text-primary transition-colors"
                        title={download.filename}
                      >
                        {download.filename}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatTime(download.completedAt)}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-6 w-6 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                      onClick={(e) => {
                        e.stopPropagation();
                        showInFolder(download.path);
                      }}
                      title="Mostrar na pasta"
                    >
                      <FolderOpen className="h-3 w-3" />
                    </Button>
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


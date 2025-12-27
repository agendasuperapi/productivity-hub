import { useState, useEffect } from 'react';
import { Download, FolderOpen, FileText } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useElectron, DownloadItem } from '@/hooks/useElectron';
import { cn } from '@/lib/utils';

export function DownloadsPopover() {
  const { isElectron, getRecentDownloads, openDownloadedFile, showInFolder, onDownloadCompleted, removeAllListeners } = useElectron();
  const [downloads, setDownloads] = useState<DownloadItem[]>([]);
  const [hasNewDownload, setHasNewDownload] = useState(false);
  const [open, setOpen] = useState(false);

  // Carregar downloads recentes ao montar
  useEffect(() => {
    if (!isElectron) return;
    
    getRecentDownloads().then(setDownloads);
  }, [isElectron, getRecentDownloads]);

  // Escutar novos downloads
  useEffect(() => {
    if (!isElectron) return;

    onDownloadCompleted((download) => {
      setDownloads(prev => [download, ...prev].slice(0, 20));
      setHasNewDownload(true);
    });

    return () => {
      removeAllListeners('download:completed');
    };
  }, [isElectron, onDownloadCompleted, removeAllListeners]);

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
          className={cn(
            "h-6 w-6 relative",
            hasNewDownload && "text-primary"
          )}
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
                  className="p-2 hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-start gap-2">
                    <span className="text-lg shrink-0">{getFileIcon(download.filename)}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate" title={download.filename}>
                        {download.filename}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatTime(download.completedAt)}
                      </p>
                    </div>
                    <div className="flex gap-1 shrink-0">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-6 w-6"
                        onClick={() => openDownloadedFile(download.path)}
                        title="Abrir arquivo"
                      >
                        <FileText className="h-3 w-3" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-6 w-6"
                        onClick={() => showInFolder(download.path)}
                        title="Mostrar na pasta"
                      >
                        <FolderOpen className="h-3 w-3" />
                      </Button>
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

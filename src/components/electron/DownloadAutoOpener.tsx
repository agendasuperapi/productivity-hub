import { useEffect, useCallback, useRef } from 'react';
import { toast } from 'sonner';
import { useElectron, DownloadItem } from '@/hooks/useElectron';
import { useLocalSettings, PdfOpenMode } from '@/hooks/useLocalSettings';

/**
 * Componente invisível que gerencia a auto-abertura de downloads (PDFs).
 * DEVE ser montado independentemente da toolbar estar visível.
 */
export function DownloadAutoOpener() {
  const {
    isElectron,
    onDownloadCompleted,
    removeAllListeners,
    createWindow,
    openDownloadedFile,
  } = useElectron();
  const { settings: localSettings } = useLocalSettings();

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
      console.log('[DownloadAutoOpener] openDownloadInAppWindow chamado');
      console.log('[DownloadAutoOpener] -> filename:', download.filename);
      console.log('[DownloadAutoOpener] -> path:', download.path);
      
      const fileUrl = toFileUrl(download.path);
      console.log('[DownloadAutoOpener] -> fileUrl gerado:', fileUrl);
      
      const windowConfig = {
        id: `pdf-${Date.now()}`,
        name: download.filename,
        url: fileUrl,
        window_width: 900,
        window_height: 700,
        zoom: 100,
      };
      console.log('[DownloadAutoOpener] -> windowConfig:', JSON.stringify(windowConfig));
      
      const result = await createWindow(windowConfig);
      console.log('[DownloadAutoOpener] -> createWindow result:', JSON.stringify(result));

      if (!result?.success) {
        console.error('[DownloadAutoOpener] Falha ao abrir na janela do app:', result?.error);
        toast.error(result?.error || 'Não foi possível abrir o PDF na janela do app');
      } else {
        console.log('[DownloadAutoOpener] Janela criada com sucesso');
      }
    },
    [createWindow, toFileUrl]
  );

  const openInSystem = useCallback(
    async (download: DownloadItem) => {
      console.log('[DownloadAutoOpener] openInSystem chamado');
      console.log('[DownloadAutoOpener] -> filename:', download.filename);
      console.log('[DownloadAutoOpener] -> path:', download.path);
      
      const result = await openDownloadedFile(download.path);
      console.log('[DownloadAutoOpener] -> openDownloadedFile result:', JSON.stringify(result));
      
      if (!result?.success) {
        console.error('[DownloadAutoOpener] Falha ao abrir no sistema:', result?.error);
        toast.error(result?.error || 'Não foi possível abrir o arquivo no Windows');
      } else {
        console.log('[DownloadAutoOpener] Arquivo aberto com sucesso no sistema');
      }
    },
    [openDownloadedFile]
  );

  // Escutar novos downloads e auto-abrir PDFs
  useEffect(() => {
    console.log('[DownloadAutoOpener] Inicializando, isElectron:', isElectron);
    if (!isElectron) return;

    console.log('[DownloadAutoOpener] Registrando onDownloadCompleted listener...');

    onDownloadCompleted((download) => {
      console.log('[DownloadAutoOpener] ========== NOVO DOWNLOAD COMPLETADO ==========');
      console.log('[DownloadAutoOpener] Arquivo:', download.filename);
      console.log('[DownloadAutoOpener] Path:', download.path);
      console.log('[DownloadAutoOpener] Timestamp:', new Date(download.completedAt).toISOString());

      // Auto-abrir PDF baseado na configuração local
      if (isPdfFile(download.filename)) {
        const currentMode = pdfOpenModeRef.current;
        console.log('[DownloadAutoOpener] É PDF! Modo atual:', currentMode);

        if (currentMode === 'system') {
          console.log('[DownloadAutoOpener] Tentando abrir no sistema:', download.path);
          openInSystem(download).then(() => {
            console.log('[DownloadAutoOpener] openInSystem finalizado');
          }).catch((err) => {
            console.error('[DownloadAutoOpener] Erro ao abrir no sistema:', err);
          });
        } else if (currentMode === 'app_window') {
          console.log('[DownloadAutoOpener] Tentando abrir em janela do app:', download.path);
          openDownloadInAppWindow(download).then(() => {
            console.log('[DownloadAutoOpener] openDownloadInAppWindow finalizado');
          }).catch((err) => {
            console.error('[DownloadAutoOpener] Erro ao abrir em janela do app:', err);
          });
        } else {
          console.log('[DownloadAutoOpener] Auto-open desabilitado (mode:', currentMode, ')');
        }
      } else {
        console.log('[DownloadAutoOpener] Não é PDF, ignorando auto-open');
      }
      console.log('[DownloadAutoOpener] ========================================');
    });

    console.log('[DownloadAutoOpener] Listener registrado com sucesso');

    return () => {
      console.log('[DownloadAutoOpener] Removendo listener download:completed');
      removeAllListeners('download:completed');
    };
  }, [
    isElectron,
    onDownloadCompleted,
    removeAllListeners,
    isPdfFile,
    openDownloadInAppWindow,
    openInSystem,
  ]);

  // Componente invisível - não renderiza nada
  return null;
}

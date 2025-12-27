import { app, BrowserWindow, ipcMain, globalShortcut, shell, webContents, dialog, clipboard, session } from 'electron';
import * as path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import Store from 'electron-store';
import { generateShortcutScript } from './shortcut-injector.js';

// Armazenar dados das janelas flutuantes para salvar no close
interface FloatingWindowData {
  tabId: string;
  zoom: number;
}

// Dados salvos para restauração de sessão
interface SavedWindowState {
  tabId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zoom: number;
}

// Interface para download concluído
interface DownloadItem {
  filename: string;
  path: string;
  url: string;
  completedAt: number;
}

// Obter __dirname equivalente para ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Detectar se é modo de desenvolvimento ANTES de qualquer outra inicialização
const isDev = !app.isPackaged;

// Usar nome diferente em dev para evitar conflito de cache com produção
if (isDev) {
  app.setName('GerenciaZap-Dev');
}

// Store para persistência de sessão (nome diferente para dev/prod)
const store = new Store({
  name: isDev ? 'gerencia-zap-auth-dev' : 'gerencia-zap-auth',
  encryptionKey: 'gerencia-zap-secure-key-2024',
});

let mainWindow: BrowserWindow | null = null;
const openWindows = new Map<string, BrowserWindow>();
const floatingWindowData = new Map<string, FloatingWindowData>();

// Lista de downloads recentes (mantida em memória)
const recentDownloads: DownloadItem[] = [];
const MAX_RECENT_DOWNLOADS = 20;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1000,
    minHeight: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true,
      devTools: true,
      webviewTag: true, // Enable webview tag
    },
    frame: false, // Remove barra de título padrão do Windows
    titleBarStyle: 'hidden',
    show: false,
    backgroundColor: '#0a1514',
  });

  // Evento para informar mudanças no estado de maximização
  mainWindow.on('maximize', () => {
    mainWindow?.webContents.send('window:maximizeChange', true);
  });
  
  mainWindow.on('unmaximize', () => {
    mainWindow?.webContents.send('window:maximizeChange', false);
  });

  // Em desenvolvimento, carregar o servidor Vite
  // Em produção, carregar o index.html buildado
  // (isDev já definido globalmente no topo do arquivo)
  
  if (isDev) {
    // Carregar do servidor Vite em desenvolvimento
    mainWindow.loadURL('http://localhost:8080');
    
    // DevTools apenas se explicitamente solicitado (não abrir automaticamente)
    // Para abrir: Ctrl+Shift+I ou View > Toggle DevTools
  } else {
    // Em produção, carregar o arquivo buildado
    const indexPath = path.join(__dirname, '../dist/index.html');
    if (fs.existsSync(indexPath)) {
      mainWindow.loadFile(indexPath);
    } else {
      // Fallback para o renderer.html antigo
      const rendererPath = path.join(__dirname, 'renderer.html');
      if (fs.existsSync(rendererPath)) {
        mainWindow.loadFile(rendererPath);
      }
    }
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
  });

  // Confirmação antes de fechar se há janelas flutuantes abertas
  mainWindow.on('close', (e) => {
    const floatingCount = openWindows.size;
    
    if (floatingCount > 0 && mainWindow && !mainWindow.isDestroyed()) {
      e.preventDefault();
      
      const message = floatingCount === 1
        ? 'Você tem 1 janela flutuante aberta.'
        : `Você tem ${floatingCount} janelas flutuantes abertas.`;
      
      dialog.showMessageBox(mainWindow, {
        type: 'warning',
        buttons: ['Fechar tudo', 'Cancelar'],
        defaultId: 1,
        cancelId: 1,
        title: 'GerenciaZap',
        message: 'Deseja sair do GerenciaZap?',
        detail: `${message}\n\nTodas as janelas serão fechadas e a sessão será salva para restauração posterior.`,
        noLink: true,
      }).then((result) => {
        if (result.response === 0) {
          // Usuário confirmou "Fechar tudo"
          mainWindow?.destroy();
        }
      });
    }
  });

  mainWindow.on('closed', () => {
    // Salvar estado das janelas flutuantes antes de fechar
    const windowStates: SavedWindowState[] = [];
    openWindows.forEach((window, tabId) => {
      try {
        if (window && !window.isDestroyed()) {
          const [x, y] = window.getPosition();
          const [width, height] = window.getSize();
          const data = floatingWindowData.get(tabId);
          
          windowStates.push({
            tabId,
            x,
            y,
            width,
            height,
            zoom: data?.zoom || 100,
          });
        }
      } catch (e) {
        console.log('[Main] Erro ao salvar estado da janela:', tabId, e);
      }
    });
    
    // Salvar no store
    if (windowStates.length > 0) {
      store.set('floatingWindowsSession', windowStates);
      console.log('[Main] Sessão de janelas salva:', windowStates.length, 'janelas');
    } else {
      store.delete('floatingWindowsSession');
    }
    
    // Marcar mainWindow como null PRIMEIRO para evitar eventos para janela destruída
    mainWindow = null;
    
    // Fechar todas as janelas flutuantes quando a janela principal fechar
    openWindows.forEach((window, tabId) => {
      try {
        if (window && !window.isDestroyed()) {
          // Remover listeners antes de fechar para evitar eventos
          window.removeAllListeners('close');
          window.removeAllListeners('closed');
          window.close();
        }
      } catch (e) {
        console.log('[Main] Erro ao fechar janela flutuante:', tabId, e);
      }
    });
    openWindows.clear();
    floatingWindowData.clear();
  });

  // Abrir links externos no navegador padrão
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

// ============ SESSION RESTORE (Janelas flutuantes) ============

ipcMain.handle('session:getFloatingWindows', () => {
  const saved = store.get('floatingWindowsSession', null) as SavedWindowState[] | null;
  console.log('[Main] Recuperando sessão de janelas:', saved?.length || 0, 'janelas');
  return saved;
});

ipcMain.handle('session:clearFloatingWindows', () => {
  store.delete('floatingWindowsSession');
  console.log('[Main] Sessão de janelas limpa');
  return true;
});

// ============ USER SETTINGS ============

ipcMain.handle('settings:get', (_, key: string) => {
  return store.get(`settings.${key}`, null);
});

ipcMain.handle('settings:set', (_, key: string, value: unknown) => {
  store.set(`settings.${key}`, value);
  return true;
});

ipcMain.handle('settings:getAll', () => {
  return store.get('settings', {});
});

ipcMain.handle('settings:setAll', (_, settings: Record<string, unknown>) => {
  store.set('settings', settings);
  return true;
});

// ============ AUTH (Sessão persistente) ============

ipcMain.handle('auth:getSession', () => {
  return store.get('session', null);
});

ipcMain.handle('auth:setSession', (_, session) => {
  store.set('session', session);
  return true;
});

ipcMain.handle('auth:clearSession', () => {
  store.delete('session');
  return true;
});

// ============ CLIPBOARD ============

ipcMain.handle('clipboard:write', async (_, text: string) => {
  try {
    clipboard.writeText(text);
    console.log('[Main] Texto copiado para clipboard:', text.substring(0, 50));
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao copiar para clipboard:', error);
    return { success: false, error: error.message };
  }
});

// ============ WINDOW MANAGEMENT ============

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcutData {
  command: string;
  expanded_text: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface KeywordData {
  key: string;
  value: string;
}

interface TabData {
  id: string;
  name: string;
  url: string;
  urls?: string[];
  zoom?: number;
  layout_type?: string;
  open_as_window?: boolean;
  window_x?: number;
  window_y?: number;
  window_width?: number;
  window_height?: number;
  textShortcuts?: TextShortcutData[];
  keywords?: KeywordData[];
}

ipcMain.handle('window:create', async (_, tab: TabData) => {
  try {
    // Verificar se a janela já existe
    if (openWindows.has(tab.id)) {
      const existingWindow = openWindows.get(tab.id);
      existingWindow?.focus();
      return { success: true, windowId: tab.id };
    }

    // Configurar posição e tamanho da janela
    const windowOptions: Electron.BrowserWindowConstructorOptions = {
      width: tab.window_width || 1200,
      height: tab.window_height || 800,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        webviewTag: true,
        preload: path.join(__dirname, 'floating-preload.js'),
      },
      title: tab.name,
      frame: false, // Remove barra de título padrão do Windows
      titleBarStyle: 'hidden',
      backgroundColor: '#0a1514',
    };

    // Aplicar posição salva se disponível
    if (tab.window_x !== undefined && tab.window_x !== null) {
      windowOptions.x = tab.window_x;
    }
    if (tab.window_y !== undefined && tab.window_y !== null) {
      windowOptions.y = tab.window_y;
    }

    const window = new BrowserWindow(windowOptions);
    
    // Carregar o HTML da janela flutuante
    const floatingHtmlPath = path.join(__dirname, 'floating-window.html');
    window.loadFile(floatingHtmlPath);

    // Gerar script de atalhos
    const shortcutScript = generateShortcutScript(
      tab.textShortcuts || [],
      tab.keywords || []
    );

    // Enviar configuração após o HTML carregar
    // Usar pequeno delay para garantir que o preload está pronto
    window.webContents.once('did-finish-load', () => {
      const configData = {
        tabId: tab.id,
        name: tab.name,
        url: tab.url,
        zoom: tab.zoom || 100,
        shortcutScript: shortcutScript,
      };
      console.log('[Main] Sending floating:init', configData);
      
      // Enviar imediatamente e também após um delay como fallback
      window.webContents.send('floating:init', configData);
      setTimeout(() => {
        if (!window.isDestroyed()) {
          window.webContents.send('floating:init', configData);
        }
      }, 100);
    });

    // Armazenar dados da janela
    floatingWindowData.set(tab.id, {
      tabId: tab.id,
      zoom: tab.zoom || 100,
    });

    openWindows.set(tab.id, window);

    // Evento para informar mudanças no estado de maximização
    window.on('maximize', () => {
      if (!window.isDestroyed()) {
        window.webContents.send('floatingWindow:maximizeChange', true);
      }
    });
    
    window.on('unmaximize', () => {
      if (!window.isDestroyed()) {
        window.webContents.send('floatingWindow:maximizeChange', false);
      }
    });

    // Salvar posição/tamanho antes de fechar
    window.on('close', () => {
      try {
        // Verificar se mainWindow existe e não foi destruída
        if (mainWindow && !mainWindow.isDestroyed() && !window.isDestroyed()) {
          const [x, y] = window.getPosition();
          const [width, height] = window.getSize();
          const data = floatingWindowData.get(tab.id);
          
          mainWindow.webContents.send('window:boundsChanged', {
            tabId: tab.id,
            x,
            y,
            width,
            height,
            zoom: data?.zoom || 100,
          });
        }
      } catch (e) {
        console.log('[Main] Erro ao salvar bounds da janela:', tab.id, e);
      }
    });

    window.on('closed', () => {
      openWindows.delete(tab.id);
      floatingWindowData.delete(tab.id);
    });

    return { success: true, windowId: tab.id };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// Handler para mudança de zoom na janela flutuante
ipcMain.on('floating:zoomChanged', (event, zoom: number) => {
  // Encontrar qual janela enviou o evento
  for (const [tabId, window] of openWindows.entries()) {
    if (window.webContents.id === event.sender.id) {
      const data = floatingWindowData.get(tabId);
      if (data) {
        data.zoom = zoom;
      }
      break;
    }
  }
});

// Handler para abrir URL externa
ipcMain.on('floating:openExternal', (_, url: string) => {
  shell.openExternal(url);
});

// Handler para salvar posição da janela flutuante (envia dados para a janela principal que faz a persistência)
ipcMain.handle('floating:savePosition', async (event) => {
  // Encontrar qual janela enviou o evento
  for (const [tabId, window] of openWindows.entries()) {
    if (window.webContents.id === event.sender.id) {
      try {
        const [x, y] = window.getPosition();
        const [width, height] = window.getSize();
        const data = floatingWindowData.get(tabId);
        
        // Enviar para a janela principal salvar no banco
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.send('floating:requestSavePosition', {
            tabId,
            x,
            y,
            width,
            height,
            zoom: data?.zoom || 100,
          });
        }
        
        return { success: true, tabId, x, y, width, height, zoom: data?.zoom || 100 };
      } catch (e: any) {
        return { success: false, error: e.message };
      }
    }
  }
  return { success: false, error: 'Window not found' };
});

ipcMain.handle('window:close', async (_, tabId: string) => {
  const window = openWindows.get(tabId);
  if (window) {
    window.close();
    openWindows.delete(tabId);
  }
  return { success: true };
});

ipcMain.handle('window:openExternal', async (_, url: string) => {
  try {
    await shell.openExternal(url);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// ============ KEYBOARD SHORTCUTS ============

ipcMain.handle('keyboard:register', async (_, shortcut: string, tabId: string) => {
  try {
    const ret = globalShortcut.register(shortcut, () => {
      mainWindow?.webContents.send('keyboard:triggered', tabId);
    });
    return { success: ret };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('keyboard:unregister', async (_, shortcut: string) => {
  try {
    globalShortcut.unregister(shortcut);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('keyboard:unregisterAll', async () => {
  try {
    globalShortcut.unregisterAll();
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// ============ DOWNLOADS ============

ipcMain.handle('downloads:getRecent', () => {
  return recentDownloads;
});

ipcMain.handle('downloads:openFile', async (_, filePath: string) => {
  try {
    await shell.openPath(filePath);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('downloads:showInFolder', async (_, filePath: string) => {
  try {
    shell.showItemInFolder(filePath);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// ============ WINDOW CONTROLS ============

ipcMain.handle('window:minimize', () => {
  mainWindow?.minimize();
  return { success: true };
});

ipcMain.handle('window:maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
  return { success: true, isMaximized: mainWindow?.isMaximized() || false };
});

ipcMain.handle('window:closeMain', () => {
  mainWindow?.close();
  return { success: true };
});

ipcMain.handle('window:isMaximized', () => {
  return mainWindow?.isMaximized() || false;
});

// ============ FLOATING WINDOW CONTROLS ============

// Helper para encontrar a janela que enviou o evento
function getFloatingWindowFromEvent(event: Electron.IpcMainInvokeEvent): BrowserWindow | null {
  for (const [, window] of openWindows.entries()) {
    if (window.webContents.id === event.sender.id) {
      return window;
    }
  }
  return null;
}

ipcMain.handle('floatingWindow:minimize', (event) => {
  const window = getFloatingWindowFromEvent(event);
  window?.minimize();
  return { success: true };
});

ipcMain.handle('floatingWindow:maximize', (event) => {
  const window = getFloatingWindowFromEvent(event);
  if (window) {
    if (window.isMaximized()) {
      window.unmaximize();
    } else {
      window.maximize();
    }
    return { success: true, isMaximized: window.isMaximized() };
  }
  return { success: false };
});

ipcMain.handle('floatingWindow:close', (event) => {
  const window = getFloatingWindowFromEvent(event);
  window?.close();
  return { success: true };
});

ipcMain.handle('floatingWindow:isMaximized', (event) => {
  const window = getFloatingWindowFromEvent(event);
  return window?.isMaximized() || false;
});

// ============ APP LIFECYCLE ============

app.whenReady().then(() => {
  createWindow();

  // Configurar handler de downloads para todas as sessões
  const defaultSession = session.defaultSession;
  
  // Handler para downloads
  defaultSession.on('will-download', (_event: Electron.Event, item: Electron.DownloadItem, _webContents: Electron.WebContents) => {
    const downloadsPath = app.getPath('downloads');
    const filename = item.getFilename();
    const savePath = path.join(downloadsPath, filename);
    
    console.log('[Main] Download iniciado:', filename);
    item.setSavePath(savePath);
    
    item.on('done', (_event: Electron.Event, state: string) => {
      if (state === 'completed') {
        console.log('[Main] Download concluído:', savePath);
        
        // Adicionar à lista de downloads recentes
        const downloadItem: DownloadItem = {
          filename,
          path: savePath,
          url: item.getURL(),
          completedAt: Date.now(),
        };
        
        recentDownloads.unshift(downloadItem);
        if (recentDownloads.length > MAX_RECENT_DOWNLOADS) {
          recentDownloads.pop();
        }
        
        // Notificar a janela principal
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.send('download:completed', downloadItem);
        }
        
        // Abrir o arquivo automaticamente
        shell.openPath(savePath).catch(err => {
          console.error('[Main] Erro ao abrir arquivo:', err);
        });
      } else {
        console.log('[Main] Download falhou:', state);
      }
    });
  });
  
  // Aplicar handler também para sessões de partição (persist:tab-*)
  app.on('session-created', (createdSession: Electron.Session) => {
    createdSession.on('will-download', (_event: Electron.Event, item: Electron.DownloadItem, _webContents: Electron.WebContents) => {
      const downloadsPath = app.getPath('downloads');
      const filename = item.getFilename();
      const savePath = path.join(downloadsPath, filename);
      
      console.log('[Main] Download iniciado (partition):', filename);
      item.setSavePath(savePath);
      
      item.on('done', (_event: Electron.Event, state: string) => {
        if (state === 'completed') {
          console.log('[Main] Download concluído (partition):', savePath);
          
          const downloadItem: DownloadItem = {
            filename,
            path: savePath,
            url: item.getURL(),
            completedAt: Date.now(),
          };
          
          recentDownloads.unshift(downloadItem);
          if (recentDownloads.length > MAX_RECENT_DOWNLOADS) {
            recentDownloads.pop();
          }
          
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('download:completed', downloadItem);
          }
          
          shell.openPath(savePath).catch(err => {
            console.error('[Main] Erro ao abrir arquivo:', err);
          });
        }
      });
    });
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});

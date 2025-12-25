import { app, BrowserWindow, ipcMain, globalShortcut, shell } from 'electron';
import * as path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import Store from 'electron-store';
import { generateShortcutScript } from './shortcut-injector.js';

// Obter __dirname equivalente para ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Store para persistência de sessão
const store = new Store({
  name: 'gerencia-zap-auth',
  encryptionKey: 'gerencia-zap-secure-key-2024',
});

let mainWindow: BrowserWindow | null = null;
const openWindows = new Map<string, BrowserWindow>();

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
    titleBarStyle: 'default',
    show: false,
    backgroundColor: '#00a4a4',
  });

  // Em desenvolvimento, carregar o servidor Vite
  // Em produção, carregar o index.html buildado
  const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;
  
  if (isDev) {
    // Carregar do servidor Vite em desenvolvimento
    mainWindow.loadURL('http://localhost:8080');
    
    // Abrir DevTools em desenvolvimento
    mainWindow.webContents.openDevTools();
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

  mainWindow.on('closed', () => {
    // Fechar todas as janelas flutuantes quando a janela principal fechar
    openWindows.forEach((window) => {
      if (!window.isDestroyed()) {
        window.close();
      }
    });
    openWindows.clear();
    mainWindow = null;
  });

  // Abrir links externos no navegador padrão
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

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

// ============ WINDOW MANAGEMENT ============

interface TextShortcutData {
  command: string;
  expanded_text: string;
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
        webSecurity: true,
      },
      title: tab.name,
    };

    // Aplicar posição salva se disponível
    if (tab.window_x !== undefined && tab.window_x !== null) {
      windowOptions.x = tab.window_x;
    }
    if (tab.window_y !== undefined && tab.window_y !== null) {
      windowOptions.y = tab.window_y;
    }

    const window = new BrowserWindow(windowOptions);

    window.loadURL(tab.url);

    // Aplicar zoom se configurado
    if (tab.zoom && tab.zoom !== 100) {
      const zoomFactor = tab.zoom / 100;
      window.webContents.setZoomFactor(zoomFactor);
    }

    // Injetar script de atalhos após a página carregar
    if (tab.textShortcuts || tab.keywords) {
      window.webContents.on('did-finish-load', () => {
        const script = generateShortcutScript(
          tab.textShortcuts || [],
          tab.keywords || []
        );
        window.webContents.executeJavaScript(script)
          .then(() => console.log(`[GerenciaZap] Script injetado na janela: ${tab.name}`))
          .catch((err) => console.error(`[GerenciaZap] Erro ao injetar script:`, err));
      });

      // Também injetar ao navegar para novas páginas
      window.webContents.on('did-navigate', () => {
        const script = generateShortcutScript(
          tab.textShortcuts || [],
          tab.keywords || []
        );
        window.webContents.executeJavaScript(script)
          .catch((err) => console.error(`[GerenciaZap] Erro ao injetar script após navegação:`, err));
      });
    }

    openWindows.set(tab.id, window);

    // Enviar eventos de mudança de posição/tamanho para o renderer
    let moveTimeout: NodeJS.Timeout | null = null;
    let resizeTimeout: NodeJS.Timeout | null = null;

    window.on('move', () => {
      if (moveTimeout) clearTimeout(moveTimeout);
      moveTimeout = setTimeout(() => {
        if (!window.isDestroyed()) {
          const [x, y] = window.getPosition();
          mainWindow?.webContents.send('window:positionChanged', { tabId: tab.id, x, y });
        }
      }, 300); // Debounce de 300ms
    });

    window.on('resize', () => {
      if (resizeTimeout) clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        if (!window.isDestroyed()) {
          const [width, height] = window.getSize();
          mainWindow?.webContents.send('window:sizeChanged', { tabId: tab.id, width, height });
        }
      }, 300); // Debounce de 300ms
    });

    window.on('closed', () => {
      if (moveTimeout) clearTimeout(moveTimeout);
      if (resizeTimeout) clearTimeout(resizeTimeout);
      openWindows.delete(tab.id);
    });

    return { success: true, windowId: tab.id };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
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

// ============ APP LIFECYCLE ============

app.whenReady().then(() => {
  createWindow();

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

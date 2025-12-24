import { app, BrowserWindow, ipcMain, globalShortcut, shell } from 'electron';
import * as path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import Store from 'electron-store';

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

  // Caminho do renderer.html
  const rendererPath = path.join(__dirname, 'renderer.html');
  
  // Verificar se o arquivo existe
  if (!fs.existsSync(rendererPath)) {
    const altPath = path.join(process.resourcesPath || __dirname, '../electron/renderer.html');
    if (fs.existsSync(altPath)) {
      mainWindow.loadFile(altPath);
    }
  } else {
    mainWindow.loadFile(rendererPath);
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
  });

  mainWindow.on('closed', () => {
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

interface TabData {
  id: string;
  name: string;
  url: string;
  urls?: string[];
  zoom?: number;
  layout_type?: string;
  open_as_window?: boolean;
}

ipcMain.handle('window:create', async (_, tab: TabData) => {
  try {
    // Verificar se a janela já existe
    if (openWindows.has(tab.id)) {
      const existingWindow = openWindows.get(tab.id);
      existingWindow?.focus();
      return { success: true, windowId: tab.id };
    }

    const window = new BrowserWindow({
      width: 1200,
      height: 800,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        webSecurity: true,
      },
      title: tab.name,
    });

    window.loadURL(tab.url);

    // Aplicar zoom se configurado
    if (tab.zoom && tab.zoom !== 100) {
      const zoomFactor = tab.zoom / 100;
      window.webContents.setZoomFactor(zoomFactor);
    }

    openWindows.set(tab.id, window);

    window.on('closed', () => {
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

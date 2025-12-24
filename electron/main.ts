import { app, BrowserWindow, ipcMain, globalShortcut } from 'electron';
import * as path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import * as localStorage from './local-storage.js';

// Obter __dirname equivalente para ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let mainWindow: BrowserWindow | null = null;
const openWindows = new Map<string, BrowserWindow>();

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true,
      devTools: true,
    },
    titleBarStyle: 'default',
    show: false,
  });

  // Caminho do renderer.html
  const rendererPath = path.join(__dirname, 'renderer.html');
  
  // Verificar se o arquivo existe, caso contrário tentar caminho alternativo
  if (!fs.existsSync(rendererPath)) {
    const altPath = path.join(process.resourcesPath || __dirname, '../electron/renderer.html');
    if (fs.existsSync(altPath)) {
      mainWindow.loadFile(altPath);
      return;
    }
  }
  
  mainWindow.loadFile(rendererPath);

  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ============ CONFIG ============

ipcMain.handle('config:get', () => {
  return localStorage.getConfig();
});

// ============ TAB GROUPS ============

ipcMain.handle('tabGroup:add', (_, group) => {
  return localStorage.addTabGroup(group);
});

ipcMain.handle('tabGroup:update', (_, id: string, data) => {
  return localStorage.updateTabGroup(id, data);
});

ipcMain.handle('tabGroup:delete', (_, id: string) => {
  return localStorage.deleteTabGroup(id);
});

// ============ TABS ============

ipcMain.handle('tab:add', (_, tab) => {
  return localStorage.addTab(tab);
});

ipcMain.handle('tab:update', (_, id: string, data) => {
  return localStorage.updateTab(id, data);
});

ipcMain.handle('tab:delete', (_, id: string) => {
  return localStorage.deleteTab(id);
});

// ============ TEXT SHORTCUTS ============

ipcMain.handle('shortcut:add', (_, shortcut) => {
  return localStorage.addTextShortcut(shortcut);
});

ipcMain.handle('shortcut:update', (_, id: string, data) => {
  return localStorage.updateTextShortcut(id, data);
});

ipcMain.handle('shortcut:delete', (_, id: string) => {
  return localStorage.deleteTextShortcut(id);
});

ipcMain.handle('shortcuts:import', (_, shortcuts) => {
  return localStorage.importTextShortcuts(shortcuts);
});

ipcMain.handle('shortcuts:export', () => {
  return localStorage.exportTextShortcuts();
});

// ============ WINDOW ============

interface Tab {
  id: string;
  name: string;
  url: string;
  zoom?: number;
  open_as_window?: boolean;
}

ipcMain.handle('window:create', async (_, tab: Tab) => {
  try {
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

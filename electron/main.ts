import { app, BrowserWindow, ipcMain, globalShortcut, shell, webContents, dialog, clipboard } from 'electron';
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
const floatingWindowData = new Map<string, FloatingWindowData>();

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
        ? 'Há 1 janela flutuante aberta. Deseja fechar tudo?'
        : `Há ${floatingCount} janelas flutuantes abertas. Deseja fechar tudo?`;
      
      dialog.showMessageBox(mainWindow, {
        type: 'question',
        buttons: ['Cancelar', 'Fechar tudo'],
        defaultId: 0,
        cancelId: 0,
        title: 'Confirmar fechamento',
        message: 'Fechar GerenciaZap?',
        detail: message,
      }).then((result) => {
        if (result.response === 1) {
          // Usuário confirmou, forçar fechamento
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
        webviewTag: true,
        preload: path.join(__dirname, 'floating-preload.js'),
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

import { app, BrowserWindow, ipcMain, globalShortcut, webContents } from 'electron';
import * as path from 'path';
import { supabase, fetchUserConfig, UserConfig, Tab } from './supabase-electron';

let mainWindow: BrowserWindow | null = null;
let userConfig: UserConfig | null = null;
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
    },
    titleBarStyle: 'default',
    show: false,
  });

  // Caminho do renderer.html
  // Em desenvolvimento: __dirname = dist-electron, então ../electron/renderer.html
  // Em produção: __dirname = app.asar/dist-electron, então ../electron/renderer.html
  const rendererPath = path.join(__dirname, '../electron/renderer.html');
  
  // Verificar se o arquivo existe, caso contrário tentar caminho alternativo
  const fs = require('fs');
  if (!fs.existsSync(rendererPath)) {
    // Tentar caminho relativo ao app
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

// IPC: Login
ipcMain.handle('auth:login', async (_, email: string, password: string) => {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      throw error;
    }

    // Buscar configurações após login
    userConfig = await fetchUserConfig();
    
    return { 
      success: true, 
      user: data.user, 
      session: data.session,
      config: userConfig 
    };
  } catch (error: any) {
    return { 
      success: false, 
      error: error.message || 'Erro no login' 
    };
  }
});

// IPC: Logout
ipcMain.handle('auth:logout', async () => {
  try {
    await supabase.auth.signOut();
    userConfig = null;
    
    // Fechar todas as janelas abertas
    openWindows.forEach((window) => {
      window.close();
    });
    openWindows.clear();
    
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// IPC: Verificar sessão
ipcMain.handle('auth:getSession', async () => {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    return { session };
  } catch (error: any) {
    return { session: null, error: error.message };
  }
});

// IPC: Buscar configurações
ipcMain.handle('config:fetch', async () => {
  try {
    userConfig = await fetchUserConfig();
    return { success: true, config: userConfig };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// IPC: Obter configurações em cache
ipcMain.handle('config:get', () => {
  return { success: true, config: userConfig };
});

// IPC: Criar nova janela para uma aba
ipcMain.handle('window:create', async (_, tab: Tab) => {
  try {
    if (!tab.open_as_window) {
      return { success: false, error: 'Aba não configurada para abrir como janela' };
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

// IPC: Registrar atalho de teclado global
ipcMain.handle('shortcut:register', async (_, shortcut: string, tabId: string) => {
  try {
    const ret = globalShortcut.register(shortcut, () => {
      mainWindow?.webContents.send('shortcut:triggered', tabId);
    });
    return { success: ret };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// IPC: Desregistrar atalho
ipcMain.handle('shortcut:unregister', async (_, shortcut: string) => {
  try {
    globalShortcut.unregister(shortcut);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// IPC: Desregistrar todos os atalhos
ipcMain.handle('shortcut:unregisterAll', async () => {
  try {
    globalShortcut.unregisterAll();
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
});

// Inicializar aplicação
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

// Escutar mudanças de autenticação
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_OUT') {
    userConfig = null;
    mainWindow?.webContents.send('auth:stateChanged', { signedIn: false });
  } else if (event === 'SIGNED_IN' && session) {
    mainWindow?.webContents.send('auth:stateChanged', { signedIn: true });
  }
});


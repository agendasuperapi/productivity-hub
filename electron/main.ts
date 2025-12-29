import { app, BrowserWindow, ipcMain, globalShortcut, shell, webContents, dialog, clipboard, session, Notification } from 'electron';
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

// Definir AppUserModelId para agrupar janelas na barra de tarefas do Windows
if (process.platform === 'win32') {
  app.setAppUserModelId('com.gerenciazap.app');
}

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

// Map global para armazenar configurações de captura de token por tabId
interface TokenCaptureConfig {
  headerName: string;
  alternativeDomains: string[];
  lastCapturedToken: string | null;
}
const tokenCaptureConfigs = new Map<string, TokenCaptureConfig>();

// Função para gerar caminho único para downloads (evita sobrescrever arquivos)
function getUniqueFilePath(dir: string, filename: string): string {
  let filePath = path.join(dir, filename);
  if (!fs.existsSync(filePath)) return filePath;
  
  const ext = path.extname(filename);
  const name = path.basename(filename, ext);
  let counter = 1;
  
  while (fs.existsSync(filePath)) {
    filePath = path.join(dir, `${name} (${counter})${ext}`);
    counter++;
  }
  
  return filePath;
}

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
  alternative_domains?: string[];
  show_link_transform_panel?: boolean;
  capture_token?: boolean;
  capture_token_header?: string;
}

ipcMain.handle('window:create', async (_, tab: TabData) => {
  console.log('[Main] *** VERSÃO 1.0.10 DO HANDLER window:create ***');
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

    // DEBUG: Log para verificar valor recebido
    console.log('[Main] window:create - capture_token recebido:', {
      id: tab.id,
      name: tab.name,
      capture_token: tab.capture_token,
      capture_token_header: tab.capture_token_header,
      typeof_capture_token: typeof tab.capture_token
    });

    // Adicionar config de captura de token ao Map global (o listener já está registrado)
    if (tab.capture_token === true) {  // Comparação estrita
      console.log('[Main] Adicionando config de captura para tab:', tab.id);
      console.log('[Main] -> header:', tab.capture_token_header || 'X-Access-Token');
      console.log('[Main] -> alternative_domains:', JSON.stringify(tab.alternative_domains));
      
      tokenCaptureConfigs.set(tab.id, {
        headerName: tab.capture_token_header || 'X-Access-Token',
        alternativeDomains: tab.alternative_domains || [],
        lastCapturedToken: null,
      });
    }

    // Enviar configuração após o HTML carregar
    // Usar pequeno delay para garantir que o preload está pronto
    window.webContents.once('did-finish-load', () => {
      const configData = {
        tabId: tab.id,
        name: tab.name,
        url: tab.url,
        zoom: tab.zoom || 100,
        shortcutScript: shortcutScript,
        alternativeDomains: tab.alternative_domains || [],
        showLinkTransformPanel: tab.show_link_transform_panel ?? true,
        captureToken: tab.capture_token ?? false,
        captureTokenHeader: tab.capture_token_header || 'X-Access-Token',
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
      tokenCaptureConfigs.delete(tab.id); // Limpar config de captura
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

// Handler para salvar token capturado
ipcMain.handle('floating:saveToken', async (event, data: { tabId: string; domain: string; tokenName: string; tokenValue: string }) => {
  try {
    console.log('[Main] Salvando token capturado:', data.tokenName, 'para tab:', data.tabId);
    
    // Enviar para a janela principal para salvar no Supabase
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('token:captured', data);
    }
    
    // Mostrar notificação push do sistema
    const timestamp = new Date().toLocaleTimeString('pt-BR', { 
      hour: '2-digit', 
      minute: '2-digit', 
      second: '2-digit' 
    });
    
    const notification = new Notification({
      title: '🔑 Token Capturado',
      body: `Domínio: ${data.domain}\nCapturado às ${timestamp}`,
      icon: path.join(__dirname, '../build/icon.png'),
      silent: false,
    });
    
    notification.show();
    
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao processar token:', error);
    return { success: false, error: error.message };
  }
});

// Handler para abrir URL em nova janela flutuante
ipcMain.on('floating:openInFloatingWindow', (_, url: string, name?: string) => {
  // Gerar um ID único para esta janela baseado na URL
  const urlId = `floating-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  // Extrair nome do domínio se não fornecido
  let windowName = name;
  if (!windowName) {
    try {
      const urlObj = new URL(url);
      windowName = urlObj.hostname;
    } catch {
      windowName = 'Nova Janela';
    }
  }
  
  const windowOptions: Electron.BrowserWindowConstructorOptions = {
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      webviewTag: true,
      preload: path.join(__dirname, 'floating-preload.js'),
    },
    title: windowName,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0a1514',
  };

  const window = new BrowserWindow(windowOptions);
  
  // Carregar o HTML da janela flutuante
  const floatingHtmlPath = path.join(__dirname, 'floating-window.html');
  window.loadFile(floatingHtmlPath);

  // Enviar configuração após o HTML carregar
  window.webContents.once('did-finish-load', () => {
    const configData = {
      tabId: urlId,
      name: windowName,
      url: url,
      zoom: 100,
      shortcutScript: '',
    };
    console.log('[Main] Sending floating:init for external link', configData);
    
    window.webContents.send('floating:init', configData);
    setTimeout(() => {
      if (!window.isDestroyed()) {
        window.webContents.send('floating:init', configData);
      }
    }, 100);
  });

  // Armazenar dados da janela
  floatingWindowData.set(urlId, {
    tabId: urlId,
    zoom: 100,
  });

  openWindows.set(urlId, window);

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

  window.on('closed', () => {
    openWindows.delete(urlId);
    floatingWindowData.delete(urlId);
  });
});

// Handler para salvar credenciais (envia para a janela principal processar via Supabase)
ipcMain.handle('floating:saveCredential', async (_, data: { url: string; username: string; password: string; siteName?: string }) => {
  try {
    console.log('[Main] Salvando credencial para:', data.url);
    
    // Enviar para a janela principal para salvar via React/Supabase
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('credential:save', data);
      return { success: true };
    }
    
    return { success: false, error: 'Main window not available' };
  } catch (error: any) {
    console.error('[Main] Erro ao salvar credencial:', error);
    return { success: false, error: error.message };
  }
});

// Handler para buscar credenciais para auto-fill
ipcMain.handle('floating:getCredentials', async (_, url: string) => {
  try {
    console.log('[Main] Buscando credenciais para:', url);
    
    // Solicitar credenciais da janela principal
    if (mainWindow && !mainWindow.isDestroyed()) {
      // Usar IPC request-response
      return new Promise((resolve) => {
        const responseChannel = `credential:response:${Date.now()}`;
        
        ipcMain.once(responseChannel, (_, credentials) => {
          resolve(credentials);
        });
        
        mainWindow!.webContents.send('credential:get', { url, responseChannel });
        
        // Timeout de 5 segundos
        setTimeout(() => {
          resolve([]);
        }, 5000);
      });
    }
    
    return [];
  } catch (error: any) {
    console.error('[Main] Erro ao buscar credenciais:', error);
    return [];
  }
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
  // Configurar captura de token GLOBALMENTE antes de criar janelas
  // O listener é registrado UMA vez e verifica todas as configs ativas
  const webviewSession = session.fromPartition('persist:floating-webview');
  
  webviewSession.webRequest.onBeforeSendHeaders(
    { urls: ['*://*/*'] },
    (details, callback) => {
      // Log para debug (remover depois de confirmar funcionamento)
      if (details.url.includes('dashboard.bz') || details.url.includes('api')) {
        console.log('[webRequest] Requisição interceptada:', details.url.substring(0, 100));
      }
      
      // Verificar todas as configs de captura ativas
      for (const [tabId, config] of tokenCaptureConfigs.entries()) {
        // Normalizar domínios (remover protocolo e trailing slash)
        const normalizeUrl = (url: string) => url.replace(/^https?:\/\//, '').replace(/\/$/, '').toLowerCase();
        
        const isTargetDomain = details.url.includes('dashboard.bz') || 
          config.alternativeDomains.some(d => {
            const normalizedDomain = normalizeUrl(d);
            const matches = details.url.toLowerCase().includes(normalizedDomain);
            return matches;
          });
        
        // DEBUG: Log para requisições pdcapi.io
        if (details.url.includes('pdcapi.io')) {
          console.log('[webRequest] Verificando pdcapi.io para tab:', tabId);
          console.log('[webRequest] -> alternativeDomains:', JSON.stringify(config.alternativeDomains));
          console.log('[webRequest] -> isTargetDomain:', isTargetDomain);
        }
        
        if (isTargetDomain) {
          const headers = details.requestHeaders;
          let tokenValue: string | null = null;
          let foundHeaderName = config.headerName;
          
          // DEBUG: Log todos os headers para ver o que está disponível
          const headerKeys = Object.keys(headers);
          if (headerKeys.length > 5) {  // Só loga se tiver headers interessantes (não só os padrão)
            console.log('[webRequest] Headers em', details.url.substring(0, 60), ':', headerKeys.join(', '));
          }
          
          for (const [key, value] of Object.entries(headers)) {
            if (key.toLowerCase() === config.headerName.toLowerCase()) {
              tokenValue = value as string;
              foundHeaderName = key;
              console.log('[webRequest] HEADER ENCONTRADO:', key);
              console.log('[webRequest] TOKEN COMPLETO:', tokenValue);
              break;
            }
          }
          
          if (tokenValue && tokenValue !== config.lastCapturedToken) {
            config.lastCapturedToken = tokenValue;
            
            console.log('[Main] TOKEN CAPTURADO:', foundHeaderName, 'para tab:', tabId);
            
            let domain = 'unknown';
            try { domain = new URL(details.url).hostname; } catch {}
            
            const timestamp = new Date().toLocaleTimeString('pt-BR', { 
              hour: '2-digit', 
              minute: '2-digit', 
              second: '2-digit' 
            });
            
            const notification = new Notification({
              title: '🔑 Token Capturado',
              body: `Domínio: ${domain}\nCapturado às ${timestamp}`,
              icon: path.join(__dirname, '../build/icon.png'),
              silent: false,
            });
            notification.show();
            
            if (mainWindow && !mainWindow.isDestroyed()) {
              console.log('[Main] ===========================================');
              console.log('[Main] Enviando token para mainWindow...');
              console.log('[Main] -> tabId:', tabId);
              console.log('[Main] -> domain:', domain);
              console.log('[Main] -> tokenName:', foundHeaderName);
              console.log('[Main] -> tokenLength:', tokenValue?.length);
              console.log('[Main] ===========================================');
              
              mainWindow.webContents.send('token:captured', {
                tabId,
                domain,
                tokenName: foundHeaderName,
                tokenValue,
              });
              
              console.log('[Main] Token enviado para mainWindow via IPC - SUCESSO');
            }
          }
        }
      }
      
      callback({ requestHeaders: details.requestHeaders });
    }
  );
  
  createWindow();

  // Configurar handler de downloads para todas as sessões
  const defaultSession = session.defaultSession;
  
  // Handler para downloads
  defaultSession.on('will-download', (_event: Electron.Event, item: Electron.DownloadItem, _webContents: Electron.WebContents) => {
    const downloadsPath = app.getPath('downloads');
    const filename = item.getFilename();
    const savePath = getUniqueFilePath(downloadsPath, filename);
    const actualFilename = path.basename(savePath);
    
    console.log('[Main] Download iniciado:', filename, '-> salvando como:', actualFilename);
    item.setSavePath(savePath);
    
    item.on('done', (_event: Electron.Event, state: string) => {
      if (state === 'completed') {
        console.log('[Main] Download concluído:', savePath);
        
        // Adicionar à lista de downloads recentes
        const downloadItem: DownloadItem = {
          filename: actualFilename,
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
      const savePath = getUniqueFilePath(downloadsPath, filename);
      const actualFilename = path.basename(savePath);
      
      console.log('[Main] Download iniciado (partition):', filename, '-> salvando como:', actualFilename);
      item.setSavePath(savePath);
      
      item.on('done', (_event: Electron.Event, state: string) => {
        if (state === 'completed') {
          console.log('[Main] Download concluído (partition):', savePath);
          
          const downloadItem: DownloadItem = {
            filename: actualFilename,
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

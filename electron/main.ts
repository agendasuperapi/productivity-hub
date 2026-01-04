import { app, BrowserWindow, ipcMain, globalShortcut, shell, webContents, dialog, clipboard, session, Notification, screen, Menu, MenuItem, nativeImage, net } from 'electron';
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

// Store para form fields locais (resposta instantânea)
const formFieldStore = new Store({
  name: isDev ? 'form-fields-dev' : 'form-fields',
  defaults: {
    fields: {} as Record<string, string[]> // { "domain|fieldId": ["valor1", "valor2", ...] }
  }
});

// Store para credenciais locais (offline + resposta instantânea)
interface LocalCredential {
  id: string;
  domain: string;
  username: string;
  encrypted_password: string;
  site_name?: string | null;
  created_at: string;
  updated_at: string;
  synced: boolean;
}

const credentialStore = new Store({
  name: isDev ? 'credentials-dev' : 'credentials',
  encryptionKey: 'gerenciazap-credentials-key-2024',
  defaults: {
    credentials: [] as LocalCredential[]
  }
});

// Store para domínios bloqueados locais (offline + resposta instantânea)
const blockedDomainsStore = new Store({
  name: isDev ? 'blocked-domains-dev' : 'blocked-domains',
  defaults: {
    domains: [] as string[]
  }
});

// Store para dados do browser (grupos e abas) - cache local para offline
const browserDataStore = new Store({
  name: isDev ? 'browser-data-dev' : 'browser-data',
  defaults: {
    tabGroups: [] as any[],
    tabs: [] as any[],
    lastSync: null as string | null
  }
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

// Set para rastrear sessões que já têm o listener de token configurado
const configuredTokenSessions = new Set<string>();

// Função para configurar captura de token em uma sessão específica
function setupTokenCaptureForSession(partitionName: string) {
  if (configuredTokenSessions.has(partitionName)) {
    console.log('[Main] Sessão já configurada para captura de token:', partitionName);
    return;
  }
  
  console.log('[Main] ========================================');
  console.log('[Main] Configurando captura de token para sessão:', partitionName);
  console.log('[Main] ========================================');
  configuredTokenSessions.add(partitionName);
  
  const targetSession = session.fromPartition(partitionName);
  
  targetSession.webRequest.onBeforeSendHeaders(
    { urls: ['*://*/*'] },
    (details, callback) => {
      // Log inicial para debug de todas as requisições (apenas domínios relevantes)
      const requestUrl = details.url.toLowerCase();
      const isRelevantRequest = requestUrl.includes('pdcapi.io') || requestUrl.includes('dashboard.bz');
      
      if (isRelevantRequest) {
        console.log(`[webRequest:${partitionName}] Requisição interceptada:`, details.url.substring(0, 100));
        console.log(`[webRequest:${partitionName}] Total configs ativas:`, tokenCaptureConfigs.size);
      }
      
      // Verificar todas as configs de captura ativas
      for (const [tabId, config] of tokenCaptureConfigs.entries()) {
        // Normalizar domínios (remover protocolo e trailing slash)
        const normalizeUrl = (url: string) => url.replace(/^https?:\/\//, '').replace(/\/$/, '').toLowerCase();
        
        // Verificar se a URL da requisição corresponde ao domínio principal ou alternativo
        const isTargetDomain = config.alternativeDomains.some(d => {
          const normalizedDomain = normalizeUrl(d);
          const matches = requestUrl.includes(normalizedDomain);
          if (isRelevantRequest) {
            console.log(`[webRequest:${partitionName}] Verificando domínio: ${normalizedDomain} -> match: ${matches}`);
          }
          return matches;
        });
        
        // DEBUG: Log para requisições relevantes
        if (isRelevantRequest) {
          console.log(`[webRequest:${partitionName}] Tab: ${tabId}`);
          console.log(`[webRequest:${partitionName}] -> headerName: ${config.headerName}`);
          console.log(`[webRequest:${partitionName}] -> alternativeDomains:`, JSON.stringify(config.alternativeDomains));
          console.log(`[webRequest:${partitionName}] -> isTargetDomain:`, isTargetDomain);
          console.log(`[webRequest:${partitionName}] -> Headers:`, Object.keys(details.requestHeaders));
        }
        
        if (isTargetDomain) {
          const headers = details.requestHeaders;
          let tokenValue: string | null = null;
          let foundHeaderName = config.headerName;
          
          for (const [key, value] of Object.entries(headers)) {
            if (key.toLowerCase() === config.headerName.toLowerCase()) {
              tokenValue = value as string;
              foundHeaderName = key;
              console.log(`[webRequest:${partitionName}] HEADER ENCONTRADO:`, key);
              console.log(`[webRequest:${partitionName}] TOKEN COMPLETO:`, tokenValue);
              break;
            }
          }
          
          if (tokenValue && tokenValue !== config.lastCapturedToken) {
            config.lastCapturedToken = tokenValue;
            
            console.log(`[Main:${partitionName}] TOKEN CAPTURADO:`, foundHeaderName, 'para tab:', tabId);
            
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
              console.log('[Main] -> partition:', partitionName);
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
}

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

// Função para verificar se uma posição está visível em algum monitor
// ============ CONTEXT MENU FOR WEBVIEWS ============

function setupWebviewContextMenu(webContents: Electron.WebContents) {
  webContents.on('context-menu', (e, params) => {
    const menu = new Menu();
    
    // Se há texto selecionado
    if (params.selectionText && params.selectionText.trim()) {
      menu.append(new MenuItem({
        label: 'Copiar',
        accelerator: 'CmdOrCtrl+C',
        click: () => webContents.copy()
      }));
      
      const searchText = params.selectionText.length > 30 
        ? params.selectionText.substring(0, 30) + '...' 
        : params.selectionText;
      menu.append(new MenuItem({
        label: `Pesquisar "${searchText}"`,
        click: () => {
          const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(params.selectionText)}`;
          shell.openExternal(searchUrl);
        }
      }));
      
      menu.append(new MenuItem({
        label: 'Traduzir para português',
        click: () => {
          const text = encodeURIComponent(params.selectionText);
          const translateUrl = `https://translate.google.com/?sl=auto&tl=pt&text=${text}&op=translate`;
          shell.openExternal(translateUrl);
        }
      }));
      
      menu.append(new MenuItem({ type: 'separator' }));
    }
    
    // Se é um link
    if (params.linkURL) {
      menu.append(new MenuItem({
        label: 'Abrir em janela flutuante',
        click: () => {
          // Criar janela flutuante a partir da URL (função definida mais abaixo)
          createFloatingWindowFromUrl(params.linkURL);
        }
      }));
      
      menu.append(new MenuItem({
        label: 'Abrir no navegador',
        click: () => shell.openExternal(params.linkURL)
      }));
      
      menu.append(new MenuItem({
        label: 'Copiar link',
        click: () => clipboard.writeText(params.linkURL)
      }));
      
      menu.append(new MenuItem({ type: 'separator' }));
    }
    
    // Se é uma imagem
    if (params.mediaType === 'image' && params.srcURL) {
      menu.append(new MenuItem({
        label: 'Copiar imagem',
        click: () => webContents.copyImageAt(params.x, params.y)
      }));
      
      menu.append(new MenuItem({
        label: 'Copiar endereço da imagem',
        click: () => clipboard.writeText(params.srcURL)
      }));
      
      menu.append(new MenuItem({
        label: 'Abrir imagem no navegador',
        click: () => shell.openExternal(params.srcURL)
      }));
      
      menu.append(new MenuItem({
        label: 'Salvar imagem como...',
        click: async () => {
          try {
            const urlParts = params.srcURL.split('/');
            let defaultName = urlParts[urlParts.length - 1].split('?')[0] || 'imagem';
            
            if (!defaultName.match(/\.(jpg|jpeg|png|gif|webp|svg|ico|bmp)$/i)) {
              defaultName += '.jpg';
            }
            
            const { filePath } = await dialog.showSaveDialog({
              title: 'Salvar imagem',
              defaultPath: path.join(app.getPath('downloads'), defaultName),
              filters: [
                { name: 'Imagens', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'] },
                { name: 'Todos os arquivos', extensions: ['*'] }
              ]
            });
            
            if (filePath) {
              const request = net.request({
                url: params.srcURL,
                session: webContents.session
              });
              
              const chunks: Buffer[] = [];
              request.on('response', (response: Electron.IncomingMessage) => {
                response.on('data', (chunk: Buffer) => chunks.push(chunk));
                response.on('end', () => {
                  const buffer = Buffer.concat(chunks);
                  fs.writeFileSync(filePath, buffer);
                  shell.showItemInFolder(filePath);
                });
              });
              request.on('error', (error: Error) => {
                console.error('[ContextMenu] Erro ao baixar imagem:', error);
              });
              request.end();
            }
          } catch (err) {
            console.error('[ContextMenu] Erro ao salvar imagem:', err);
          }
        }
      }));
      
      menu.append(new MenuItem({ type: 'separator' }));
    }
    
    // Se há campo de input editável
    if (params.isEditable) {
      if (params.editFlags.canCut) {
        menu.append(new MenuItem({
          label: 'Recortar',
          accelerator: 'CmdOrCtrl+X',
          click: () => webContents.cut()
        }));
      }
      if (params.editFlags.canCopy) {
        menu.append(new MenuItem({
          label: 'Copiar',
          accelerator: 'CmdOrCtrl+C',
          click: () => webContents.copy()
        }));
      }
      if (params.editFlags.canPaste) {
        menu.append(new MenuItem({
          label: 'Colar',
          accelerator: 'CmdOrCtrl+V',
          click: () => webContents.paste()
        }));
      }
      if (params.editFlags.canSelectAll) {
        menu.append(new MenuItem({
          label: 'Selecionar tudo',
          accelerator: 'CmdOrCtrl+A',
          click: () => webContents.selectAll()
        }));
      }
      
      menu.append(new MenuItem({ type: 'separator' }));
    }
    
    // Opções de navegação (sempre disponíveis)
    menu.append(new MenuItem({
      label: 'Voltar',
      enabled: webContents.canGoBack(),
      click: () => webContents.goBack()
    }));
    
    menu.append(new MenuItem({
      label: 'Avançar',
      enabled: webContents.canGoForward(),
      click: () => webContents.goForward()
    }));
    
    menu.append(new MenuItem({
      label: 'Recarregar',
      accelerator: 'CmdOrCtrl+R',
      click: () => webContents.reload()
    }));
    
    menu.append(new MenuItem({ type: 'separator' }));
    
    menu.append(new MenuItem({
      label: 'Inspecionar elemento',
      click: () => webContents.inspectElement(params.x, params.y)
    }));
    
    menu.popup();
  });
}

function isPositionVisible(x: number, y: number, width: number, height: number): boolean {
  const displays = screen.getAllDisplays();
  // Verificar se pelo menos 100px da janela está visível em algum monitor
  for (const display of displays) {
    const { x: dx, y: dy, width: dw, height: dh } = display.bounds;
    
    const overlapX = Math.max(0, Math.min(x + width, dx + dw) - Math.max(x, dx));
    const overlapY = Math.max(0, Math.min(y + height, dy + dh) - Math.max(y, dy));
    
    if (overlapX > 100 && overlapY > 100) {
      return true;
    }
  }
  return false;
}

function createWindow() {
  // Restaurar bounds salvos da janela principal
  const savedMainBounds = store.get('mainWindowBounds', null) as { x: number; y: number; width: number; height: number } | null;
  
  const windowOptions: Electron.BrowserWindowConstructorOptions = {
    width: savedMainBounds?.width || 1400,
    height: savedMainBounds?.height || 900,
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
  };

  // Aplicar posição salva se disponível E visível em algum monitor
  if (savedMainBounds?.x !== undefined && savedMainBounds?.y !== undefined) {
    const width = savedMainBounds.width || 1400;
    const height = savedMainBounds.height || 900;
    if (isPositionVisible(savedMainBounds.x, savedMainBounds.y, width, height)) {
      windowOptions.x = savedMainBounds.x;
      windowOptions.y = savedMainBounds.y;
    } else {
      console.log('[Main] Posição principal salva fora da tela, centralizando janela');
    }
  }

  mainWindow = new BrowserWindow(windowOptions);

  // Evento para informar mudanças no estado de maximização
  mainWindow.on('maximize', () => {
    mainWindow?.webContents.send('window:maximizeChange', true);
  });
  
  mainWindow.on('unmaximize', () => {
    mainWindow?.webContents.send('window:maximizeChange', false);
  });

  // Capturar botões laterais do mouse (voltar/avançar) na janela principal
  mainWindow.on('app-command', (e, cmd) => {
    if (cmd === 'browser-backward') {
      mainWindow?.webContents.send('navigate:back');
    } else if (cmd === 'browser-forward') {
      mainWindow?.webContents.send('navigate:forward');
    }
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

// ============ MAIN WINDOW BOUNDS ============

ipcMain.handle('mainWindow:saveBounds', () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    const [x, y] = mainWindow.getPosition();
    const [width, height] = mainWindow.getSize();
    store.set('mainWindowBounds', { x, y, width, height });
    console.log('[Main] Posição da janela principal salva:', { x, y, width, height });
    return { success: true };
  }
  return { success: false };
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
  urls?: { url: string; shortcut_enabled?: boolean; zoom?: number; session_group?: string }[];
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
  link_click_behavior?: 'same_window' | 'floating_window' | 'external_browser';
  session_group?: string;
}

ipcMain.handle('window:create', async (_, tab: TabData) => {
  console.log('[Main] *** VERSÃO 1.0.10 DO HANDLER window:create ***');
  try {
    // Verificar se a janela já existe
    if (openWindows.has(tab.id)) {
      const existingWindow = openWindows.get(tab.id);
      if (existingWindow && !existingWindow.isDestroyed()) {
        // Restaurar se estiver minimizada
        if (existingWindow.isMinimized()) {
          existingWindow.restore();
        }
        // Mostrar janela (caso esteja oculta)
        existingWindow.show();
        // Focar na janela
        existingWindow.focus();
      }
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

    // Aplicar posição salva se disponível E visível em algum monitor
    if (tab.window_x !== undefined && tab.window_x !== null &&
        tab.window_y !== undefined && tab.window_y !== null) {
      const windowWidth = tab.window_width || 1200;
      const windowHeight = tab.window_height || 800;
      
      if (isPositionVisible(tab.window_x, tab.window_y, windowWidth, windowHeight)) {
        windowOptions.x = tab.window_x;
        windowOptions.y = tab.window_y;
      } else {
        console.log('[Main] Posição da janela flutuante fora da tela, centralizando:', tab.name);
      }
    }

    const window = new BrowserWindow(windowOptions);
    
    // Configurar menu de contexto para webviews dentro desta janela
    window.webContents.on('did-attach-webview', (_, webviewContents) => {
      setupWebviewContextMenu(webviewContents);
    });
    
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

    // Determinar a partition que será usada pela janela
    const firstUrlSessionGroup = tab.urls && tab.urls.length > 0 ? tab.urls[0].session_group : undefined;
    const sessionGroup = firstUrlSessionGroup || tab.session_group;
    const partitionName = sessionGroup ? `persist:${sessionGroup}` : 'persist:floating-webview';
    
    // Adicionar config de captura de token ao Map global E configurar listener para a sessão
    if (tab.capture_token === true) {  // Comparação estrita
      console.log('[Main] Adicionando config de captura para tab:', tab.id);
      console.log('[Main] -> header:', tab.capture_token_header || 'X-Access-Token');
      console.log('[Main] -> alternative_domains:', JSON.stringify(tab.alternative_domains));
      console.log('[Main] -> partition:', partitionName);
      
      // IMPORTANTE: Adicionar config ANTES de configurar a sessão
      tokenCaptureConfigs.set(tab.id, {
        headerName: tab.capture_token_header || 'X-Access-Token',
        alternativeDomains: tab.alternative_domains || [],
        lastCapturedToken: null,
      });
      
      console.log('[Main] tokenCaptureConfigs atualizado. Total:', tokenCaptureConfigs.size);
      console.log('[Main] Configs ativas:', Array.from(tokenCaptureConfigs.keys()));
      
      // Configurar captura de token para esta sessão específica
      setupTokenCaptureForSession(partitionName);
    }

    // Enviar configuração após o HTML carregar
    // Usar pequeno delay para garantir que o preload está pronto
    window.webContents.once('did-finish-load', () => {
      // Determinar session_group da primeira URL (se houver)
      const firstUrlSessionGroup = tab.urls && tab.urls.length > 0 ? tab.urls[0].session_group : undefined;
      const sessionGroup = firstUrlSessionGroup || tab.session_group;
      
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
        linkClickBehavior: tab.link_click_behavior || 'same_window',
        sessionGroup: sessionGroup,
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

    // Capturar botões laterais do mouse (voltar/avançar)
    window.on('app-command', (e, cmd) => {
      if (cmd === 'browser-backward') {
        window.webContents.send('navigate:back');
      } else if (cmd === 'browser-forward') {
        window.webContents.send('navigate:forward');
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

// Função helper para criar janela flutuante a partir de URL (usada pelo context menu e IPC)
function createFloatingWindowFromUrl(url: string, name?: string) {
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
  
  // Configurar menu de contexto para webviews dentro desta janela
  window.webContents.on('did-attach-webview', (_, webviewContents) => {
    setupWebviewContextMenu(webviewContents);
  });
  
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

  // Capturar botões laterais do mouse (voltar/avançar)
  window.on('app-command', (e, cmd) => {
    if (cmd === 'browser-backward') {
      window.webContents.send('navigate:back');
    } else if (cmd === 'browser-forward') {
      window.webContents.send('navigate:forward');
    }
  });

  window.on('closed', () => {
    openWindows.delete(urlId);
    floatingWindowData.delete(urlId);
  });
}

// Handler IPC para abrir URL em nova janela flutuante
ipcMain.on('floating:openInFloatingWindow', (_, url: string, name?: string) => {
  createFloatingWindowFromUrl(url, name);
});

// Handler para abrir configurações da aba na janela principal
ipcMain.on('floating:openTabSettings', (event) => {
  // Encontrar qual janela enviou o evento
  for (const [tabId, window] of openWindows.entries()) {
    if (window.webContents.id === event.sender.id) {
      console.log('[Main] Opening tab settings for:', tabId);
      
      // Enviar para a janela principal para abrir o dialog de edição
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('tab:openSettings', tabId);
        mainWindow.focus(); // Trazer janela principal para frente
      }
      break;
    }
  }
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
          console.log('[Main] Credenciais recebidas do BrowserContext:', credentials?.length || 0);
          resolve({ success: true, credentials: credentials || [] });
        });
        
        mainWindow!.webContents.send('credential:get', { url, responseChannel });
        
        // Timeout de 5 segundos
        setTimeout(() => {
          console.log('[Main] Timeout ao buscar credenciais');
          resolve({ success: false, credentials: [] });
        }, 5000);
      });
    }
    
    return { success: false, credentials: [] };
  } catch (error: any) {
    console.error('[Main] Erro ao buscar credenciais:', error);
    return { success: false, credentials: [], error: error.message };
  }
});

// Handler para bloquear domínio (nunca salvar credenciais)
ipcMain.handle('floating:blockCredentialDomain', async (_, domain: string) => {
  try {
    console.log('[Main] Bloqueando domínio para credenciais:', domain);
    
    if (mainWindow && !mainWindow.isDestroyed()) {
      return new Promise((resolve) => {
        const responseChannel = `credential:blockDomain:response:${Date.now()}`;
        
        ipcMain.once(responseChannel, (_, result) => {
          console.log('[Main] Resultado do bloqueio:', result);
          resolve(result);
        });
        
        mainWindow!.webContents.send('credential:blockDomain', { domain, responseChannel });
        
        setTimeout(() => {
          console.log('[Main] Timeout ao bloquear domínio');
          resolve({ success: false });
        }, 5000);
      });
    }
    
    return { success: false };
  } catch (error: any) {
    console.error('[Main] Erro ao bloquear domínio:', error);
    return { success: false, error: error.message };
  }
});

// Handler para verificar se domínio está bloqueado
ipcMain.handle('floating:isCredentialDomainBlocked', async (_, domain: string) => {
  try {
    console.log('[Main] Verificando se domínio está bloqueado:', domain);
    
    if (mainWindow && !mainWindow.isDestroyed()) {
      return new Promise((resolve) => {
        const responseChannel = `credential:isBlocked:response:${Date.now()}`;
        
        ipcMain.once(responseChannel, (_, result) => {
          console.log('[Main] Resultado da verificação:', result);
          resolve(result);
        });
        
        mainWindow!.webContents.send('credential:isBlocked', { domain, responseChannel });
        
        setTimeout(() => {
          console.log('[Main] Timeout ao verificar bloqueio');
          resolve({ blocked: false });
        }, 5000);
      });
    }
    
    return { blocked: false };
  } catch (error: any) {
    console.error('[Main] Erro ao verificar bloqueio:', error);
    return { blocked: false, error: error.message };
  }
});

// Handler para salvar campo de formulário - LOCAL STORAGE (resposta instantânea)
ipcMain.handle('floating:saveFormField', async (_, data: { domain: string; field: string; value: string; label?: string }) => {
  try {
    const key = `${data.domain}|${data.field}`;
    const fields = formFieldStore.get('fields', {}) as Record<string, string[]>;
    
    if (!fields[key]) {
      fields[key] = [];
    }
    
    // Adicionar valor se não existir (mais recente primeiro)
    if (!fields[key].includes(data.value)) {
      fields[key].unshift(data.value);
      // Limitar a 20 sugestões por campo
      if (fields[key].length > 20) {
        fields[key] = fields[key].slice(0, 20);
      }
      formFieldStore.set('fields', fields);
      console.log('[Main] Form field salvo localmente:', key, '- Total:', fields[key].length);
    }
    
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao salvar campo de formulário:', error);
    return { success: false, error: error.message };
  }
});

// Handler para buscar sugestões de campos de formulário - LOCAL STORAGE (resposta instantânea)
ipcMain.handle('floating:getFormFieldSuggestions', async (_, data: { domain: string; field: string }) => {
  try {
    const key = `${data.domain}|${data.field}`;
    const fields = formFieldStore.get('fields', {}) as Record<string, string[]>;
    const suggestions = fields[key] || [];
    console.log('[Main] Form field sugestões:', key, '- Encontradas:', suggestions.length);
    return suggestions;
  } catch (error: any) {
    console.error('[Main] Erro ao buscar sugestões:', error);
    return [];
  }
});

// Handler para limpar sugestões de um domínio
ipcMain.handle('floating:clearFormFieldsForDomain', async (_, domain: string) => {
  try {
    const fields = formFieldStore.get('fields', {}) as Record<string, string[]>;
    const keysToDelete = Object.keys(fields).filter(key => key.startsWith(domain + '|'));
    keysToDelete.forEach(key => delete fields[key]);
    formFieldStore.set('fields', fields);
    console.log('[Main] Form fields limpos para domínio:', domain, '- Removidos:', keysToDelete.length);
    return { success: true, deleted: keysToDelete.length };
  } catch (error: any) {
    console.error('[Main] Erro ao limpar campos de formulário:', error);
    return { success: false, deleted: 0 };
  }
});

// Handler para listar domínios com sugestões salvas
ipcMain.handle('floating:getFormFieldDomains', async () => {
  try {
    const fields = formFieldStore.get('fields', {}) as Record<string, string[]>;
    const domainCounts: Record<string, number> = {};
    
    Object.keys(fields).forEach(key => {
      const domain = key.split('|')[0];
      domainCounts[domain] = (domainCounts[domain] || 0) + fields[key].length;
    });
    
    const domains = Object.entries(domainCounts).map(([domain, count]) => ({
      domain,
      valueCount: count
    }));
    
    console.log('[Main] Form field domínios:', domains.length);
    return domains;
  } catch (error: any) {
    console.error('[Main] Erro ao listar domínios:', error);
    return [];
  }
});

// ============ LOCAL CREDENTIALS (armazenamento offline) ============

// Handler para salvar credencial local
ipcMain.handle('credential:saveLocal', async (_, credential: LocalCredential) => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    
    // Verificar se já existe (mesmo id ou mesmo domain+username)
    const existingIndex = credentials.findIndex(c => 
      c.id === credential.id || 
      (c.domain === credential.domain && c.username === credential.username)
    );
    
    if (existingIndex >= 0) {
      // Atualizar existente
      credentials[existingIndex] = { ...credential, updated_at: new Date().toISOString() };
    } else {
      // Adicionar novo
      credentials.push(credential);
    }
    
    credentialStore.set('credentials', credentials);
    console.log('[Main] Credencial local salva:', credential.domain, credential.username);
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao salvar credencial local:', error);
    return { success: false, error: error.message };
  }
});

// Handler para buscar credenciais por domínio
ipcMain.handle('credential:getLocalByDomain', async (_, domain: string) => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    const filtered = credentials.filter(c => c.domain === domain);
    console.log('[Main] Credenciais locais para', domain, ':', filtered.length);
    return filtered;
  } catch (error: any) {
    console.error('[Main] Erro ao buscar credenciais locais:', error);
    return [];
  }
});

// Handler para buscar todas as credenciais locais
ipcMain.handle('credential:getAllLocal', async () => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    console.log('[Main] Total credenciais locais:', credentials.length);
    return credentials;
  } catch (error: any) {
    console.error('[Main] Erro ao buscar todas credenciais locais:', error);
    return [];
  }
});

// Handler para deletar credencial local
ipcMain.handle('credential:deleteLocal', async (_, id: string) => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    const filtered = credentials.filter(c => c.id !== id);
    credentialStore.set('credentials', filtered);
    console.log('[Main] Credencial local deletada:', id);
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao deletar credencial local:', error);
    return { success: false, error: error.message };
  }
});

// Handler para marcar credencial como sincronizada
ipcMain.handle('credential:markSynced', async (_, id: string) => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    const index = credentials.findIndex(c => c.id === id);
    
    if (index >= 0) {
      credentials[index].synced = true;
      credentialStore.set('credentials', credentials);
      console.log('[Main] Credencial marcada como sincronizada:', id);
    }
    
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao marcar sincronizado:', error);
    return { success: false, error: error.message };
  }
});

// Handler para buscar credenciais não sincronizadas
ipcMain.handle('credential:getUnsynced', async () => {
  try {
    const credentials = credentialStore.get('credentials', []) as LocalCredential[];
    const unsynced = credentials.filter(c => !c.synced);
    console.log('[Main] Credenciais não sincronizadas:', unsynced.length);
    return unsynced;
  } catch (error: any) {
    console.error('[Main] Erro ao buscar não sincronizados:', error);
    return [];
  }
});

// Handler para sincronizar credenciais do Supabase para local
ipcMain.handle('credential:syncFromSupabase', async (_, credentials: LocalCredential[]) => {
  try {
    // Mesclar com credenciais locais, preferindo as do Supabase
    const local = credentialStore.get('credentials', []) as LocalCredential[];
    const merged = [...credentials.map(c => ({ ...c, synced: true }))];
    
    // Adicionar credenciais locais não sincronizadas que não existem no Supabase
    local.forEach(localCred => {
      if (!localCred.synced) {
        const existsInSupabase = credentials.some(c => 
          c.domain === localCred.domain && c.username === localCred.username
        );
        if (!existsInSupabase) {
          merged.push(localCred);
        }
      }
    });
    
    credentialStore.set('credentials', merged);
    console.log('[Main] Credenciais sincronizadas do Supabase:', credentials.length, '- Total local:', merged.length);
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao sincronizar do Supabase:', error);
    return { success: false, error: error.message };
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

// ============ BLOCKED DOMAINS LOCAL STORE ============

ipcMain.handle('blockedDomains:getLocal', () => {
  return blockedDomainsStore.get('domains', []);
});

ipcMain.handle('blockedDomains:addLocal', (_, domain: string) => {
  const domains = blockedDomainsStore.get('domains', []) as string[];
  const normalizedDomain = domain.toLowerCase();
  if (!domains.includes(normalizedDomain)) {
    domains.push(normalizedDomain);
    blockedDomainsStore.set('domains', domains);
    console.log('[Main] Domínio bloqueado adicionado localmente:', normalizedDomain);
  }
  return { success: true };
});

ipcMain.handle('blockedDomains:removeLocal', (_, domain: string) => {
  const domains = blockedDomainsStore.get('domains', []) as string[];
  const normalizedDomain = domain.toLowerCase();
  const filtered = domains.filter((d: string) => d !== normalizedDomain);
  blockedDomainsStore.set('domains', filtered);
  console.log('[Main] Domínio desbloqueado localmente:', normalizedDomain);
  return { success: true };
});

ipcMain.handle('blockedDomains:syncFromSupabase', (_, domains: string[]) => {
  blockedDomainsStore.set('domains', domains.map((d: string) => d.toLowerCase()));
  console.log('[Main] Domínios bloqueados sincronizados do Supabase:', domains.length);
  return { success: true };
});

ipcMain.handle('blockedDomains:isBlocked', (_, domain: string) => {
  const domains = blockedDomainsStore.get('domains', []) as string[];
  const normalizedDomain = domain.toLowerCase();
  return domains.includes(normalizedDomain);
});

// ============ BROWSER DATA LOCAL STORE (offline cache) ============

ipcMain.handle('browserData:getLocal', () => {
  return {
    tabGroups: browserDataStore.get('tabGroups', []),
    tabs: browserDataStore.get('tabs', []),
    lastSync: browserDataStore.get('lastSync')
  };
});

ipcMain.handle('browserData:saveLocal', (_, data: { tabGroups?: any[]; tabs?: any[] }) => {
  if (data.tabGroups) browserDataStore.set('tabGroups', data.tabGroups);
  if (data.tabs) browserDataStore.set('tabs', data.tabs);
  browserDataStore.set('lastSync', new Date().toISOString());
  console.log('[Main] Dados do browser salvos localmente:', {
    groups: data.tabGroups?.length || 0,
    tabs: data.tabs?.length || 0
  });
  return { success: true };
});

// ============ DATA CLEANUP ============

ipcMain.handle('credential:deleteByDomain', async (_, domain: string) => {
  const credentials = credentialStore.get('credentials', []) as LocalCredential[];
  const normalizedDomain = domain.toLowerCase();
  const filtered = credentials.filter(c => !c.domain.toLowerCase().includes(normalizedDomain));
  const deleted = credentials.length - filtered.length;
  credentialStore.set('credentials', filtered);
  console.log('[Main] Credenciais deletadas para domínio:', normalizedDomain, '- Total:', deleted);
  return { success: true, deleted };
});

ipcMain.handle('session:clearData', async (_, partitionName: string) => {
  try {
    const targetSession = session.fromPartition(partitionName);
    await targetSession.clearStorageData({
      storages: ['cookies', 'localstorage', 'indexdb', 'serviceworkers', 'cachestorage']
    });
    console.log('[Main] Dados da sessão limpos:', partitionName);
    return { success: true };
  } catch (error: any) {
    console.error('[Main] Erro ao limpar sessão:', error);
    return { success: false, error: error.message };
  }
});

// ============ APP LIFECYCLE ============

app.whenReady().then(() => {
  // Configurar captura de token para a sessão padrão de janelas flutuantes
  setupTokenCaptureForSession('persist:floating-webview');
  
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
    // ====== EXTENSÃO DE COOKIES DE SESSÃO (30 dias) ======
    // Intercepta cookies sem expiração e adiciona 30 dias
    createdSession.webRequest.onHeadersReceived({ urls: ['*://*/*'] }, (details, callback) => {
      const setCookieHeaders = details.responseHeaders?.['set-cookie'] || 
                               details.responseHeaders?.['Set-Cookie'];
      
      if (setCookieHeaders && Array.isArray(setCookieHeaders)) {
        const modifiedCookies = setCookieHeaders.map((cookie: string) => {
          // Se o cookie não tem expiração (cookie de sessão), adicionar 30 dias
          if (!cookie.toLowerCase().includes('expires=') && 
              !cookie.toLowerCase().includes('max-age=')) {
            const expiryDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
            return `${cookie}; Expires=${expiryDate.toUTCString()}`;
          }
          return cookie;
        });
        
        if (details.responseHeaders) {
          delete details.responseHeaders['set-cookie'];
          delete details.responseHeaders['Set-Cookie'];
          details.responseHeaders['set-cookie'] = modifiedCookies;
        }
      }
      
      callback({ responseHeaders: details.responseHeaders });
    });
    
    // ====== HANDLER DE DOWNLOADS ======
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

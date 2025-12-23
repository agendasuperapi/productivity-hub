"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const path = __importStar(require("path"));
const supabase_electron_1 = require("./supabase-electron");
let mainWindow = null;
let userConfig = null;
const openWindows = new Map();
function createWindow() {
    mainWindow = new electron_1.BrowserWindow({
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
electron_1.ipcMain.handle('auth:login', async (_, email, password) => {
    try {
        const { data, error } = await supabase_electron_1.supabase.auth.signInWithPassword({
            email,
            password,
        });
        if (error) {
            throw error;
        }
        // Buscar configurações após login
        userConfig = await (0, supabase_electron_1.fetchUserConfig)();
        return {
            success: true,
            user: data.user,
            session: data.session,
            config: userConfig
        };
    }
    catch (error) {
        return {
            success: false,
            error: error.message || 'Erro no login'
        };
    }
});
// IPC: Logout
electron_1.ipcMain.handle('auth:logout', async () => {
    try {
        await supabase_electron_1.supabase.auth.signOut();
        userConfig = null;
        // Fechar todas as janelas abertas
        openWindows.forEach((window) => {
            window.close();
        });
        openWindows.clear();
        return { success: true };
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// IPC: Verificar sessão
electron_1.ipcMain.handle('auth:getSession', async () => {
    try {
        const { data: { session } } = await supabase_electron_1.supabase.auth.getSession();
        return { session };
    }
    catch (error) {
        return { session: null, error: error.message };
    }
});
// IPC: Buscar configurações
electron_1.ipcMain.handle('config:fetch', async () => {
    try {
        userConfig = await (0, supabase_electron_1.fetchUserConfig)();
        return { success: true, config: userConfig };
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// IPC: Obter configurações em cache
electron_1.ipcMain.handle('config:get', () => {
    return { success: true, config: userConfig };
});
// IPC: Criar nova janela para uma aba
electron_1.ipcMain.handle('window:create', async (_, tab) => {
    try {
        if (!tab.open_as_window) {
            return { success: false, error: 'Aba não configurada para abrir como janela' };
        }
        const window = new electron_1.BrowserWindow({
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
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// IPC: Registrar atalho de teclado global
electron_1.ipcMain.handle('shortcut:register', async (_, shortcut, tabId) => {
    try {
        const ret = electron_1.globalShortcut.register(shortcut, () => {
            mainWindow?.webContents.send('shortcut:triggered', tabId);
        });
        return { success: ret };
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// IPC: Desregistrar atalho
electron_1.ipcMain.handle('shortcut:unregister', async (_, shortcut) => {
    try {
        electron_1.globalShortcut.unregister(shortcut);
        return { success: true };
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// IPC: Desregistrar todos os atalhos
electron_1.ipcMain.handle('shortcut:unregisterAll', async () => {
    try {
        electron_1.globalShortcut.unregisterAll();
        return { success: true };
    }
    catch (error) {
        return { success: false, error: error.message };
    }
});
// Inicializar aplicação
electron_1.app.whenReady().then(() => {
    createWindow();
    electron_1.app.on('activate', () => {
        if (electron_1.BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});
electron_1.app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        electron_1.app.quit();
    }
});
electron_1.app.on('will-quit', () => {
    electron_1.globalShortcut.unregisterAll();
});
// Escutar mudanças de autenticação
supabase_electron_1.supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT') {
        userConfig = null;
        mainWindow?.webContents.send('auth:stateChanged', { signedIn: false });
    }
    else if (event === 'SIGNED_IN' && session) {
        mainWindow?.webContents.send('auth:stateChanged', { signedIn: true });
    }
});

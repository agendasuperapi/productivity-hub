import { contextBridge, ipcRenderer } from 'electron';
const electronAPI = {
    // Autenticação
    login: (email, password) => ipcRenderer.invoke('auth:login', email, password),
    logout: () => ipcRenderer.invoke('auth:logout'),
    getSession: () => ipcRenderer.invoke('auth:getSession'),
    // Configurações
    fetchConfig: () => ipcRenderer.invoke('config:fetch'),
    getConfig: () => ipcRenderer.invoke('config:get'),
    // Janelas
    createWindow: (tab) => ipcRenderer.invoke('window:create', tab),
    // Atalhos
    registerShortcut: (shortcut, tabId) => ipcRenderer.invoke('shortcut:register', shortcut, tabId),
    unregisterShortcut: (shortcut) => ipcRenderer.invoke('shortcut:unregister', shortcut),
    unregisterAllShortcuts: () => ipcRenderer.invoke('shortcut:unregisterAll'),
    // Eventos
    onAuthStateChanged: (callback) => {
        ipcRenderer.on('auth:stateChanged', (_, data) => callback(data));
    },
    onShortcutTriggered: (callback) => {
        ipcRenderer.on('shortcut:triggered', (_, tabId) => callback(tabId));
    },
    removeAllListeners: (channel) => {
        ipcRenderer.removeAllListeners(channel);
    },
};
// Expor API de forma segura
contextBridge.exposeInMainWorld('electronAPI', electronAPI);

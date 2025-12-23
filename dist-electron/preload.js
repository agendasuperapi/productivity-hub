"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const electronAPI = {
    // Autenticação
    login: (email, password) => electron_1.ipcRenderer.invoke('auth:login', email, password),
    logout: () => electron_1.ipcRenderer.invoke('auth:logout'),
    getSession: () => electron_1.ipcRenderer.invoke('auth:getSession'),
    // Configurações
    fetchConfig: () => electron_1.ipcRenderer.invoke('config:fetch'),
    getConfig: () => electron_1.ipcRenderer.invoke('config:get'),
    // Janelas
    createWindow: (tab) => electron_1.ipcRenderer.invoke('window:create', tab),
    // Atalhos
    registerShortcut: (shortcut, tabId) => electron_1.ipcRenderer.invoke('shortcut:register', shortcut, tabId),
    unregisterShortcut: (shortcut) => electron_1.ipcRenderer.invoke('shortcut:unregister', shortcut),
    unregisterAllShortcuts: () => electron_1.ipcRenderer.invoke('shortcut:unregisterAll'),
    // Eventos
    onAuthStateChanged: (callback) => {
        electron_1.ipcRenderer.on('auth:stateChanged', (_, data) => callback(data));
    },
    onShortcutTriggered: (callback) => {
        electron_1.ipcRenderer.on('shortcut:triggered', (_, tabId) => callback(tabId));
    },
    removeAllListeners: (channel) => {
        electron_1.ipcRenderer.removeAllListeners(channel);
    },
};
// Expor API de forma segura
electron_1.contextBridge.exposeInMainWorld('electronAPI', electronAPI);

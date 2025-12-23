(() => {
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });

  // electron/preload.ts
  var import_electron = __require("electron");
  var electronAPI = {
    // Autenticação
    login: (email, password) => import_electron.ipcRenderer.invoke("auth:login", email, password),
    logout: () => import_electron.ipcRenderer.invoke("auth:logout"),
    getSession: () => import_electron.ipcRenderer.invoke("auth:getSession"),
    // Configurações
    fetchConfig: () => import_electron.ipcRenderer.invoke("config:fetch"),
    getConfig: () => import_electron.ipcRenderer.invoke("config:get"),
    // Janelas
    createWindow: (tab) => import_electron.ipcRenderer.invoke("window:create", tab),
    // Atalhos
    registerShortcut: (shortcut, tabId) => import_electron.ipcRenderer.invoke("shortcut:register", shortcut, tabId),
    unregisterShortcut: (shortcut) => import_electron.ipcRenderer.invoke("shortcut:unregister", shortcut),
    unregisterAllShortcuts: () => import_electron.ipcRenderer.invoke("shortcut:unregisterAll"),
    // Eventos
    onAuthStateChanged: (callback) => {
      import_electron.ipcRenderer.on("auth:stateChanged", (_, data) => callback(data));
    },
    onShortcutTriggered: (callback) => {
      import_electron.ipcRenderer.on("shortcut:triggered", (_, tabId) => callback(tabId));
    },
    removeAllListeners: (channel) => {
      import_electron.ipcRenderer.removeAllListeners(channel);
    }
  };
  import_electron.contextBridge.exposeInMainWorld("electronAPI", electronAPI);
})();
//# sourceMappingURL=preload.js.map

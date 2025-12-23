(() => {
  // electron/renderer.ts
  var currentConfig = null;
  var activeTabId = null;
  var loginContainer = document.getElementById("login-container");
  var appContainer = document.getElementById("app-container");
  var loginForm = document.getElementById("login-form");
  var emailInput = document.getElementById("email");
  var passwordInput = document.getElementById("password");
  var loginError = document.getElementById("login-error");
  var sidebarGroups = document.getElementById("sidebar-groups");
  var mainContent = document.getElementById("main-content");
  var logoutBtn = document.getElementById("logout-btn");
  async function init() {
    try {
      const session = await window.electronAPI.getSession();
      if (session?.user) {
        await loadApp();
      } else {
        showLogin();
      }
    } catch (error) {
      console.error("Erro ao inicializar:", error);
      showLogin();
    }
  }
  function showLogin() {
    if (loginContainer) loginContainer.style.display = "flex";
    if (appContainer) appContainer.style.display = "none";
  }
  function showApp() {
    if (loginContainer) loginContainer.style.display = "none";
    if (appContainer) appContainer.style.display = "flex";
  }
  async function loadApp() {
    showApp();
    try {
      const config = await window.electronAPI.fetchConfig();
      if (config) {
        currentConfig = config;
        renderSidebar();
        registerShortcuts();
      }
    } catch (error) {
      console.error("Erro ao carregar configura\xE7\xF5es:", error);
    }
  }
  function renderSidebar() {
    if (!sidebarGroups || !currentConfig) return;
    sidebarGroups.innerHTML = "";
    const groups = currentConfig.tab_groups || [];
    const tabs = currentConfig.tabs || [];
    groups.sort((a, b) => a.position - b.position).forEach((group) => {
      const groupTabs = tabs.filter((tab) => tab.group_id === group.id);
      const groupElement = document.createElement("div");
      groupElement.className = "sidebar-group";
      groupElement.innerHTML = `
      <div class="group-header" style="color: ${group.color || "#888"}">
        <span class="group-icon">${group.icon || "\u{1F4C1}"}</span>
        <span class="group-name">${group.name}</span>
      </div>
      <div class="group-tabs"></div>
    `;
      const tabsContainer = groupElement.querySelector(".group-tabs");
      groupTabs.forEach((tab) => {
        const tabElement = document.createElement("div");
        tabElement.className = `tab-item ${activeTabId === tab.id ? "active" : ""}`;
        tabElement.dataset.tabId = tab.id;
        tabElement.innerHTML = `
        <span class="tab-icon" style="color: ${tab.color || "#666"}">${tab.icon || "\u{1F517}"}</span>
        <span class="tab-name">${tab.name}</span>
        ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ""}
      `;
        tabElement.addEventListener("click", () => openTab(tab));
        tabsContainer?.appendChild(tabElement);
      });
      sidebarGroups.appendChild(groupElement);
    });
  }
  async function openTab(tab) {
    activeTabId = tab.id;
    renderSidebar();
    try {
      await window.electronAPI.createWindow(tab);
    } catch (error) {
      console.error("Erro ao abrir aba:", error);
    }
  }
  async function registerShortcuts() {
    if (!currentConfig) return;
    await window.electronAPI.unregisterAllShortcuts();
    const tabs = currentConfig.tabs || [];
    for (const tab of tabs) {
      if (tab.keyboard_shortcut) {
        try {
          await window.electronAPI.registerShortcut(tab.keyboard_shortcut, tab.id);
        } catch (error) {
          console.error(`Erro ao registrar atalho ${tab.keyboard_shortcut}:`, error);
        }
      }
    }
  }
  loginForm?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = emailInput?.value;
    const password = passwordInput?.value;
    if (!email || !password) {
      if (loginError) loginError.textContent = "Preencha todos os campos";
      return;
    }
    try {
      const result = await window.electronAPI.login(email, password);
      if (result.error) {
        if (loginError) loginError.textContent = result.error.message || "Erro ao fazer login";
      } else {
        await loadApp();
      }
    } catch (error) {
      if (loginError) loginError.textContent = error.message || "Erro ao fazer login";
    }
  });
  logoutBtn?.addEventListener("click", async () => {
    try {
      await window.electronAPI.logout();
      currentConfig = null;
      activeTabId = null;
      showLogin();
    } catch (error) {
      console.error("Erro ao fazer logout:", error);
    }
  });
  window.electronAPI.onShortcutTriggered((tabId) => {
    if (!currentConfig) return;
    const tab = currentConfig.tabs?.find((t) => t.id === tabId);
    if (tab) {
      openTab(tab);
    }
  });
  window.electronAPI.onAuthStateChanged((data) => {
    if (data.event === "SIGNED_OUT") {
      currentConfig = null;
      activeTabId = null;
      showLogin();
    } else if (data.event === "SIGNED_IN" && data.session) {
      loadApp();
    }
  });
  document.addEventListener("DOMContentLoaded", init);
})();
//# sourceMappingURL=renderer.js.map

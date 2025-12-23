// @ts-nocheck
// Renderer script - Interface lógica para o Electron
// Este arquivo é compilado separadamente pelo tsconfig.electron.json

interface Tab {
  id: string;
  name: string;
  url: string;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  zoom?: number;
  group_id: string;
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  tabs: Tab[];
}

interface UserConfig {
  tab_groups: TabGroup[];
  tabs: Tab[];
}

// Estado da aplicação
let currentConfig: UserConfig | null = null;
let activeTabId: string | null = null;

// Elementos DOM
const loginContainer = document.getElementById('login-container');
const appContainer = document.getElementById('app-container');
const loginForm = document.getElementById('login-form');
const emailInput = document.getElementById('email') as HTMLInputElement;
const passwordInput = document.getElementById('password') as HTMLInputElement;
const loginError = document.getElementById('login-error');
const sidebarGroups = document.getElementById('sidebar-groups');
const mainContent = document.getElementById('main-content');
const logoutBtn = document.getElementById('logout-btn');

// Inicialização
async function init() {
  try {
    const session = await window.electronAPI.getSession();
    if (session?.user) {
      await loadApp();
    } else {
      showLogin();
    }
  } catch (error) {
    console.error('Erro ao inicializar:', error);
    showLogin();
  }
}

// Mostrar tela de login
function showLogin() {
  if (loginContainer) loginContainer.style.display = 'flex';
  if (appContainer) appContainer.style.display = 'none';
}

// Mostrar aplicação
function showApp() {
  if (loginContainer) loginContainer.style.display = 'none';
  if (appContainer) appContainer.style.display = 'flex';
}

// Carregar aplicação após login
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
    console.error('Erro ao carregar configurações:', error);
  }
}

// Renderizar sidebar com grupos e abas
function renderSidebar() {
  if (!sidebarGroups || !currentConfig) return;
  
  sidebarGroups.innerHTML = '';
  
  const groups = currentConfig.tab_groups || [];
  const tabs = currentConfig.tabs || [];
  
  groups.sort((a, b) => a.position - b.position).forEach(group => {
    const groupTabs = tabs.filter(tab => tab.group_id === group.id);
    
    const groupElement = document.createElement('div');
    groupElement.className = 'sidebar-group';
    groupElement.innerHTML = `
      <div class="group-header" style="color: ${group.color || '#888'}">
        <span class="group-icon">${group.icon || '📁'}</span>
        <span class="group-name">${group.name}</span>
      </div>
      <div class="group-tabs"></div>
    `;
    
    const tabsContainer = groupElement.querySelector('.group-tabs');
    groupTabs.forEach(tab => {
      const tabElement = document.createElement('div');
      tabElement.className = `tab-item ${activeTabId === tab.id ? 'active' : ''}`;
      tabElement.dataset.tabId = tab.id;
      tabElement.innerHTML = `
        <span class="tab-icon" style="color: ${tab.color || '#666'}">${tab.icon || '🔗'}</span>
        <span class="tab-name">${tab.name}</span>
        ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ''}
      `;
      tabElement.addEventListener('click', () => openTab(tab));
      tabsContainer?.appendChild(tabElement);
    });
    
    sidebarGroups.appendChild(groupElement);
  });
}

// Abrir aba
async function openTab(tab: Tab) {
  activeTabId = tab.id;
  renderSidebar(); // Atualizar estado ativo
  
  try {
    await window.electronAPI.createWindow(tab);
  } catch (error) {
    console.error('Erro ao abrir aba:', error);
  }
}

// Registrar atalhos de teclado
async function registerShortcuts() {
  if (!currentConfig) return;
  
  // Limpar atalhos anteriores
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

// Event Listeners

// Login form
loginForm?.addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const email = emailInput?.value;
  const password = passwordInput?.value;
  
  if (!email || !password) {
    if (loginError) loginError.textContent = 'Preencha todos os campos';
    return;
  }
  
  try {
    const result = await window.electronAPI.login(email, password);
    if (result.error) {
      if (loginError) loginError.textContent = result.error.message || 'Erro ao fazer login';
    } else {
      await loadApp();
    }
  } catch (error: any) {
    if (loginError) loginError.textContent = error.message || 'Erro ao fazer login';
  }
});

// Logout
logoutBtn?.addEventListener('click', async () => {
  try {
    await window.electronAPI.logout();
    currentConfig = null;
    activeTabId = null;
    showLogin();
  } catch (error) {
    console.error('Erro ao fazer logout:', error);
  }
});

// Listener para atalhos de teclado
window.electronAPI.onShortcutTriggered((tabId: string) => {
  if (!currentConfig) return;
  
  const tab = currentConfig.tabs?.find(t => t.id === tabId);
  if (tab) {
    openTab(tab);
  }
});

// Listener para mudanças de autenticação
window.electronAPI.onAuthStateChanged((data: any) => {
  if (data.event === 'SIGNED_OUT') {
    currentConfig = null;
    activeTabId = null;
    showLogin();
  } else if (data.event === 'SIGNED_IN' && data.session) {
    loadApp();
  }
});

// Iniciar
document.addEventListener('DOMContentLoaded', init);

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
const loginContainer = document.getElementById('loginScreen');
const appContainer = document.getElementById('mainApp');
const loginForm = document.getElementById('loginForm');
const emailInput = document.getElementById('emailInput') as HTMLInputElement;
const passwordInput = document.getElementById('passwordInput') as HTMLInputElement;
const loginError = document.getElementById('errorMessage');
const tabsBar = document.getElementById('tabsBar');
const contentArea = document.getElementById('contentArea');
const logoutBtn = document.getElementById('logoutButton');

// Verificar se electronAPI está disponível
function waitForElectronAPI(): Promise<void> {
  return new Promise((resolve) => {
    if (window.electronAPI) {
      resolve();
      return;
    }
    const checkInterval = setInterval(() => {
      if (window.electronAPI) {
        clearInterval(checkInterval);
        resolve();
      }
    }, 10);
    // Timeout após 5 segundos
    setTimeout(() => {
      clearInterval(checkInterval);
      if (!window.electronAPI) {
        console.error('electronAPI não está disponível após 5 segundos');
      }
      resolve();
    }, 5000);
  });
}

// Inicialização
async function init() {
  // Aguardar electronAPI estar disponível
  await waitForElectronAPI();
  
  if (!window.electronAPI) {
    console.error('electronAPI não está disponível');
    if (loginError) {
      loginError.textContent = 'Erro: API do Electron não está disponível';
      loginError.classList.add('show');
    }
    return;
  }
  
  try {
    const result = await window.electronAPI.getSession();
    if (result?.session?.user) {
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
  if (loginContainer) loginContainer.classList.add('active');
  if (appContainer) appContainer.style.display = 'none';
}

// Mostrar aplicação
function showApp() {
  if (loginContainer) loginContainer.classList.remove('active');
  if (appContainer) appContainer.style.display = 'flex';
}

// Carregar aplicação após login
async function loadApp() {
  showApp();
  
  // Mostrar loading
  if (contentArea) {
    contentArea.innerHTML = '<div class="loading">Carregando configurações...</div>';
  }
  
  try {
    console.log('[Renderer] Iniciando carregamento de configurações...');
    const result = await window.electronAPI.fetchConfig();
    console.log('[Renderer] Resultado do fetchConfig:', result);
    
    if (result?.success && result.config) {
      currentConfig = result.config;
      console.log('[Renderer] Configuração carregada:', {
        grupos: currentConfig.tab_groups?.length || 0,
        tabs: currentConfig.tabs?.length || 0
      });
      renderTabs();
      registerShortcuts();
      
      // Mostrar mensagem se não houver tabs
      if (!currentConfig.tab_groups?.length && !currentConfig.tabs?.length) {
        if (contentArea) {
          contentArea.innerHTML = `
            <div class="loading" style="color: #ffd93d;">
              <p>Nenhuma aba configurada ainda.</p>
              <p style="font-size: 12px; opacity: 0.7; margin-top: 8px;">
                Acesse a versão web para criar grupos e abas.
              </p>
            </div>`;
        }
      }
    } else {
      const errorMsg = result?.error || 'Erro desconhecido ao carregar configurações';
      console.error('[Renderer] Erro ao carregar configurações:', errorMsg);
      showError(errorMsg);
    }
  } catch (error: any) {
    console.error('[Renderer] Exceção ao carregar configurações:', error);
    const errorMsg = error?.message || 'Erro desconhecido';
    showError(errorMsg);
  }
}

// Mostrar erro de forma detalhada
function showError(message: string) {
  if (!contentArea) return;
  
  let suggestion = '';
  
  // Sugestões baseadas no tipo de erro
  if (message.includes('401') || message.includes('autenticado') || message.includes('token')) {
    suggestion = 'Tente fazer logout e login novamente.';
  } else if (message.includes('conexão') || message.includes('fetch') || message.includes('network')) {
    suggestion = 'Verifique sua conexão com a internet.';
  } else if (message.includes('500') || message.includes('server')) {
    suggestion = 'Erro no servidor. Tente novamente em alguns minutos.';
  } else if (message.includes('404')) {
    suggestion = 'Serviço não encontrado. Entre em contato com o suporte.';
  }
  
  contentArea.innerHTML = `
    <div class="error-container" style="
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      text-align: center;
      padding: 20px;
    ">
      <div style="
        background: rgba(255, 107, 107, 0.1);
        border: 1px solid rgba(255, 107, 107, 0.3);
        border-radius: 8px;
        padding: 20px;
        max-width: 400px;
      ">
        <div style="color: #ff6b6b; font-size: 32px; margin-bottom: 12px;">⚠️</div>
        <h3 style="color: #ff6b6b; margin: 0 0 12px 0; font-size: 16px;">Erro ao carregar configurações</h3>
        <p style="color: #e0e0e0; font-size: 13px; margin: 0 0 12px 0; word-break: break-word;">${message}</p>
        ${suggestion ? `<p style="color: #ffd93d; font-size: 12px; margin: 0 0 16px 0;">${suggestion}</p>` : ''}
        <button onclick="window.location.reload()" style="
          background: #6366f1;
          color: white;
          border: none;
          padding: 8px 16px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 13px;
        ">Tentar novamente</button>
      </div>
    </div>`;
}

// Renderizar tabs na barra de tabs
function renderTabs() {
  if (!tabsBar || !currentConfig) return;
  
  tabsBar.innerHTML = '';
  
  const groups = currentConfig.tab_groups || [];
  const tabs = currentConfig.tabs || [];
  
  // Ordenar grupos por posição
  groups.sort((a, b) => a.position - b.position).forEach(group => {
    const groupTabs = tabs.filter(tab => tab.group_id === group.id);
    
    groupTabs.forEach(tab => {
      const tabButton = document.createElement('button');
      tabButton.className = `tab-button ${activeTabId === tab.id ? 'active' : ''}`;
      tabButton.dataset.tabId = tab.id;
      tabButton.innerHTML = `
        <span class="tab-icon">${tab.icon || '🔗'}</span>
        <span>${tab.name}</span>
        ${tab.keyboard_shortcut ? `<span style="opacity: 0.5; font-size: 10px; margin-left: 4px;">${tab.keyboard_shortcut}</span>` : ''}
      `;
      tabButton.addEventListener('click', () => openTab(tab));
      tabsBar.appendChild(tabButton);
    });
  });
  
  // Limpar área de conteúdo
  if (contentArea) {
    contentArea.innerHTML = '<div class="loading">Clique em uma aba para abrir</div>';
  }
}

// Abrir aba
async function openTab(tab: Tab) {
  activeTabId = tab.id;
  renderTabs(); // Atualizar estado ativo
  
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
    if (loginError) {
      loginError.textContent = 'Preencha todos os campos';
      loginError.classList.add('show');
    }
    return;
  }
  
  if (!window.electronAPI) {
    if (loginError) {
      loginError.textContent = 'Erro: API do Electron não está disponível';
      loginError.classList.add('show');
    }
    return;
  }
  
  try {
    const result = await window.electronAPI.login(email, password);
    if (result.error) {
      if (loginError) {
        loginError.textContent = result.error.message || 'Erro ao fazer login';
        loginError.classList.add('show');
      }
    } else {
      if (loginError) loginError.classList.remove('show');
      await loadApp();
    }
  } catch (error: any) {
    if (loginError) {
      loginError.textContent = error.message || 'Erro ao fazer login';
      loginError.classList.add('show');
    }
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
window.electronAPI?.onShortcutTriggered?.((tabId: string) => {
  if (!currentConfig) return;
  
  const tab = currentConfig.tabs?.find(t => t.id === tabId);
  if (tab) {
    openTab(tab);
  }
});

// Listener para mudanças de autenticação
window.electronAPI?.onAuthStateChanged?.((data: any) => {
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

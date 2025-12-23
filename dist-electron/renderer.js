// @ts-nocheck
// Renderer script - Interface lógica para o Electron
// Este arquivo é compilado separadamente pelo tsconfig.electron.json
// Estado da aplicação
let currentConfig = null;
let activeTabId = null;
// Elementos DOM
const loginContainer = document.getElementById('loginScreen');
const appContainer = document.getElementById('mainApp');
const loginForm = document.getElementById('loginForm');
const emailInput = document.getElementById('emailInput');
const passwordInput = document.getElementById('passwordInput');
const loginError = document.getElementById('errorMessage');
const tabsBar = document.getElementById('tabsBar');
const contentArea = document.getElementById('contentArea');
const logoutBtn = document.getElementById('logoutButton');
// Verificar se electronAPI está disponível
function waitForElectronAPI() {
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
        }
        else {
            showLogin();
        }
    }
    catch (error) {
        console.error('Erro ao inicializar:', error);
        showLogin();
    }
}
// Mostrar tela de login
function showLogin() {
    if (loginContainer)
        loginContainer.classList.add('active');
    if (appContainer)
        appContainer.style.display = 'none';
}
// Mostrar aplicação
function showApp() {
    if (loginContainer)
        loginContainer.classList.remove('active');
    if (appContainer)
        appContainer.style.display = 'flex';
}
// Carregar aplicação após login
async function loadApp() {
    showApp();
    try {
        const result = await window.electronAPI.fetchConfig();
        console.log('Resultado do fetchConfig:', result);
        if (result?.success && result.config) {
            currentConfig = result.config;
            console.log('Configuração carregada:', currentConfig);
            renderTabs();
            registerShortcuts();
        }
        else {
            const errorMsg = result?.error || 'Erro desconhecido ao carregar configurações';
            console.error('Erro ao carregar configurações:', errorMsg);
            if (contentArea) {
                contentArea.innerHTML = `<div class="loading" style="color: #ff6b6b;">Erro ao carregar configurações: ${errorMsg}</div>`;
            }
        }
    }
    catch (error) {
        console.error('Erro ao carregar configurações:', error);
        const errorMsg = error?.message || 'Erro desconhecido';
        if (contentArea) {
            contentArea.innerHTML = `<div class="loading" style="color: #ff6b6b;">Erro ao carregar configurações: ${errorMsg}</div>`;
        }
    }
}
// Renderizar tabs na barra de tabs
function renderTabs() {
    if (!tabsBar || !currentConfig)
        return;
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
async function openTab(tab) {
    activeTabId = tab.id;
    renderTabs(); // Atualizar estado ativo
    try {
        await window.electronAPI.createWindow(tab);
    }
    catch (error) {
        console.error('Erro ao abrir aba:', error);
    }
}
// Registrar atalhos de teclado
async function registerShortcuts() {
    if (!currentConfig)
        return;
    // Limpar atalhos anteriores
    await window.electronAPI.unregisterAllShortcuts();
    const tabs = currentConfig.tabs || [];
    for (const tab of tabs) {
        if (tab.keyboard_shortcut) {
            try {
                await window.electronAPI.registerShortcut(tab.keyboard_shortcut, tab.id);
            }
            catch (error) {
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
        }
        else {
            if (loginError)
                loginError.classList.remove('show');
            await loadApp();
        }
    }
    catch (error) {
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
    }
    catch (error) {
        console.error('Erro ao fazer logout:', error);
    }
});
// Listener para atalhos de teclado
window.electronAPI?.onShortcutTriggered?.((tabId) => {
    if (!currentConfig)
        return;
    const tab = currentConfig.tabs?.find(t => t.id === tabId);
    if (tab) {
        openTab(tab);
    }
});
// Listener para mudanças de autenticação
window.electronAPI?.onAuthStateChanged?.((data) => {
    if (data.event === 'SIGNED_OUT') {
        currentConfig = null;
        activeTabId = null;
        showLogin();
    }
    else if (data.event === 'SIGNED_IN' && data.session) {
        loadApp();
    }
});
// Iniciar
document.addEventListener('DOMContentLoaded', init);

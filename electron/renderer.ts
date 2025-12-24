// @ts-nocheck
// Renderer script - Interface lógica para o Electron Local

interface Tab {
  id: string;
  name: string;
  url: string;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  zoom?: number;
  group_id: string;
  position: number;
  open_as_window?: boolean;
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
}

interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
}

interface LocalConfig {
  tab_groups: TabGroup[];
  tabs: Tab[];
  text_shortcuts: TextShortcut[];
}

// Estado da aplicação
let currentConfig: LocalConfig = { tab_groups: [], tabs: [], text_shortcuts: [] };
let currentScreen = 'home';
let deleteCallback: (() => void) | null = null;

// ============ UTILITIES ============

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
    setTimeout(() => {
      clearInterval(checkInterval);
      resolve();
    }, 5000);
  });
}

function showToast(message: string, type: 'success' | 'error' = 'success') {
  const container = document.getElementById('toastContainer');
  if (!container) return;
  
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <span>${type === 'success' ? '✅' : '❌'}</span>
    <span>${message}</span>
  `;
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.remove();
  }, 3000);
}

function openModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.add('active');
}

function closeModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.remove('active');
}

// Make closeModal globally accessible
(window as any).closeModal = closeModal;

function navigateTo(screen: string) {
  currentScreen = screen;
  
  // Update nav items
  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.toggle('active', item.getAttribute('data-screen') === screen);
  });
  
  // Update screens
  document.querySelectorAll('.screen').forEach(s => {
    s.classList.toggle('active', s.id === `${screen}Screen`);
  });
  
  // Refresh content
  if (screen === 'home') renderHome();
  else if (screen === 'groups') renderGroups();
  else if (screen === 'shortcuts') renderShortcuts();
}

// Make navigateTo globally accessible
(window as any).navigateTo = navigateTo;

// ============ INITIALIZATION ============

async function init() {
  await waitForElectronAPI();
  
  if (!window.electronAPI) {
    showToast('Erro: API do Electron não disponível', 'error');
    return;
  }
  
  // Load config
  await loadConfig();
  
  // Setup navigation
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const screen = item.getAttribute('data-screen');
      if (screen) navigateTo(screen);
    });
  });
  
  // Setup buttons
  setupEventListeners();
  
  // Register keyboard shortcuts
  await registerKeyboardShortcuts();
  
  // Render initial screen
  renderHome();
}

async function loadConfig() {
  try {
    currentConfig = await window.electronAPI.getConfig();
  } catch (error) {
    console.error('Erro ao carregar config:', error);
    currentConfig = { tab_groups: [], tabs: [], text_shortcuts: [] };
  }
}

// ============ KEYBOARD SHORTCUTS ============

async function registerKeyboardShortcuts() {
  await window.electronAPI.unregisterAllShortcuts();
  
  for (const tab of currentConfig.tabs) {
    if (tab.keyboard_shortcut) {
      try {
        await window.electronAPI.registerShortcut(tab.keyboard_shortcut, tab.id);
      } catch (error) {
        console.error(`Erro ao registrar atalho ${tab.keyboard_shortcut}:`, error);
      }
    }
  }
}

// ============ HOME SCREEN ============

const LINK_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`;

const GLOBE_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>`;

const WINDOW_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/></svg>`;

function getUrlDomain(url: string): string {
  try {
    const domain = new URL(url).hostname;
    return domain.length > 20 ? domain.substring(0, 20) + '...' : domain;
  } catch {
    return url.length > 20 ? url.substring(0, 20) + '...' : url;
  }
}

function renderHome() {
  const grid = document.getElementById('homeTabsGrid');
  const emptyState = document.getElementById('homeEmptyState');
  if (!grid || !emptyState) return;
  
  const groups = currentConfig.tab_groups.sort((a, b) => a.position - b.position);
  const tabs = currentConfig.tabs;
  
  if (tabs.length === 0) {
    grid.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  grid.style.display = 'grid';
  emptyState.style.display = 'none';
  
  grid.innerHTML = '';
  
  const renderTabCard = (tab: Tab) => {
    const card = document.createElement('div');
    card.className = 'tab-card';
    
    const hasMultipleUrls = tab.urls && Array.isArray(tab.urls) && tab.urls.length > 0;
    const urlCount = hasMultipleUrls ? (tab.urls as any[]).length + 1 : 1;
    
    let badgesHtml = '';
    if (urlCount > 1) {
      badgesHtml += `<span class="tab-card-badge urls">${urlCount} URLs</span>`;
    }
    if (tab.open_as_window) {
      badgesHtml += `<span class="tab-card-badge window">${WINDOW_ICON_SVG} Janela</span>`;
    }
    
    card.innerHTML = `
      <div class="tab-card-icon">
        ${tab.icon || LINK_ICON_SVG}
      </div>
      <div class="tab-card-name">${tab.name}</div>
      <div class="tab-card-url">${getUrlDomain(tab.url)}</div>
      ${tab.keyboard_shortcut ? `<div class="tab-card-shortcut">${tab.keyboard_shortcut}</div>` : ''}
      ${badgesHtml ? `<div class="tab-card-badges">${badgesHtml}</div>` : ''}
    `;
    card.addEventListener('click', () => openTab(tab));
    grid.appendChild(card);
  };
  
  groups.forEach(group => {
    const groupTabs = tabs
      .filter(t => t.group_id === group.id)
      .sort((a, b) => a.position - b.position);
    
    groupTabs.forEach(renderTabCard);
  });
  
  // Tabs without group
  const orphanTabs = tabs.filter(t => !groups.find(g => g.id === t.group_id));
  orphanTabs.forEach(renderTabCard);
}

async function openTab(tab: Tab) {
  try {
    await window.electronAPI.createWindow(tab);
  } catch (error) {
    console.error('Erro ao abrir aba:', error);
    showToast('Erro ao abrir aba', 'error');
  }
}

// ============ GROUPS SCREEN ============

function renderGroups() {
  const list = document.getElementById('groupsList');
  const emptyState = document.getElementById('groupsEmptyState');
  if (!list || !emptyState) return;
  
  const groups = currentConfig.tab_groups.sort((a, b) => a.position - b.position);
  
  if (groups.length === 0) {
    list.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  list.style.display = 'block';
  emptyState.style.display = 'none';
  
  list.innerHTML = '';
  
  groups.forEach(group => {
    const groupTabs = currentConfig.tabs
      .filter(t => t.group_id === group.id)
      .sort((a, b) => a.position - b.position);
    
    const section = document.createElement('div');
    section.className = 'group-section';
    section.innerHTML = `
      <div class="group-header">
        <div class="group-title">
          <span>${group.icon || '📁'}</span>
          <span>${group.name}</span>
          <span class="badge badge-gray">${groupTabs.length} abas</span>
        </div>
        <div class="card-actions">
          <button class="btn btn-sm btn-primary add-tab-btn" data-group-id="${group.id}">+ Aba</button>
          <button class="btn btn-sm btn-secondary edit-group-btn" data-id="${group.id}">✏️</button>
          <button class="btn btn-sm btn-danger delete-group-btn" data-id="${group.id}">🗑️</button>
        </div>
      </div>
      <div class="group-tabs-list">
        ${groupTabs.length === 0 ? '<div style="padding: 16px; text-align: center; color: #808080; font-size: 12px;">Nenhuma aba neste grupo</div>' : ''}
        ${groupTabs.map(tab => `
          <div class="tab-item">
            <span class="tab-item-icon">${tab.icon || '🔗'}</span>
            <div class="tab-item-info">
              <div class="tab-item-name">${tab.name}</div>
              <div class="tab-item-url">${tab.url}</div>
            </div>
            ${tab.keyboard_shortcut ? `<span class="tab-item-shortcut">${tab.keyboard_shortcut}</span>` : ''}
            <div class="card-actions">
              <button class="btn btn-sm btn-secondary edit-tab-btn" data-id="${tab.id}">✏️</button>
              <button class="btn btn-sm btn-danger delete-tab-btn" data-id="${tab.id}">🗑️</button>
            </div>
          </div>
        `).join('')}
      </div>
    `;
    list.appendChild(section);
  });
  
  // Add event listeners
  list.querySelectorAll('.add-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const groupId = btn.getAttribute('data-group-id');
      openTabModal(null, groupId);
    });
  });
  
  list.querySelectorAll('.edit-group-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const group = currentConfig.tab_groups.find(g => g.id === id);
      if (group) openGroupModal(group);
    });
  });
  
  list.querySelectorAll('.delete-group-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      confirmDelete('Tem certeza que deseja excluir este grupo e todas as suas abas?', async () => {
        await window.electronAPI.deleteTabGroup(id);
        await loadConfig();
        renderGroups();
        showToast('Grupo excluído');
      });
    });
  });
  
  list.querySelectorAll('.edit-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const tab = currentConfig.tabs.find(t => t.id === id);
      if (tab) openTabModal(tab, tab.group_id);
    });
  });
  
  list.querySelectorAll('.delete-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      confirmDelete('Tem certeza que deseja excluir esta aba?', async () => {
        await window.electronAPI.deleteTab(id);
        await loadConfig();
        renderGroups();
        await registerKeyboardShortcuts();
        showToast('Aba excluída');
      });
    });
  });
}

function openGroupModal(group: TabGroup | null = null) {
  const titleEl = document.getElementById('groupModalTitle');
  const idInput = document.getElementById('groupId') as HTMLInputElement;
  const nameInput = document.getElementById('groupName') as HTMLInputElement;
  const iconInput = document.getElementById('groupIcon') as HTMLInputElement;
  const colorInput = document.getElementById('groupColor') as HTMLInputElement;
  
  if (titleEl) titleEl.textContent = group ? 'Editar Grupo' : 'Novo Grupo';
  if (idInput) idInput.value = group?.id || '';
  if (nameInput) nameInput.value = group?.name || '';
  if (iconInput) iconInput.value = group?.icon || '';
  if (colorInput) colorInput.value = group?.color || '#4a9eff';
  
  openModal('groupModal');
}

function openTabModal(tab: Tab | null, groupId: string | null) {
  const titleEl = document.getElementById('tabModalTitle');
  const idInput = document.getElementById('tabId') as HTMLInputElement;
  const groupIdInput = document.getElementById('tabGroupId') as HTMLInputElement;
  const nameInput = document.getElementById('tabName') as HTMLInputElement;
  const urlInput = document.getElementById('tabUrl') as HTMLInputElement;
  const iconInput = document.getElementById('tabIcon') as HTMLInputElement;
  const shortcutInput = document.getElementById('tabShortcut') as HTMLInputElement;
  const zoomInput = document.getElementById('tabZoom') as HTMLInputElement;
  const positionInput = document.getElementById('tabPosition') as HTMLInputElement;
  
  if (titleEl) titleEl.textContent = tab ? 'Editar Aba' : 'Nova Aba';
  if (idInput) idInput.value = tab?.id || '';
  if (groupIdInput) groupIdInput.value = groupId || tab?.group_id || '';
  if (nameInput) nameInput.value = tab?.name || '';
  if (urlInput) urlInput.value = tab?.url || '';
  if (iconInput) iconInput.value = tab?.icon || '';
  if (shortcutInput) shortcutInput.value = tab?.keyboard_shortcut || '';
  if (zoomInput) zoomInput.value = String(tab?.zoom || 100);
  if (positionInput) positionInput.value = String(tab?.position || 0);
  
  openModal('tabModal');
}

// ============ SHORTCUTS SCREEN ============

function renderShortcuts(filter: string = '') {
  const tbody = document.getElementById('shortcutsTableBody');
  const list = document.getElementById('shortcutsList');
  const emptyState = document.getElementById('shortcutsEmptyState');
  if (!tbody || !list || !emptyState) return;
  
  let shortcuts = currentConfig.text_shortcuts;
  
  if (filter) {
    const lowerFilter = filter.toLowerCase();
    shortcuts = shortcuts.filter(s => 
      s.command.toLowerCase().includes(lowerFilter) ||
      s.expanded_text.toLowerCase().includes(lowerFilter) ||
      s.category?.toLowerCase().includes(lowerFilter)
    );
  }
  
  if (currentConfig.text_shortcuts.length === 0) {
    list.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  list.style.display = 'block';
  emptyState.style.display = 'none';
  
  tbody.innerHTML = shortcuts.map(s => `
    <tr>
      <td><span class="shortcut-command">${s.command}</span></td>
      <td><span class="shortcut-text">${s.expanded_text}</span></td>
      <td>${s.category ? `<span class="badge badge-blue">${s.category}</span>` : '-'}</td>
      <td>
        <div class="card-actions">
          <button class="btn btn-sm btn-secondary edit-shortcut-btn" data-id="${s.id}">✏️</button>
          <button class="btn btn-sm btn-danger delete-shortcut-btn" data-id="${s.id}">🗑️</button>
        </div>
      </td>
    </tr>
  `).join('');
  
  // Add event listeners
  tbody.querySelectorAll('.edit-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const shortcut = currentConfig.text_shortcuts.find(s => s.id === id);
      if (shortcut) openShortcutModal(shortcut);
    });
  });
  
  tbody.querySelectorAll('.delete-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      confirmDelete('Tem certeza que deseja excluir este atalho?', async () => {
        await window.electronAPI.deleteTextShortcut(id);
        await loadConfig();
        renderShortcuts();
        showToast('Atalho excluído');
      });
    });
  });
}

function openShortcutModal(shortcut: TextShortcut | null = null) {
  const titleEl = document.getElementById('shortcutModalTitle');
  const idInput = document.getElementById('shortcutId') as HTMLInputElement;
  const commandInput = document.getElementById('shortcutCommand') as HTMLInputElement;
  const textInput = document.getElementById('shortcutText') as HTMLTextAreaElement;
  const categoryInput = document.getElementById('shortcutCategory') as HTMLInputElement;
  const descriptionInput = document.getElementById('shortcutDescription') as HTMLInputElement;
  
  if (titleEl) titleEl.textContent = shortcut ? 'Editar Atalho' : 'Novo Atalho';
  if (idInput) idInput.value = shortcut?.id || '';
  if (commandInput) commandInput.value = shortcut?.command || '';
  if (textInput) textInput.value = shortcut?.expanded_text || '';
  if (categoryInput) categoryInput.value = shortcut?.category || '';
  if (descriptionInput) descriptionInput.value = shortcut?.description || '';
  
  openModal('shortcutModal');
}

// ============ CONFIRM DELETE ============

function confirmDelete(message: string, callback: () => void) {
  const msgEl = document.getElementById('confirmMessage');
  if (msgEl) msgEl.textContent = message;
  deleteCallback = callback;
  openModal('confirmModal');
}

// ============ EVENT LISTENERS ============

function setupEventListeners() {
  // Add Group buttons
  document.getElementById('addGroupBtn')?.addEventListener('click', () => openGroupModal());
  document.getElementById('addGroupBtnEmpty')?.addEventListener('click', () => openGroupModal());
  
  // Add Shortcut buttons
  document.getElementById('addShortcutBtn')?.addEventListener('click', () => openShortcutModal());
  document.getElementById('addShortcutBtnEmpty')?.addEventListener('click', () => openShortcutModal());
  
  // Save Group
  document.getElementById('saveGroupBtn')?.addEventListener('click', async () => {
    const id = (document.getElementById('groupId') as HTMLInputElement).value;
    const name = (document.getElementById('groupName') as HTMLInputElement).value;
    const icon = (document.getElementById('groupIcon') as HTMLInputElement).value;
    const color = (document.getElementById('groupColor') as HTMLInputElement).value;
    
    if (!name) {
      showToast('Nome é obrigatório', 'error');
      return;
    }
    
    if (id) {
      await window.electronAPI.updateTabGroup(id, { name, icon, color });
      showToast('Grupo atualizado');
    } else {
      const position = currentConfig.tab_groups.length;
      await window.electronAPI.addTabGroup({ name, icon, color, position });
      showToast('Grupo criado');
    }
    
    closeModal('groupModal');
    await loadConfig();
    renderGroups();
  });
  
  // Save Tab
  document.getElementById('saveTabBtn')?.addEventListener('click', async () => {
    const id = (document.getElementById('tabId') as HTMLInputElement).value;
    const groupId = (document.getElementById('tabGroupId') as HTMLInputElement).value;
    const name = (document.getElementById('tabName') as HTMLInputElement).value;
    const url = (document.getElementById('tabUrl') as HTMLInputElement).value;
    const icon = (document.getElementById('tabIcon') as HTMLInputElement).value;
    const keyboard_shortcut = (document.getElementById('tabShortcut') as HTMLInputElement).value;
    const zoom = parseInt((document.getElementById('tabZoom') as HTMLInputElement).value) || 100;
    const position = parseInt((document.getElementById('tabPosition') as HTMLInputElement).value) || 0;
    
    if (!name || !url) {
      showToast('Nome e URL são obrigatórios', 'error');
      return;
    }
    
    if (id) {
      await window.electronAPI.updateTab(id, { name, url, icon, keyboard_shortcut, zoom, position });
      showToast('Aba atualizada');
    } else {
      await window.electronAPI.addTab({ 
        name, url, icon, keyboard_shortcut, zoom, position, 
        group_id: groupId, 
        open_as_window: true 
      });
      showToast('Aba criada');
    }
    
    closeModal('tabModal');
    await loadConfig();
    renderGroups();
    renderHome();
    await registerKeyboardShortcuts();
  });
  
  // Save Shortcut
  document.getElementById('saveShortcutBtn')?.addEventListener('click', async () => {
    const id = (document.getElementById('shortcutId') as HTMLInputElement).value;
    const command = (document.getElementById('shortcutCommand') as HTMLInputElement).value;
    const expanded_text = (document.getElementById('shortcutText') as HTMLTextAreaElement).value;
    const category = (document.getElementById('shortcutCategory') as HTMLInputElement).value;
    const description = (document.getElementById('shortcutDescription') as HTMLInputElement).value;
    
    if (!command || !expanded_text) {
      showToast('Comando e texto são obrigatórios', 'error');
      return;
    }
    
    if (id) {
      await window.electronAPI.updateTextShortcut(id, { command, expanded_text, category, description });
      showToast('Atalho atualizado');
    } else {
      await window.electronAPI.addTextShortcut({ command, expanded_text, category, description });
      showToast('Atalho criado');
    }
    
    closeModal('shortcutModal');
    await loadConfig();
    renderShortcuts();
  });
  
  // Confirm Delete
  document.getElementById('confirmDeleteBtn')?.addEventListener('click', () => {
    if (deleteCallback) {
      deleteCallback();
      deleteCallback = null;
    }
    closeModal('confirmModal');
  });
  
  // Search shortcuts
  document.getElementById('shortcutSearch')?.addEventListener('input', (e) => {
    const filter = (e.target as HTMLInputElement).value;
    renderShortcuts(filter);
  });
  
  // Import shortcuts
  document.getElementById('importShortcutsBtn')?.addEventListener('click', () => {
    document.getElementById('importFileInput')?.click();
  });
  
  document.getElementById('importFileInput')?.addEventListener('change', async (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      
      if (Array.isArray(data)) {
        await window.electronAPI.importTextShortcuts(data);
        await loadConfig();
        renderShortcuts();
        showToast(`${data.length} atalhos importados`);
      } else {
        showToast('Formato inválido', 'error');
      }
    } catch (error) {
      showToast('Erro ao importar arquivo', 'error');
    }
    
    (e.target as HTMLInputElement).value = '';
  });
  
  // Export shortcuts
  document.getElementById('exportShortcutsBtn')?.addEventListener('click', async () => {
    const shortcuts = await window.electronAPI.exportTextShortcuts();
    const blob = new Blob([JSON.stringify(shortcuts, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'text-shortcuts.json';
    a.click();
    URL.revokeObjectURL(url);
    showToast('Atalhos exportados');
  });
  
  // Listen for keyboard shortcuts from main process
  window.electronAPI.onShortcutTriggered((tabId: string) => {
    const tab = currentConfig.tabs.find(t => t.id === tabId);
    if (tab) openTab(tab);
  });
}

// ============ START ============

document.addEventListener('DOMContentLoaded', init);

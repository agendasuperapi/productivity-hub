// @ts-nocheck
// Renderer script - GerenciaZap Electron (Flutter-like)

const SUPABASE_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplZ2pydmdscmpuaHVreHFreG9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MTA4NTAsImV4cCI6MjA4MjA4Njg1MH0.mhrSxMboDPKan4ez71_f5qjwUhxGMCq61GXvuTo93MU';

interface User { id: string; email?: string; user_metadata?: { full_name?: string; name?: string; }; }
interface Session { access_token: string; refresh_token: string; expires_at?: number; user: User; }
interface TabGroup { id: string; name: string; icon?: string; color?: string; position: number; user_id: string; }
interface Tab { id: string; name: string; url: string; urls?: string[]; layout_type?: string; icon?: string; color?: string; keyboard_shortcut?: string; zoom?: number; group_id: string; position: number; user_id: string; }
interface TextShortcut { id: string; command: string; expanded_text: string; description?: string; category?: string; user_id: string; }
interface Keyword { id: string; key: string; value: string; user_id: string; }

let currentSession: Session | null = null;
let currentUser: User | null = null;
let tabGroups: TabGroup[] = [];
let tabs: Tab[] = [];
let textShortcuts: TextShortcut[] = [];
let keywords: Keyword[] = [];
let currentScreen = 'home';
let currentTab: Tab | null = null;
let currentZoom = 100;
let currentLayout = 'single'; // 'single' | '2x1' | '1x2'
let confirmCallback: (() => void) | null = null;
let editingGroupId: string | null = null;
let editingTabId: string | null = null;
let editingShortcutId: string | null = null;
let editingKeywordId: string | null = null;
let selectedGroupId: string | null = null;
let webviewInstances: HTMLElement[] = [];

const COLORS = ['#00a4a4', '#6366f1', '#8b5cf6', '#ec4899', '#ef4444', '#f97316', '#eab308', '#22c55e', '#14b8a6', '#3b82f6'];
const ICONS = ['📁', '🌐', '💼', '📊', '📝', '🎯', '⭐', '🔥', '💡', '🎨', '📱', '💻', '🏠', '🔧', '📧'];

class SupabaseClient {
  private url: string; private key: string; private accessToken: string | null = null;
  constructor(url: string, key: string) { this.url = url; this.key = key; }
  setAccessToken(token: string | null) { this.accessToken = token; }
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = { 'apikey': this.key, 'Content-Type': 'application/json' };
    if (this.accessToken) headers['Authorization'] = `Bearer ${this.accessToken}`;
    return headers;
  }
  async signInWithPassword(email: string, password: string) {
    const response = await fetch(`${this.url}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { 'apikey': this.key, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    const data = await response.json();
    if (!response.ok) return { data: { session: null, user: null }, error: data };
    return { data: { session: { access_token: data.access_token, refresh_token: data.refresh_token, expires_at: data.expires_at, user: data.user }, user: data.user }, error: null };
  }
  async signUp(email: string, password: string, name?: string) {
    const response = await fetch(`${this.url}/auth/v1/signup`, { method: 'POST', headers: { 'apikey': this.key, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, data: { full_name: name } }) });
    const data = await response.json();
    if (!response.ok) return { data: { session: null, user: null }, error: data };
    return { data: { session: data.session, user: data.user }, error: null };
  }
  async select(table: string, query?: string) {
    const url = `${this.url}/rest/v1/${table}${query ? `?${query}` : ''}`;
    const response = await fetch(url, { headers: this.getHeaders() });
    return response.json();
  }
  async insert(table: string, data: any) {
    const response = await fetch(`${this.url}/rest/v1/${table}`, { method: 'POST', headers: { ...this.getHeaders(), 'Prefer': 'return=representation' }, body: JSON.stringify(data) });
    return response.json();
  }
  async update(table: string, id: string, data: any) {
    const response = await fetch(`${this.url}/rest/v1/${table}?id=eq.${id}`, { method: 'PATCH', headers: { ...this.getHeaders(), 'Prefer': 'return=representation' }, body: JSON.stringify(data) });
    return response.json();
  }
  async delete(table: string, id: string) {
    await fetch(`${this.url}/rest/v1/${table}?id=eq.${id}`, { method: 'DELETE', headers: this.getHeaders() });
  }
}

const supabase = new SupabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY);

function showToast(message: string, type: 'success' | 'error' | 'warning' = 'success') {
  const container = document.getElementById('toastContainer')!;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

function showScreen(screen: string) {
  currentScreen = screen;
  document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
  document.querySelector(`.nav-item[data-screen="${screen}"]`)?.classList.add('active');
  
  const welcomeScreen = document.getElementById('welcomeScreen')!;
  const webviewContainer = document.getElementById('webviewContainer')!;
  const groupsScreen = document.getElementById('groupsScreen')!;
  const shortcutsScreen = document.getElementById('shortcutsScreen')!;
  const keywordsScreen = document.getElementById('keywordsScreen')!;
  const profileScreen = document.getElementById('profileScreen')!;
  const navBar = document.getElementById('navBar')!;

  [welcomeScreen, groupsScreen, shortcutsScreen, keywordsScreen, profileScreen].forEach(el => el.classList.add('hidden'));
  webviewContainer.classList.remove('visible');
  navBar.classList.remove('visible');

  switch (screen) {
    case 'home': welcomeScreen.classList.remove('hidden'); break;
    case 'groups': groupsScreen.classList.remove('hidden'); renderGroupsGrid(); break;
    case 'shortcuts': shortcutsScreen.classList.remove('hidden'); renderShortcutsGrid(); break;
    case 'keywords': keywordsScreen.classList.remove('hidden'); renderKeywordsGrid(); break;
    case 'profile': profileScreen.classList.remove('hidden'); renderProfile(); break;
  }
}

function openTab(tab: Tab) {
  currentTab = tab;
  currentZoom = tab.zoom || 100;
  currentLayout = tab.layout_type || 'single';
  
  const navBar = document.getElementById('navBar')!;
  const welcomeScreen = document.getElementById('welcomeScreen')!;
  const webviewContainer = document.getElementById('webviewContainer')!;
  
  welcomeScreen.classList.add('hidden');
  [document.getElementById('groupsScreen')!, document.getElementById('shortcutsScreen')!, document.getElementById('keywordsScreen')!, document.getElementById('profileScreen')!].forEach(el => el.classList.add('hidden'));
  
  navBar.classList.add('visible');
  webviewContainer.classList.add('visible');
  
  document.getElementById('navTabName')!.textContent = tab.name;
  document.getElementById('navTabIcon')!.style.background = tab.color || '#00a4a4';
  document.getElementById('navTabIcon')!.textContent = tab.icon || '🌐';
  document.getElementById('navZoomValue')!.textContent = `${currentZoom}%`;
  document.getElementById('navUrlInput')!.value = tab.url;
  
  // Update layout selector
  updateLayoutSelector();
  
  // Render webviews based on layout
  renderWebviews(tab);
}

function updateLayoutSelector() {
  document.querySelectorAll('.layout-btn').forEach(btn => {
    btn.classList.remove('active');
    if (btn.getAttribute('data-layout') === currentLayout) {
      btn.classList.add('active');
    }
  });
}

function setLayout(layout: string) {
  currentLayout = layout;
  updateLayoutSelector();
  if (currentTab) {
    renderWebviews(currentTab);
  }
}

function renderWebviews(tab: Tab) {
  const container = document.getElementById('webviewContainer')!;
  webviewInstances = [];
  
  // Get URLs - use urls array if available, otherwise use single url
  const urls = tab.urls && tab.urls.length > 0 ? tab.urls : [tab.url];
  
  let containerClass = 'webview-container';
  if (currentLayout === '2x1') containerClass += ' split-horizontal';
  else if (currentLayout === '1x2') containerClass += ' split-vertical';
  
  container.className = containerClass;
  
  if (currentLayout === 'single') {
    container.innerHTML = '';
    const webview = createWebview(urls[0], 0);
    container.appendChild(webview);
    webviewInstances.push(webview);
  } else if (currentLayout === '2x1') {
    // Horizontal split (side by side)
    container.innerHTML = '';
    const url1 = urls[0] || tab.url;
    const url2 = urls[1] || urls[0] || tab.url;
    
    const webview1 = createWebview(url1, 0);
    const webview2 = createWebview(url2, 1);
    
    container.appendChild(webview1);
    container.appendChild(webview2);
    webviewInstances.push(webview1, webview2);
  } else if (currentLayout === '1x2') {
    // Vertical split (stacked)
    container.innerHTML = '';
    const url1 = urls[0] || tab.url;
    const url2 = urls[1] || urls[0] || tab.url;
    
    const webview1 = createWebview(url1, 0);
    const webview2 = createWebview(url2, 1);
    
    container.appendChild(webview1);
    container.appendChild(webview2);
    webviewInstances.push(webview1, webview2);
  }
}

function createWebview(url: string, index: number): HTMLElement {
  const wrapper = document.createElement('div');
  wrapper.className = 'webview-wrapper';
  wrapper.innerHTML = `<webview src="${url}" style="flex:1;width:100%;height:100%;" partition="persist:tab${currentTab?.id || 'default'}"></webview>`;
  
  const webview = wrapper.querySelector('webview') as any;
  
  if (webview) {
    webview.addEventListener('did-start-loading', () => {
      if (index === 0) document.getElementById('navRefresh')!.textContent = '⏳';
    });
    
    webview.addEventListener('did-stop-loading', () => {
      if (index === 0) document.getElementById('navRefresh')!.textContent = '🔄';
      // Apply zoom
      if (currentZoom !== 100) {
        webview.setZoomFactor(currentZoom / 100);
      }
      // Inject WhatsApp shortcuts script
      injectShortcutsScript(webview);
    });
    
    webview.addEventListener('did-navigate', (e: any) => {
      if (index === 0) document.getElementById('navUrlInput')!.value = e.url;
    });
    
    webview.addEventListener('dom-ready', () => {
      // Inject script on DOM ready as well
      injectShortcutsScript(webview);
    });
  }
  
  return wrapper;
}

function injectShortcutsScript(webview: any) {
  if (!webview || typeof webview.executeJavaScript !== 'function') return;
  
  // Build shortcuts map from textShortcuts and keywords
  const shortcutsMap: Record<string, string> = {};
  textShortcuts.forEach(s => {
    shortcutsMap[s.command] = s.expanded_text;
  });
  
  // Build keywords map for replacement within expanded text
  const keywordsMap: Record<string, string> = {};
  keywords.forEach(k => {
    keywordsMap[`<${k.key}>`] = k.value;
  });
  
  const injectionScript = `
    (function() {
      if (window.__gerenciazapInjected) return;
      window.__gerenciazapInjected = true;
      
      const shortcuts = ${JSON.stringify(shortcutsMap)};
      const keywords = ${JSON.stringify(keywordsMap)};
      
      function replaceKeywords(text) {
        let result = text;
        for (const [key, value] of Object.entries(keywords)) {
          result = result.split(key).join(value);
        }
        return result;
      }
      
      function processInput(element) {
        if (!element) return;
        
        let text = '';
        let isContentEditable = false;
        
        if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
          text = element.value;
        } else if (element.isContentEditable || element.getAttribute('contenteditable') === 'true') {
          text = element.textContent || element.innerText;
          isContentEditable = true;
        } else {
          return;
        }
        
        // Check for shortcuts (commands starting with /)
        for (const [command, expandedText] of Object.entries(shortcuts)) {
          if (text.includes(command)) {
            let replacement = replaceKeywords(expandedText);
            text = text.split(command).join(replacement);
            
            if (isContentEditable) {
              element.textContent = text;
              // Move cursor to end
              const range = document.createRange();
              const sel = window.getSelection();
              range.selectNodeContents(element);
              range.collapse(false);
              sel.removeAllRanges();
              sel.addRange(range);
            } else {
              element.value = text;
            }
            
            // Dispatch input event
            element.dispatchEvent(new Event('input', { bubbles: true }));
          }
        }
      }
      
      // Listen for input events
      document.addEventListener('input', function(e) {
        processInput(e.target);
      }, true);
      
      // Also listen for keyup to catch quick typing
      document.addEventListener('keyup', function(e) {
        if (e.key === ' ' || e.key === 'Enter') {
          processInput(e.target);
        }
      }, true);
      
      console.log('[GerenciaZap] Atalhos injetados:', Object.keys(shortcuts).length, 'comandos,', Object.keys(keywords).length, 'palavras-chave');
    })();
  `;
  
  webview.executeJavaScript(injectionScript).catch(() => {
    // Silently fail if injection is blocked
  });
}

async function loadData() {
  if (!currentUser) return;
  tabGroups = await supabase.select('tab_groups', `user_id=eq.${currentUser.id}&order=position`);
  tabs = await supabase.select('tabs', `user_id=eq.${currentUser.id}&order=position`);
  textShortcuts = await supabase.select('text_shortcuts', `user_id=eq.${currentUser.id}&order=command`);
  keywords = await supabase.select('keywords', `user_id=eq.${currentUser.id}&order=key`);
  renderSidebarGroups();
}

function renderSidebarGroups() {
  const container = document.getElementById('tabGroupsList')!;
  container.innerHTML = tabGroups.map(group => {
    const groupTabs = tabs.filter(t => t.group_id === group.id);
    return `
      <div class="tab-group expanded" data-group-id="${group.id}">
        <div class="tab-group-header" onclick="toggleGroup('${group.id}')">
          <div class="tab-group-icon" style="background:${group.color || '#00a4a4'};color:#fff">${group.icon || '📁'}</div>
          <span class="tab-group-name">${group.name}</span>
          <span class="tab-group-arrow">▶</span>
        </div>
        <div class="tab-group-tabs">
          ${groupTabs.map(tab => `
            <div class="tab-item ${currentTab?.id === tab.id ? 'active' : ''}" onclick="openTab(${JSON.stringify(tab).replace(/"/g, '&quot;')})">
              <div class="tab-item-icon" style="background:${tab.color || '#00a4a4'};color:#fff">${tab.icon || '🌐'}</div>
              <span class="tab-item-name">${tab.name}</span>
              ${tab.keyboard_shortcut ? `<span class="tab-item-shortcut">${tab.keyboard_shortcut}</span>` : ''}
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }).join('');
}

function renderGroupsGrid() {
  const container = document.getElementById('groupsGrid')!;
  if (tabGroups.length === 0) {
    container.innerHTML = `<div class="empty-state"><div class="empty-state-icon">📁</div><h3 class="empty-state-title">Nenhum grupo criado</h3><p class="empty-state-text">Crie grupos para organizar suas abas</p></div>`;
    return;
  }
  container.innerHTML = tabGroups.map(group => {
    const groupTabs = tabs.filter(t => t.group_id === group.id);
    return `
      <div class="card">
        <div class="card-header">
          <div class="card-icon" style="background:${group.color || '#00a4a4'};color:#fff">${group.icon || '📁'}</div>
          <span class="card-title">${group.name}</span>
          <div class="card-actions">
            <button class="card-action-btn" onclick="openAddTabModal('${group.id}')" title="Adicionar aba">+</button>
            <button class="card-action-btn" onclick="openEditGroupModal('${group.id}')" title="Editar">✏️</button>
            <button class="card-action-btn danger" onclick="deleteGroup('${group.id}')" title="Excluir">🗑️</button>
          </div>
        </div>
        <div class="card-tabs-list">
          ${groupTabs.length === 0 ? '<p style="color:var(--gray-400);font-size:13px;">Nenhuma aba</p>' : groupTabs.map(tab => `
            <div class="card-tab-item">
              <div class="card-tab-icon" style="background:${tab.color || '#00a4a4'};color:#fff">${tab.icon || '🌐'}</div>
              <span class="card-tab-name">${tab.name}</span>
              <div class="card-tab-actions">
                <button class="card-tab-btn" onclick="openEditTabModal('${tab.id}')">✏️</button>
                <button class="card-tab-btn danger" onclick="deleteTab('${tab.id}')">🗑️</button>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }).join('');
}

function renderShortcutsGrid() {
  const container = document.getElementById('shortcutsGrid')!;
  if (textShortcuts.length === 0) {
    container.innerHTML = `<div class="empty-state"><div class="empty-state-icon">⚡</div><h3 class="empty-state-title">Nenhum atalho criado</h3><p class="empty-state-text">Crie atalhos para digitar mensagens rapidamente</p></div>`;
    return;
  }
  container.innerHTML = textShortcuts.map(s => `
    <div class="card">
      <div class="card-header">
        <div class="card-icon" style="background:var(--teal-primary);color:#fff">⚡</div>
        <span class="card-title">${s.command}</span>
        <div class="card-actions">
          <button class="card-action-btn" onclick="openEditShortcutModal('${s.id}')">✏️</button>
          <button class="card-action-btn danger" onclick="deleteShortcut('${s.id}')">🗑️</button>
        </div>
      </div>
      <div class="card-content">${s.expanded_text.substring(0, 100)}${s.expanded_text.length > 100 ? '...' : ''}</div>
      <div class="card-meta"><span>${s.category || 'geral'}</span></div>
    </div>
  `).join('');
}

function renderKeywordsGrid() {
  const container = document.getElementById('keywordsGrid')!;
  if (keywords.length === 0) {
    container.innerHTML = `<div class="empty-state"><div class="empty-state-icon">🏷️</div><h3 class="empty-state-title">Nenhuma palavra-chave</h3><p class="empty-state-text">Crie palavras-chave para substituição automática</p></div>`;
    return;
  }
  container.innerHTML = keywords.map(k => `
    <div class="card">
      <div class="card-header">
        <div class="card-icon" style="background:var(--teal-primary);color:#fff">🏷️</div>
        <span class="card-title">&lt;${k.key}&gt;</span>
        <div class="card-actions">
          <button class="card-action-btn" onclick="openEditKeywordModal('${k.id}')">✏️</button>
          <button class="card-action-btn danger" onclick="deleteKeyword('${k.id}')">🗑️</button>
        </div>
      </div>
      <div class="card-content">${k.value.substring(0, 100)}${k.value.length > 100 ? '...' : ''}</div>
    </div>
  `).join('');
}

function renderProfile() {
  const name = currentUser?.user_metadata?.full_name || currentUser?.user_metadata?.name || '';
  document.getElementById('profileName')!.value = name;
  document.getElementById('profileEmail')!.value = currentUser?.email || '';
  document.getElementById('userName')!.textContent = name || 'Usuário';
  document.getElementById('userEmail')!.textContent = currentUser?.email || '';
  document.getElementById('userAvatar')!.textContent = (name || currentUser?.email || 'U')[0].toUpperCase();
}

function renderColorPicker(containerId: string, selectedColor: string) {
  const container = document.getElementById(containerId)!;
  container.innerHTML = COLORS.map(c => `<div class="color-option ${c === selectedColor ? 'selected' : ''}" style="background:${c}" data-color="${c}" onclick="selectColor('${containerId}', '${c}')"></div>`).join('');
}

function renderIconPicker(containerId: string, selectedIcon: string) {
  const container = document.getElementById(containerId)!;
  container.innerHTML = ICONS.map(i => `<div class="icon-option ${i === selectedIcon ? 'selected' : ''}" data-icon="${i}" onclick="selectIcon('${containerId}', '${i}')">${i}</div>`).join('');
}

function selectColor(containerId: string, color: string) {
  document.querySelectorAll(`#${containerId} .color-option`).forEach(el => el.classList.remove('selected'));
  document.querySelector(`#${containerId} .color-option[data-color="${color}"]`)?.classList.add('selected');
}

function selectIcon(containerId: string, icon: string) {
  document.querySelectorAll(`#${containerId} .icon-option`).forEach(el => el.classList.remove('selected'));
  document.querySelector(`#${containerId} .icon-option[data-icon="${icon}"]`)?.classList.add('selected');
}

function openModal(id: string) { document.getElementById(id)!.classList.add('visible'); }
function closeModal(id: string) { document.getElementById(id)!.classList.remove('visible'); }

function openAddGroupModal() {
  editingGroupId = null;
  document.getElementById('groupModalTitle')!.textContent = 'Novo Grupo';
  document.getElementById('groupName')!.value = '';
  renderColorPicker('groupColorPicker', COLORS[0]);
  renderIconPicker('groupIconPicker', ICONS[0]);
  openModal('groupModal');
}

function openEditGroupModal(id: string) {
  const group = tabGroups.find(g => g.id === id);
  if (!group) return;
  editingGroupId = id;
  document.getElementById('groupModalTitle')!.textContent = 'Editar Grupo';
  document.getElementById('groupName')!.value = group.name;
  renderColorPicker('groupColorPicker', group.color || COLORS[0]);
  renderIconPicker('groupIconPicker', group.icon || ICONS[0]);
  openModal('groupModal');
}

function openAddTabModal(groupId: string) {
  selectedGroupId = groupId;
  editingTabId = null;
  document.getElementById('tabModalTitle')!.textContent = 'Nova Aba';
  document.getElementById('tabName')!.value = '';
  document.getElementById('tabUrl')!.value = '';
  document.getElementById('tabShortcut')!.value = '';
  document.getElementById('tabZoom')!.value = '100';
  renderColorPicker('tabColorPicker', COLORS[0]);
  renderIconPicker('tabIconPicker', '🌐');
  openModal('tabModal');
}

function openEditTabModal(id: string) {
  const tab = tabs.find(t => t.id === id);
  if (!tab) return;
  editingTabId = id;
  selectedGroupId = tab.group_id;
  document.getElementById('tabModalTitle')!.textContent = 'Editar Aba';
  document.getElementById('tabName')!.value = tab.name;
  document.getElementById('tabUrl')!.value = tab.url;
  document.getElementById('tabShortcut')!.value = tab.keyboard_shortcut || '';
  document.getElementById('tabZoom')!.value = String(tab.zoom || 100);
  renderColorPicker('tabColorPicker', tab.color || COLORS[0]);
  renderIconPicker('tabIconPicker', tab.icon || '🌐');
  openModal('tabModal');
}

function openEditShortcutModal(id: string) {
  const s = textShortcuts.find(x => x.id === id);
  if (!s) return;
  editingShortcutId = id;
  document.getElementById('shortcutModalTitle')!.textContent = 'Editar Atalho';
  document.getElementById('shortcutCommand')!.value = s.command;
  document.getElementById('shortcutDescription')!.value = s.description || '';
  document.getElementById('shortcutText')!.value = s.expanded_text;
  document.getElementById('shortcutCategory')!.value = s.category || '';
  openModal('shortcutModal');
}

function openEditKeywordModal(id: string) {
  const k = keywords.find(x => x.id === id);
  if (!k) return;
  editingKeywordId = id;
  document.getElementById('keywordModalTitle')!.textContent = 'Editar Palavra-chave';
  document.getElementById('keywordKey')!.value = k.key;
  document.getElementById('keywordValue')!.value = k.value;
  openModal('keywordModal');
}

async function saveGroup() {
  const name = document.getElementById('groupName')!.value.trim();
  const color = document.querySelector('#groupColorPicker .color-option.selected')?.dataset.color || COLORS[0];
  const icon = document.querySelector('#groupIconPicker .icon-option.selected')?.dataset.icon || ICONS[0];
  if (!name) return showToast('Nome é obrigatório', 'error');
  
  if (editingGroupId) {
    await supabase.update('tab_groups', editingGroupId, { name, color, icon });
    showToast('Grupo atualizado!', 'success');
  } else {
    await supabase.insert('tab_groups', { name, color, icon, user_id: currentUser!.id, position: tabGroups.length });
    showToast('Grupo criado!', 'success');
  }
  closeModal('groupModal');
  await loadData();
  if (currentScreen === 'groups') renderGroupsGrid();
}

async function saveTab() {
  const name = document.getElementById('tabName')!.value.trim();
  const url = document.getElementById('tabUrl')!.value.trim();
  const shortcut = document.getElementById('tabShortcut')!.value.trim();
  const zoom = parseInt(document.getElementById('tabZoom')!.value) || 100;
  const color = document.querySelector('#tabColorPicker .color-option.selected')?.dataset.color || COLORS[0];
  const icon = document.querySelector('#tabIconPicker .icon-option.selected')?.dataset.icon || '🌐';
  if (!name || !url) return showToast('Nome e URL são obrigatórios', 'error');
  
  if (editingTabId) {
    await supabase.update('tabs', editingTabId, { name, url, keyboard_shortcut: shortcut || null, zoom, color, icon });
    showToast('Aba atualizada!', 'success');
  } else {
    const groupTabs = tabs.filter(t => t.group_id === selectedGroupId);
    await supabase.insert('tabs', { name, url, keyboard_shortcut: shortcut || null, zoom, color, icon, group_id: selectedGroupId, user_id: currentUser!.id, position: groupTabs.length });
    showToast('Aba criada!', 'success');
  }
  closeModal('tabModal');
  await loadData();
  if (currentScreen === 'groups') renderGroupsGrid();
}

async function saveShortcut() {
  const command = document.getElementById('shortcutCommand')!.value.trim();
  const description = document.getElementById('shortcutDescription')!.value.trim();
  const text = document.getElementById('shortcutText')!.value.trim();
  const category = document.getElementById('shortcutCategory')!.value.trim() || 'geral';
  if (!command || !text) return showToast('Comando e texto são obrigatórios', 'error');
  
  if (editingShortcutId) {
    await supabase.update('text_shortcuts', editingShortcutId, { command, description, expanded_text: text, category });
    showToast('Atalho atualizado!', 'success');
  } else {
    await supabase.insert('text_shortcuts', { command, description, expanded_text: text, category, user_id: currentUser!.id });
    showToast('Atalho criado!', 'success');
  }
  closeModal('shortcutModal');
  await loadData();
  renderShortcutsGrid();
}

async function saveKeyword() {
  const key = document.getElementById('keywordKey')!.value.trim().toUpperCase();
  const value = document.getElementById('keywordValue')!.value.trim();
  if (!key || !value) return showToast('Chave e valor são obrigatórios', 'error');
  
  if (editingKeywordId) {
    await supabase.update('keywords', editingKeywordId, { key, value });
    showToast('Palavra-chave atualizada!', 'success');
  } else {
    await supabase.insert('keywords', { key, value, user_id: currentUser!.id });
    showToast('Palavra-chave criada!', 'success');
  }
  closeModal('keywordModal');
  await loadData();
  renderKeywordsGrid();
}

async function deleteGroup(id: string) {
  confirmCallback = async () => { await supabase.delete('tab_groups', id); await loadData(); renderGroupsGrid(); showToast('Grupo excluído!', 'success'); closeModal('confirmModal'); };
  document.getElementById('confirmMessage')!.textContent = 'Excluir este grupo e todas as suas abas?';
  openModal('confirmModal');
}

async function deleteTab(id: string) {
  confirmCallback = async () => { await supabase.delete('tabs', id); await loadData(); renderGroupsGrid(); showToast('Aba excluída!', 'success'); closeModal('confirmModal'); };
  document.getElementById('confirmMessage')!.textContent = 'Excluir esta aba?';
  openModal('confirmModal');
}

async function deleteShortcut(id: string) {
  confirmCallback = async () => { await supabase.delete('text_shortcuts', id); await loadData(); renderShortcutsGrid(); showToast('Atalho excluído!', 'success'); closeModal('confirmModal'); };
  document.getElementById('confirmMessage')!.textContent = 'Excluir este atalho?';
  openModal('confirmModal');
}

async function deleteKeyword(id: string) {
  confirmCallback = async () => { await supabase.delete('keywords', id); await loadData(); renderKeywordsGrid(); showToast('Palavra-chave excluída!', 'success'); closeModal('confirmModal'); };
  document.getElementById('confirmMessage')!.textContent = 'Excluir esta palavra-chave?';
  openModal('confirmModal');
}

function toggleGroup(groupId: string) {
  const group = document.querySelector(`.tab-group[data-group-id="${groupId}"]`);
  group?.classList.toggle('expanded');
}

async function init() {
  const stored = await window.electronAPI?.getSession?.();
  if (stored?.access_token && stored?.user) {
    currentSession = stored;
    currentUser = stored.user;
    supabase.setAccessToken(stored.access_token);
    await showApp();
  } else {
    showAuth();
  }
  document.getElementById('loadingScreen')!.style.display = 'none';
}

function showAuth() {
  document.getElementById('authScreen')!.style.display = 'flex';
  document.getElementById('appScreen')!.style.display = 'none';
}

async function showApp() {
  document.getElementById('authScreen')!.style.display = 'none';
  document.getElementById('appScreen')!.style.display = 'block';
  await loadData();
  renderProfile();
  showScreen('home');
}

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
  init();

  let isLogin = true;
  document.getElementById('authToggleLink')?.addEventListener('click', () => {
    isLogin = !isLogin;
    document.getElementById('nameGroup')!.style.display = isLogin ? 'none' : 'block';
    document.getElementById('authBtn')!.textContent = isLogin ? 'Entrar' : 'Criar Conta';
    document.getElementById('authToggleText')!.textContent = isLogin ? 'Não tem conta?' : 'Já tem conta?';
    document.getElementById('authToggleLink')!.textContent = isLogin ? 'Criar conta' : 'Entrar';
  });

  document.getElementById('authForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('emailInput')!.value;
    const password = document.getElementById('passwordInput')!.value;
    const name = document.getElementById('nameInput')!.value;
    const btn = document.getElementById('authBtn')!;
    btn.disabled = true;
    btn.textContent = 'Aguarde...';

    const result = isLogin ? await supabase.signInWithPassword(email, password) : await supabase.signUp(email, password, name);
    if (result.error) {
      document.getElementById('authError')!.style.display = 'block';
      document.getElementById('authError')!.textContent = result.error.message || result.error.error_description || 'Erro ao autenticar';
      btn.disabled = false;
      btn.textContent = isLogin ? 'Entrar' : 'Criar Conta';
      return;
    }
    if (result.data.session) {
      currentSession = result.data.session;
      currentUser = result.data.user;
      supabase.setAccessToken(result.data.session.access_token);
      await window.electronAPI?.saveSession?.(result.data.session);
      await showApp();
    } else {
      showToast('Verifique seu email para confirmar o cadastro', 'warning');
    }
    btn.disabled = false;
    btn.textContent = isLogin ? 'Entrar' : 'Criar Conta';
  });

  document.querySelectorAll('.nav-item[data-screen]').forEach(item => {
    item.addEventListener('click', () => showScreen(item.dataset.screen!));
  });

  document.getElementById('addGroupBtn')?.addEventListener('click', openAddGroupModal);
  document.getElementById('saveGroupBtn')?.addEventListener('click', saveGroup);
  document.getElementById('saveTabBtn')?.addEventListener('click', saveTab);
  document.getElementById('addShortcutBtn')?.addEventListener('click', () => { editingShortcutId = null; document.getElementById('shortcutModalTitle')!.textContent = 'Novo Atalho'; document.getElementById('shortcutCommand')!.value = ''; document.getElementById('shortcutDescription')!.value = ''; document.getElementById('shortcutText')!.value = ''; document.getElementById('shortcutCategory')!.value = ''; openModal('shortcutModal'); });
  document.getElementById('saveShortcutBtn')?.addEventListener('click', saveShortcut);
  document.getElementById('addKeywordBtn')?.addEventListener('click', () => { editingKeywordId = null; document.getElementById('keywordModalTitle')!.textContent = 'Nova Palavra-chave'; document.getElementById('keywordKey')!.value = ''; document.getElementById('keywordValue')!.value = ''; openModal('keywordModal'); });
  document.getElementById('saveKeywordBtn')?.addEventListener('click', saveKeyword);
  document.getElementById('confirmBtn')?.addEventListener('click', () => confirmCallback?.());
  document.getElementById('logoutBtn')?.addEventListener('click', async () => { await window.electronAPI?.logout?.(); currentSession = null; currentUser = null; supabase.setAccessToken(null); showAuth(); });

  document.getElementById('navBack')?.addEventListener('click', () => {
    const webview = document.querySelector('webview') as any;
    if (webview?.goBack) webview.goBack();
  });
  document.getElementById('navForward')?.addEventListener('click', () => {
    const webview = document.querySelector('webview') as any;
    if (webview?.goForward) webview.goForward();
  });
  document.getElementById('navRefresh')?.addEventListener('click', () => {
    document.querySelectorAll('webview').forEach((wv: any) => wv.reload?.());
  });
  document.getElementById('navZoomIn')?.addEventListener('click', () => {
    currentZoom = Math.min(200, currentZoom + 10);
    document.getElementById('navZoomValue')!.textContent = `${currentZoom}%`;
    document.querySelectorAll('webview').forEach((wv: any) => wv.setZoomFactor?.(currentZoom / 100));
  });
  document.getElementById('navZoomOut')?.addEventListener('click', () => {
    currentZoom = Math.max(50, currentZoom - 10);
    document.getElementById('navZoomValue')!.textContent = `${currentZoom}%`;
    document.querySelectorAll('webview').forEach((wv: any) => wv.setZoomFactor?.(currentZoom / 100));
  });
  document.getElementById('navUrlInput')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      let url = (e.target as HTMLInputElement).value;
      if (!url.startsWith('http')) url = 'https://' + url;
      const webview = document.querySelector('webview') as any;
      if (webview?.loadURL) webview.loadURL(url);
    }
  });

  // Layout buttons
  document.querySelectorAll('.layout-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const layout = btn.getAttribute('data-layout') || 'single';
      setLayout(layout);
    });
  });
});

// Expose functions globally
(window as any).toggleGroup = toggleGroup;
(window as any).openTab = openTab;
(window as any).openEditGroupModal = openEditGroupModal;
(window as any).openAddTabModal = openAddTabModal;
(window as any).openEditTabModal = openEditTabModal;
(window as any).openEditShortcutModal = openEditShortcutModal;
(window as any).openEditKeywordModal = openEditKeywordModal;
(window as any).deleteGroup = deleteGroup;
(window as any).deleteTab = deleteTab;
(window as any).deleteShortcut = deleteShortcut;
(window as any).deleteKeyword = deleteKeyword;
(window as any).closeModal = closeModal;
(window as any).selectColor = selectColor;
(window as any).selectIcon = selectIcon;
(window as any).setLayout = setLayout;

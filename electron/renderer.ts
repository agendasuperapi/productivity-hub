// @ts-nocheck
// Renderer script - GerenciaZap Electron com Supabase (Completo)

// ============ SUPABASE CONFIG ============
const SUPABASE_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplZ2pydmdscmpuaHVreHFreG9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MTA4NTAsImV4cCI6MjA4MjA4Njg1MH0.mhrSxMboDPKan4ez71_f5qjwUhxGMCq61GXvuTo93MU';

// ============ TYPES ============
interface User {
  id: string;
  email?: string;
  user_metadata?: {
    full_name?: string;
    name?: string;
  };
}

interface Session {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
  user: User;
}

interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
  user_id: string;
}

interface Tab {
  id: string;
  name: string;
  url: string;
  urls?: any;
  icon?: string;
  color?: string;
  keyboard_shortcut?: string;
  zoom?: number;
  layout_type?: string;
  group_id: string;
  position: number;
  open_as_window?: boolean;
  user_id: string;
}

interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
  user_id: string;
}

// ============ STATE ============
let currentSession: Session | null = null;
let currentUser: User | null = null;
let tabGroups: TabGroup[] = [];
let tabs: Tab[] = [];
let textShortcuts: TextShortcut[] = [];
let currentScreen = 'home';
let confirmCallback: (() => void) | null = null;

// ============ SUPABASE CLIENT ============
class SupabaseClient {
  private url: string;
  private key: string;
  private accessToken: string | null = null;

  constructor(url: string, key: string) {
    this.url = url;
    this.key = key;
  }

  setAccessToken(token: string | null) {
    this.accessToken = token;
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'apikey': this.key,
      'Content-Type': 'application/json',
    };
    if (this.accessToken) {
      headers['Authorization'] = `Bearer ${this.accessToken}`;
    }
    return headers;
  }

  async signInWithPassword(email: string, password: string): Promise<{ data: { session: Session | null; user: User | null }; error: any }> {
    try {
      const response = await fetch(`${this.url}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: { 'apikey': this.key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await response.json();
      if (!response.ok) return { data: { session: null, user: null }, error: data };
      const session: Session = {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expires_at: data.expires_at,
        user: data.user,
      };
      return { data: { session, user: data.user }, error: null };
    } catch (error) {
      return { data: { session: null, user: null }, error };
    }
  }

  async signUp(email: string, password: string, name: string): Promise<{ data: { session: Session | null; user: User | null }; error: any }> {
    try {
      const response = await fetch(`${this.url}/auth/v1/signup`, {
        method: 'POST',
        headers: { 'apikey': this.key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, data: { full_name: name } }),
      });
      const data = await response.json();
      if (!response.ok) return { data: { session: null, user: null }, error: data };
      if (data.access_token) {
        const session: Session = {
          access_token: data.access_token,
          refresh_token: data.refresh_token,
          expires_at: data.expires_at,
          user: data.user,
        };
        return { data: { session, user: data.user }, error: null };
      }
      return { data: { session: null, user: data.user }, error: null };
    } catch (error) {
      return { data: { session: null, user: null }, error };
    }
  }

  async refreshSession(refreshToken: string): Promise<{ data: { session: Session | null }; error: any }> {
    try {
      const response = await fetch(`${this.url}/auth/v1/token?grant_type=refresh_token`, {
        method: 'POST',
        headers: { 'apikey': this.key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      const data = await response.json();
      if (!response.ok) return { data: { session: null }, error: data };
      const session: Session = {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expires_at: data.expires_at,
        user: data.user,
      };
      return { data: { session }, error: null };
    } catch (error) {
      return { data: { session: null }, error };
    }
  }

  from(table: string) {
    const client = this;
    return {
      async select(columns = '*'): Promise<{ data: any[]; error: any }> {
        try {
          const response = await fetch(`${client.url}/rest/v1/${table}?select=${columns}&order=position.asc`, {
            headers: client.getHeaders(),
          });
          const data = await response.json();
          if (!response.ok) return { data: [], error: data };
          return { data, error: null };
        } catch (error) {
          return { data: [], error };
        }
      },
      async insert(values: any): Promise<{ data: any; error: any }> {
        try {
          const response = await fetch(`${client.url}/rest/v1/${table}`, {
            method: 'POST',
            headers: { ...client.getHeaders(), 'Prefer': 'return=representation' },
            body: JSON.stringify(values),
          });
          const data = await response.json();
          if (!response.ok) return { data: null, error: data };
          return { data: Array.isArray(data) ? data[0] : data, error: null };
        } catch (error) {
          return { data: null, error };
        }
      },
      update(values: any) {
        return {
          async eq(column: string, value: string): Promise<{ data: any; error: any }> {
            try {
              const response = await fetch(`${client.url}/rest/v1/${table}?${column}=eq.${value}`, {
                method: 'PATCH',
                headers: { ...client.getHeaders(), 'Prefer': 'return=representation' },
                body: JSON.stringify(values),
              });
              const data = await response.json();
              if (!response.ok) return { data: null, error: data };
              return { data: Array.isArray(data) ? data[0] : data, error: null };
            } catch (error) {
              return { data: null, error };
            }
          }
        };
      },
      delete() {
        return {
          async eq(column: string, value: string): Promise<{ error: any }> {
            try {
              const response = await fetch(`${client.url}/rest/v1/${table}?${column}=eq.${value}`, {
                method: 'DELETE',
                headers: client.getHeaders(),
              });
              if (!response.ok) {
                const data = await response.json();
                return { error: data };
              }
              return { error: null };
            } catch (error) {
              return { error };
            }
          }
        };
      },
    };
  }
}

const supabase = new SupabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============ UTILITIES ============
function showToast(message: string, type: 'success' | 'error' = 'success') {
  const container = document.getElementById('toastContainer');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<span>${type === 'success' ? '✅' : '❌'}</span><span>${message}</span>`;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

function showError(message: string) {
  const errorEl = document.getElementById('authError');
  if (errorEl) {
    errorEl.textContent = message;
    errorEl.classList.add('visible');
  }
}

function hideError() {
  const errorEl = document.getElementById('authError');
  if (errorEl) errorEl.classList.remove('visible');
}

function openModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.add('active');
}

function closeModal(modalId: string) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.remove('active');
}

function showConfirm(title: string, text: string, callback: () => void) {
  document.getElementById('confirmTitle')!.textContent = title;
  document.getElementById('confirmText')!.textContent = text;
  confirmCallback = callback;
  openModal('confirmModal');
}

// Global functions
(window as any).closeModal = closeModal;
(window as any).navigateTo = navigateTo;

function setLoading(loading: boolean) {
  const loadingScreen = document.getElementById('loadingScreen');
  if (loadingScreen) loadingScreen.style.display = loading ? 'flex' : 'none';
}

function showAuth() {
  document.getElementById('loadingScreen')!.style.display = 'none';
  document.getElementById('authScreen')!.style.display = 'flex';
  document.getElementById('appScreen')!.style.display = 'none';
}

function showApp() {
  document.getElementById('loadingScreen')!.style.display = 'none';
  document.getElementById('authScreen')!.style.display = 'none';
  document.getElementById('appScreen')!.style.display = 'flex';
  updateUserInfo();
  loadData();
}

function updateUserInfo() {
  if (!currentUser) return;
  const name = currentUser.user_metadata?.full_name || currentUser.user_metadata?.name || 'Usuário';
  const email = currentUser.email || '';
  const initial = name.charAt(0).toUpperCase();
  
  const avatarEl = document.getElementById('userAvatar');
  const nameEl = document.getElementById('userName');
  const emailEl = document.getElementById('userEmail');
  const profileEl = document.getElementById('profileInfo');
  
  if (avatarEl) avatarEl.textContent = initial;
  if (nameEl) nameEl.textContent = name;
  if (emailEl) emailEl.textContent = email;
  if (profileEl) {
    profileEl.innerHTML = `
      <p style="font-size: 14px; margin-bottom: 8px;"><strong>Nome:</strong> ${name}</p>
      <p style="font-size: 14px; margin-bottom: 8px;"><strong>Email:</strong> ${email}</p>
      <p style="font-size: 14px; color: var(--text-muted);"><strong>ID:</strong> ${currentUser.id}</p>
    `;
  }
}

function navigateTo(screen: string) {
  currentScreen = screen;
  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.toggle('active', item.getAttribute('data-screen') === screen);
  });
  document.querySelectorAll('.screen').forEach(s => {
    s.classList.toggle('active', s.id === `${screen}Screen`);
  });
  if (screen === 'home') renderHome();
  else if (screen === 'groups') renderGroups();
  else if (screen === 'shortcuts') renderShortcuts();
}

// ============ AUTH ============
async function initAuth() {
  setLoading(true);
  try {
    const savedSession = await window.electronAPI.getSession();
    if (savedSession) {
      const { data, error } = await supabase.refreshSession(savedSession.refresh_token);
      if (data.session) {
        currentSession = data.session;
        currentUser = data.session.user;
        supabase.setAccessToken(data.session.access_token);
        await window.electronAPI.setSession(data.session);
        showApp();
        return;
      }
    }
    showAuth();
  } catch (error) {
    console.error('Auth init error:', error);
    showAuth();
  }
}

async function handleLogin(email: string, password: string) {
  hideError();
  const { data, error } = await supabase.signInWithPassword(email, password);
  if (error) {
    showError(error.error_description || error.message || error.msg || 'Erro ao fazer login');
    return false;
  }
  if (data.session) {
    currentSession = data.session;
    currentUser = data.user;
    supabase.setAccessToken(data.session.access_token);
    await window.electronAPI.setSession(data.session);
    showApp();
    return true;
  }
  showError('Erro ao fazer login');
  return false;
}

async function handleSignup(name: string, email: string, password: string) {
  hideError();
  const { data, error } = await supabase.signUp(email, password, name);
  if (error) {
    showError(error.error_description || error.message || error.msg || 'Erro ao criar conta');
    return false;
  }
  if (data.session) {
    currentSession = data.session;
    currentUser = data.user;
    supabase.setAccessToken(data.session.access_token);
    await window.electronAPI.setSession(data.session);
    showApp();
    return true;
  } else if (data.user) {
    showError('Conta criada! Verifique seu email para confirmar.');
    return false;
  }
  showError('Erro ao criar conta');
  return false;
}

async function handleLogout() {
  await window.electronAPI.clearSession();
  currentSession = null;
  currentUser = null;
  supabase.setAccessToken(null);
  tabGroups = [];
  tabs = [];
  textShortcuts = [];
  showAuth();
}

// ============ DATA ============
async function loadData() {
  try {
    const [groupsRes, tabsRes, shortcutsRes] = await Promise.all([
      supabase.from('tab_groups').select('*'),
      supabase.from('tabs').select('*'),
      supabase.from('text_shortcuts').select('*'),
    ]);
    
    if (!groupsRes.error) tabGroups = groupsRes.data;
    if (!tabsRes.error) tabs = tabsRes.data;
    if (!shortcutsRes.error) textShortcuts = shortcutsRes.data;
    
    await registerKeyboardShortcuts();
    updateStats();
    renderHome();
  } catch (error) {
    console.error('Error loading data:', error);
    showToast('Erro ao carregar dados', 'error');
  }
}

async function registerKeyboardShortcuts() {
  await window.electronAPI.unregisterAllShortcuts();
  for (const tab of tabs) {
    if (tab.keyboard_shortcut) {
      try {
        await window.electronAPI.registerShortcut(tab.keyboard_shortcut, tab.id);
      } catch (error) {
        console.error(`Error registering shortcut ${tab.keyboard_shortcut}:`, error);
      }
    }
  }
}

function updateStats() {
  const groupsEl = document.getElementById('statsGroups');
  const tabsEl = document.getElementById('statsTabs');
  const shortcutsEl = document.getElementById('statsShortcuts');
  if (groupsEl) groupsEl.textContent = String(tabGroups.length);
  if (tabsEl) tabsEl.textContent = String(tabs.length);
  if (shortcutsEl) shortcutsEl.textContent = String(textShortcuts.length);
}

// ============ HOME ============
function renderHome() {
  const container = document.getElementById('homeContent');
  const emptyState = document.getElementById('homeEmptyState');
  if (!container || !emptyState) return;
  
  updateStats();
  
  if (tabs.length === 0) {
    container.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  container.style.display = 'block';
  emptyState.style.display = 'none';
  container.innerHTML = '<div class="groups-grid"></div>';
  const grid = container.querySelector('.groups-grid')!;
  
  tabGroups.forEach(group => {
    const groupTabs = tabs.filter(t => t.group_id === group.id);
    if (groupTabs.length === 0) return;
    
    const card = document.createElement('div');
    card.className = 'group-card';
    card.innerHTML = `
      <div class="group-header" style="border-left: 4px solid ${group.color || '#22d3ee'}">
        <div class="group-info">
          <span class="group-icon">${group.icon || '📁'}</span>
          <span class="group-name">${group.name}</span>
        </div>
        <span class="badge badge-gray">${groupTabs.length} abas</span>
      </div>
      <div class="group-tabs">
        ${groupTabs.map(tab => `
          <div class="tab-item" data-tab-id="${tab.id}">
            <span class="tab-icon">${tab.icon || '🔗'}</span>
            <div class="tab-info">
              <div class="tab-name">${tab.name}</div>
              <div class="tab-url">${tab.url}</div>
            </div>
            <div class="tab-badges">
              ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ''}
              ${tab.zoom && tab.zoom !== 100 ? `<span class="tab-zoom">${tab.zoom}%</span>` : ''}
            </div>
          </div>
        `).join('')}
      </div>
    `;
    
    card.querySelectorAll('.tab-item').forEach(item => {
      item.addEventListener('click', () => {
        const tabId = item.getAttribute('data-tab-id');
        const tab = tabs.find(t => t.id === tabId);
        if (tab) openTab(tab);
      });
    });
    
    grid.appendChild(card);
  });
}

async function openTab(tab: Tab) {
  try {
    await window.electronAPI.createWindow({
      id: tab.id,
      name: tab.name,
      url: tab.url,
      urls: tab.urls,
      zoom: tab.zoom,
      layout_type: tab.layout_type,
      open_as_window: tab.open_as_window,
    });
  } catch (error) {
    console.error('Error opening tab:', error);
    showToast('Erro ao abrir aba', 'error');
  }
}

// ============ GROUPS ============
function renderGroups() {
  const container = document.getElementById('groupsList');
  const emptyState = document.getElementById('groupsEmptyState');
  if (!container || !emptyState) return;
  
  if (tabGroups.length === 0) {
    container.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  container.style.display = 'grid';
  emptyState.style.display = 'none';
  container.innerHTML = '';
  
  tabGroups.forEach(group => {
    const groupTabs = tabs.filter(t => t.group_id === group.id);
    const card = document.createElement('div');
    card.className = 'group-card';
    card.innerHTML = `
      <div class="group-header" style="border-left: 4px solid ${group.color || '#22d3ee'}">
        <div class="group-info">
          <span class="group-icon">${group.icon || '📁'}</span>
          <span class="group-name">${group.name}</span>
        </div>
        <div class="card-actions">
          <button class="btn btn-sm btn-primary add-tab-btn" data-group-id="${group.id}">+ Aba</button>
          <button class="btn btn-sm btn-secondary edit-group-btn" data-group-id="${group.id}">✏️</button>
          <button class="btn btn-sm btn-danger delete-group-btn" data-group-id="${group.id}">🗑️</button>
        </div>
      </div>
      <div class="group-tabs">
        ${groupTabs.length === 0 ? '<p style="padding: 20px; color: var(--text-muted); text-align: center; font-size: 13px;">Nenhuma aba neste grupo. Clique em "+ Aba" para adicionar.</p>' : ''}
        ${groupTabs.map(tab => `
          <div class="tab-item">
            <span class="tab-icon">${tab.icon || '🔗'}</span>
            <div class="tab-info">
              <div class="tab-name">${tab.name}</div>
              <div class="tab-url">${tab.url}</div>
            </div>
            <div class="tab-badges">
              ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ''}
              ${tab.zoom && tab.zoom !== 100 ? `<span class="tab-zoom">${tab.zoom}%</span>` : ''}
            </div>
            <div class="card-actions">
              <button class="btn btn-icon btn-ghost edit-tab-btn" data-tab-id="${tab.id}">✏️</button>
              <button class="btn btn-icon btn-ghost delete-tab-btn" data-tab-id="${tab.id}" style="color: var(--error);">🗑️</button>
            </div>
          </div>
        `).join('')}
      </div>
    `;
    container.appendChild(card);
  });
  
  // Event listeners
  container.querySelectorAll('.add-tab-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const groupId = btn.getAttribute('data-group-id')!;
      openTabModal(null, groupId);
    });
  });
  
  container.querySelectorAll('.edit-group-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const groupId = btn.getAttribute('data-group-id')!;
      const group = tabGroups.find(g => g.id === groupId);
      if (group) openGroupModal(group);
    });
  });
  
  container.querySelectorAll('.delete-group-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const groupId = btn.getAttribute('data-group-id')!;
      const group = tabGroups.find(g => g.id === groupId);
      showConfirm(
        'Excluir Grupo',
        `Tem certeza que deseja excluir o grupo "${group?.name}"? Todas as abas deste grupo também serão excluídas.`,
        async () => {
          // Delete all tabs in the group first
          for (const tab of tabs.filter(t => t.group_id === groupId)) {
            await supabase.from('tabs').delete().eq('id', tab.id);
          }
          const { error } = await supabase.from('tab_groups').delete().eq('id', groupId);
          closeModal('confirmModal');
          if (!error) {
            tabGroups = tabGroups.filter(g => g.id !== groupId);
            tabs = tabs.filter(t => t.group_id !== groupId);
            renderGroups();
            updateStats();
            showToast('Grupo excluído com sucesso');
          } else {
            showToast('Erro ao excluir grupo', 'error');
          }
        }
      );
    });
  });
  
  container.querySelectorAll('.edit-tab-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const tabId = btn.getAttribute('data-tab-id')!;
      const tab = tabs.find(t => t.id === tabId);
      if (tab) openTabModal(tab, tab.group_id);
    });
  });
  
  container.querySelectorAll('.delete-tab-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const tabId = btn.getAttribute('data-tab-id')!;
      const tab = tabs.find(t => t.id === tabId);
      showConfirm(
        'Excluir Aba',
        `Tem certeza que deseja excluir a aba "${tab?.name}"?`,
        async () => {
          const { error } = await supabase.from('tabs').delete().eq('id', tabId);
          closeModal('confirmModal');
          if (!error) {
            tabs = tabs.filter(t => t.id !== tabId);
            renderGroups();
            updateStats();
            await registerKeyboardShortcuts();
            showToast('Aba excluída com sucesso');
          } else {
            showToast('Erro ao excluir aba', 'error');
          }
        }
      );
    });
  });
}

function openGroupModal(group: TabGroup | null = null) {
  document.getElementById('groupModalTitle')!.textContent = group ? 'Editar Grupo' : 'Novo Grupo';
  (document.getElementById('groupId') as HTMLInputElement).value = group?.id || '';
  (document.getElementById('groupName') as HTMLInputElement).value = group?.name || '';
  (document.getElementById('groupIcon') as HTMLInputElement).value = group?.icon || '📁';
  (document.getElementById('groupColor') as HTMLInputElement).value = group?.color || '#22d3ee';
  
  // Update icon picker
  document.querySelectorAll('#groupIconPicker .icon-option').forEach(btn => {
    btn.classList.toggle('selected', btn.getAttribute('data-icon') === (group?.icon || '📁'));
  });
  
  // Update color picker
  document.querySelectorAll('#groupColorPicker .color-option').forEach(btn => {
    btn.classList.toggle('selected', btn.getAttribute('data-color') === (group?.color || '#22d3ee'));
  });
  
  openModal('groupModal');
}

function openTabModal(tab: Tab | null, groupId: string) {
  document.getElementById('tabModalTitle')!.textContent = tab ? 'Editar Aba' : 'Nova Aba';
  (document.getElementById('tabId') as HTMLInputElement).value = tab?.id || '';
  (document.getElementById('tabGroupId') as HTMLInputElement).value = groupId;
  (document.getElementById('tabName') as HTMLInputElement).value = tab?.name || '';
  (document.getElementById('tabUrl') as HTMLInputElement).value = tab?.url || '';
  (document.getElementById('tabShortcut') as HTMLInputElement).value = tab?.keyboard_shortcut || '';
  (document.getElementById('tabZoom') as HTMLInputElement).value = String(tab?.zoom || 100);
  (document.getElementById('tabIcon') as HTMLInputElement).value = tab?.icon || '🔗';
  (document.getElementById('tabOpenAsWindow') as HTMLInputElement).checked = tab?.open_as_window || false;
  
  // Update icon picker
  document.querySelectorAll('#tabIconPicker .icon-option').forEach(btn => {
    btn.classList.toggle('selected', btn.getAttribute('data-icon') === (tab?.icon || '🔗'));
  });
  
  openModal('tabModal');
}

async function saveGroup() {
  const id = (document.getElementById('groupId') as HTMLInputElement).value;
  const name = (document.getElementById('groupName') as HTMLInputElement).value;
  const icon = (document.getElementById('groupIcon') as HTMLInputElement).value;
  const color = (document.getElementById('groupColor') as HTMLInputElement).value;
  
  if (!name) {
    showToast('Nome é obrigatório', 'error');
    return;
  }
  
  if (id) {
    // Update
    const { data, error } = await supabase.from('tab_groups').update({ name, icon, color }).eq('id', id);
    if (error) {
      showToast('Erro ao atualizar grupo', 'error');
      return;
    }
    const index = tabGroups.findIndex(g => g.id === id);
    if (index !== -1) {
      tabGroups[index] = { ...tabGroups[index], name, icon, color };
    }
    showToast('Grupo atualizado com sucesso');
  } else {
    // Create
    const { data, error } = await supabase.from('tab_groups').insert({
      name,
      icon,
      color,
      position: tabGroups.length,
      user_id: currentUser!.id,
    });
    if (error) {
      showToast('Erro ao criar grupo', 'error');
      return;
    }
    if (data) tabGroups.push(data);
    showToast('Grupo criado com sucesso');
  }
  
  closeModal('groupModal');
  renderGroups();
  renderHome();
  updateStats();
}

async function saveTab() {
  const id = (document.getElementById('tabId') as HTMLInputElement).value;
  const groupId = (document.getElementById('tabGroupId') as HTMLInputElement).value;
  const name = (document.getElementById('tabName') as HTMLInputElement).value;
  const url = (document.getElementById('tabUrl') as HTMLInputElement).value;
  const keyboard_shortcut = (document.getElementById('tabShortcut') as HTMLInputElement).value || null;
  const zoom = parseInt((document.getElementById('tabZoom') as HTMLInputElement).value) || 100;
  const icon = (document.getElementById('tabIcon') as HTMLInputElement).value;
  const open_as_window = (document.getElementById('tabOpenAsWindow') as HTMLInputElement).checked;
  
  if (!name || !url) {
    showToast('Nome e URL são obrigatórios', 'error');
    return;
  }
  
  if (id) {
    // Update
    const { data, error } = await supabase.from('tabs').update({
      name, url, keyboard_shortcut, zoom, icon, open_as_window
    }).eq('id', id);
    if (error) {
      showToast('Erro ao atualizar aba', 'error');
      return;
    }
    const index = tabs.findIndex(t => t.id === id);
    if (index !== -1) {
      tabs[index] = { ...tabs[index], name, url, keyboard_shortcut, zoom, icon, open_as_window };
    }
    showToast('Aba atualizada com sucesso');
  } else {
    // Create
    const groupTabs = tabs.filter(t => t.group_id === groupId);
    const { data, error } = await supabase.from('tabs').insert({
      name, url, keyboard_shortcut, zoom, icon, open_as_window,
      group_id: groupId,
      position: groupTabs.length,
      user_id: currentUser!.id,
    });
    if (error) {
      showToast('Erro ao criar aba', 'error');
      return;
    }
    if (data) tabs.push(data);
    showToast('Aba criada com sucesso');
  }
  
  closeModal('tabModal');
  await registerKeyboardShortcuts();
  renderGroups();
  renderHome();
  updateStats();
}

// ============ SHORTCUTS ============
function renderShortcuts() {
  const container = document.getElementById('shortcutsList');
  const emptyState = document.getElementById('shortcutsEmptyState');
  if (!container || !emptyState) return;
  
  if (textShortcuts.length === 0) {
    container.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  container.style.display = 'grid';
  emptyState.style.display = 'none';
  
  container.innerHTML = textShortcuts.map(s => `
    <div class="shortcut-card">
      <div class="shortcut-header">
        <div style="display: flex; align-items: center; gap: 10px;">
          <span class="shortcut-command">${s.command}</span>
          ${s.category ? `<span class="badge badge-primary">${s.category}</span>` : ''}
        </div>
        <div class="card-actions">
          <button class="btn btn-icon btn-ghost edit-shortcut-btn" data-shortcut-id="${s.id}">✏️</button>
          <button class="btn btn-icon btn-ghost delete-shortcut-btn" data-shortcut-id="${s.id}" style="color: var(--error);">🗑️</button>
        </div>
      </div>
      <p class="shortcut-text">${s.expanded_text}</p>
      ${s.description ? `<p style="font-size: 12px; color: var(--text-muted); margin-top: 8px;">${s.description}</p>` : ''}
    </div>
  `).join('');
  
  container.querySelectorAll('.edit-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const shortcutId = btn.getAttribute('data-shortcut-id')!;
      const shortcut = textShortcuts.find(s => s.id === shortcutId);
      if (shortcut) openShortcutModal(shortcut);
    });
  });
  
  container.querySelectorAll('.delete-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const shortcutId = btn.getAttribute('data-shortcut-id')!;
      const shortcut = textShortcuts.find(s => s.id === shortcutId);
      showConfirm(
        'Excluir Atalho',
        `Tem certeza que deseja excluir o atalho "${shortcut?.command}"?`,
        async () => {
          const { error } = await supabase.from('text_shortcuts').delete().eq('id', shortcutId);
          closeModal('confirmModal');
          if (!error) {
            textShortcuts = textShortcuts.filter(s => s.id !== shortcutId);
            renderShortcuts();
            updateStats();
            showToast('Atalho excluído com sucesso');
          } else {
            showToast('Erro ao excluir atalho', 'error');
          }
        }
      );
    });
  });
}

function openShortcutModal(shortcut: TextShortcut | null = null) {
  document.getElementById('shortcutModalTitle')!.textContent = shortcut ? 'Editar Atalho' : 'Novo Atalho';
  (document.getElementById('shortcutId') as HTMLInputElement).value = shortcut?.id || '';
  (document.getElementById('shortcutCommand') as HTMLInputElement).value = shortcut?.command || '';
  (document.getElementById('shortcutText') as HTMLTextAreaElement).value = shortcut?.expanded_text || '';
  (document.getElementById('shortcutCategory') as HTMLInputElement).value = shortcut?.category || '';
  (document.getElementById('shortcutDescription') as HTMLInputElement).value = shortcut?.description || '';
  openModal('shortcutModal');
}

async function saveShortcut() {
  const id = (document.getElementById('shortcutId') as HTMLInputElement).value;
  const command = (document.getElementById('shortcutCommand') as HTMLInputElement).value;
  const expanded_text = (document.getElementById('shortcutText') as HTMLTextAreaElement).value;
  const category = (document.getElementById('shortcutCategory') as HTMLInputElement).value || null;
  const description = (document.getElementById('shortcutDescription') as HTMLInputElement).value || null;
  
  if (!command || !expanded_text) {
    showToast('Comando e texto são obrigatórios', 'error');
    return;
  }
  
  if (id) {
    // Update
    const { data, error } = await supabase.from('text_shortcuts').update({
      command, expanded_text, category, description
    }).eq('id', id);
    if (error) {
      showToast('Erro ao atualizar atalho', 'error');
      return;
    }
    const index = textShortcuts.findIndex(s => s.id === id);
    if (index !== -1) {
      textShortcuts[index] = { ...textShortcuts[index], command, expanded_text, category, description };
    }
    showToast('Atalho atualizado com sucesso');
  } else {
    // Create
    const { data, error } = await supabase.from('text_shortcuts').insert({
      command, expanded_text, category, description,
      user_id: currentUser!.id,
    });
    if (error) {
      showToast('Erro ao criar atalho', 'error');
      return;
    }
    if (data) textShortcuts.push(data);
    showToast('Atalho criado com sucesso');
  }
  
  closeModal('shortcutModal');
  renderShortcuts();
  updateStats();
}

// ============ EVENT SETUP ============
function setupEventListeners() {
  // Auth tabs
  document.querySelectorAll('.auth-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.auth-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const tabName = tab.getAttribute('data-tab');
      document.getElementById('loginForm')!.style.display = tabName === 'login' ? 'flex' : 'none';
      document.getElementById('signupForm')!.style.display = tabName === 'signup' ? 'flex' : 'none';
      hideError();
    });
  });
  
  // Login form
  document.getElementById('loginForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = (document.getElementById('loginEmail') as HTMLInputElement).value;
    const password = (document.getElementById('loginPassword') as HTMLInputElement).value;
    await handleLogin(email, password);
  });
  
  // Signup form
  document.getElementById('signupForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = (document.getElementById('signupName') as HTMLInputElement).value;
    const email = (document.getElementById('signupEmail') as HTMLInputElement).value;
    const password = (document.getElementById('signupPassword') as HTMLInputElement).value;
    await handleSignup(name, email, password);
  });
  
  // Logout
  document.getElementById('logoutBtn')?.addEventListener('click', handleLogout);
  
  // Navigation
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const screen = item.getAttribute('data-screen');
      if (screen) navigateTo(screen);
    });
  });
  
  // Add group button
  document.getElementById('addGroupBtn')?.addEventListener('click', () => openGroupModal());
  
  // Add shortcut button
  document.getElementById('addShortcutBtn')?.addEventListener('click', () => openShortcutModal());
  
  // Group form
  document.getElementById('groupForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveGroup();
  });
  
  // Tab form
  document.getElementById('tabForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveTab();
  });
  
  // Shortcut form
  document.getElementById('shortcutForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveShortcut();
  });
  
  // Confirm button
  document.getElementById('confirmBtn')?.addEventListener('click', () => {
    if (confirmCallback) confirmCallback();
  });
  
  // Icon pickers
  document.querySelectorAll('.icon-picker .icon-option').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const picker = btn.closest('.icon-picker')!;
      picker.querySelectorAll('.icon-option').forEach(b => b.classList.remove('selected'));
      btn.classList.add('selected');
      const icon = btn.getAttribute('data-icon')!;
      const inputId = picker.id === 'groupIconPicker' ? 'groupIcon' : 'tabIcon';
      (document.getElementById(inputId) as HTMLInputElement).value = icon;
    });
  });
  
  // Color pickers
  document.querySelectorAll('.color-picker .color-option').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const picker = btn.closest('.color-picker')!;
      picker.querySelectorAll('.color-option').forEach(b => b.classList.remove('selected'));
      btn.classList.add('selected');
      const color = btn.getAttribute('data-color')!;
      (document.getElementById('groupColor') as HTMLInputElement).value = color;
    });
  });
  
  // Close modals on overlay click
  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        overlay.classList.remove('active');
      }
    });
  });
  
  // Keyboard shortcut triggered
  window.electronAPI.onShortcutTriggered((tabId) => {
    const tab = tabs.find(t => t.id === tabId);
    if (tab) openTab(tab);
  });
}

// ============ INIT ============
async function init() {
  await new Promise<void>((resolve) => {
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
  
  setupEventListeners();
  await initAuth();
}

document.addEventListener('DOMContentLoaded', init);

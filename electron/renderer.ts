// @ts-nocheck
// Renderer script - GerenciaZap Electron com Supabase

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

// ============ SUPABASE CLIENT (Simplified) ============
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
        headers: {
          'apikey': this.key,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const data = await response.json();

      if (!response.ok) {
        return { data: { session: null, user: null }, error: data };
      }

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
        headers: {
          'apikey': this.key,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          password,
          data: { full_name: name },
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        return { data: { session: null, user: null }, error: data };
      }

      // Auto-confirm is enabled, so we should get a session
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
        headers: {
          'apikey': this.key,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });

      const data = await response.json();

      if (!response.ok) {
        return { data: { session: null }, error: data };
      }

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

  // Database operations
  async from(table: string) {
    const client = this;
    return {
      async select(columns = '*'): Promise<{ data: any[]; error: any }> {
        try {
          const response = await fetch(`${client.url}/rest/v1/${table}?select=${columns}`, {
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

      async update(values: any): Promise<{ eq: (column: string, value: string) => Promise<{ data: any; error: any }> }> {
        return {
          async eq(column: string, value: string) {
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

      async delete(): Promise<{ eq: (column: string, value: string) => Promise<{ error: any }> }> {
        return {
          async eq(column: string, value: string) {
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
  toast.innerHTML = `
    <span>${type === 'success' ? '✅' : '❌'}</span>
    <span>${message}</span>
  `;
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
  if (errorEl) {
    errorEl.classList.remove('visible');
  }
}

function setLoading(loading: boolean) {
  const loadingScreen = document.getElementById('loadingScreen');
  if (loadingScreen) {
    loadingScreen.style.display = loading ? 'flex' : 'none';
  }
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
  
  if (avatarEl) avatarEl.textContent = initial;
  if (nameEl) nameEl.textContent = name;
  if (emailEl) emailEl.textContent = email;
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

// Make globally accessible
(window as any).navigateTo = navigateTo;

// ============ AUTH ============
async function initAuth() {
  setLoading(true);
  
  try {
    // Check for persisted session
    const savedSession = await window.electronAPI.getSession();
    
    if (savedSession) {
      // Try to refresh the session
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
    const message = error.error_description || error.message || error.msg || 'Erro ao fazer login';
    showError(message);
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
    const message = error.error_description || error.message || error.msg || 'Erro ao criar conta';
    showError(message);
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
    // Email confirmation may be required
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

// ============ DATA LOADING ============
async function loadData() {
  try {
    // Load tab groups
    const groupsTable = await supabase.from('tab_groups');
    const { data: groupsData, error: groupsError } = await groupsTable.select('*');
    if (!groupsError) {
      tabGroups = groupsData.sort((a: TabGroup, b: TabGroup) => a.position - b.position);
    }
    
    // Load tabs
    const tabsTable = await supabase.from('tabs');
    const { data: tabsData, error: tabsError } = await tabsTable.select('*');
    if (!tabsError) {
      tabs = tabsData.sort((a: Tab, b: Tab) => a.position - b.position);
    }
    
    // Load text shortcuts
    const shortcutsTable = await supabase.from('text_shortcuts');
    const { data: shortcutsData, error: shortcutsError } = await shortcutsTable.select('*');
    if (!shortcutsError) {
      textShortcuts = shortcutsData;
    }
    
    // Register keyboard shortcuts
    await registerKeyboardShortcuts();
    
    // Update stats and render
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

// ============ HOME SCREEN ============
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
      <div class="group-header">
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
            ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ''}
          </div>
        `).join('')}
      </div>
    `;
    
    // Add click handlers for tabs
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

// ============ GROUPS SCREEN ============
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
      <div class="group-header">
        <div class="group-info">
          <span class="group-icon">${group.icon || '📁'}</span>
          <span class="group-name">${group.name}</span>
        </div>
        <div class="card-actions">
          <button class="btn btn-sm btn-secondary add-tab-btn" data-group-id="${group.id}">+ Aba</button>
          <button class="btn btn-sm btn-secondary edit-group-btn" data-group-id="${group.id}">✏️</button>
          <button class="btn btn-sm btn-danger delete-group-btn" data-group-id="${group.id}">🗑️</button>
        </div>
      </div>
      <div class="group-tabs">
        ${groupTabs.length === 0 ? '<p style="padding: 16px; color: var(--text-muted); text-align: center; font-size: 13px;">Nenhuma aba neste grupo</p>' : ''}
        ${groupTabs.map(tab => `
          <div class="tab-item">
            <span class="tab-icon">${tab.icon || '🔗'}</span>
            <div class="tab-info">
              <div class="tab-name">${tab.name}</div>
              <div class="tab-url">${tab.url}</div>
            </div>
            ${tab.keyboard_shortcut ? `<span class="tab-shortcut">${tab.keyboard_shortcut}</span>` : ''}
            <div class="card-actions">
              <button class="btn btn-sm btn-secondary edit-tab-btn" data-tab-id="${tab.id}">✏️</button>
              <button class="btn btn-sm btn-danger delete-tab-btn" data-tab-id="${tab.id}">🗑️</button>
            </div>
          </div>
        `).join('')}
      </div>
    `;
    
    container.appendChild(card);
  });
  
  // Add event listeners
  container.querySelectorAll('.add-tab-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      showToast('Criação de abas em breve...', 'success');
    });
  });
  
  container.querySelectorAll('.edit-group-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      showToast('Edição de grupo em breve...', 'success');
    });
  });
  
  container.querySelectorAll('.delete-group-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const groupId = btn.getAttribute('data-group-id');
      if (confirm('Tem certeza que deseja excluir este grupo?')) {
        const table = await supabase.from('tab_groups');
        const deleteOp = await table.delete();
        const { error } = await deleteOp.eq('id', groupId);
        if (!error) {
          tabGroups = tabGroups.filter(g => g.id !== groupId);
          renderGroups();
          updateStats();
          showToast('Grupo excluído');
        } else {
          showToast('Erro ao excluir grupo', 'error');
        }
      }
    });
  });
  
  container.querySelectorAll('.edit-tab-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      showToast('Edição de aba em breve...', 'success');
    });
  });
  
  container.querySelectorAll('.delete-tab-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const tabId = btn.getAttribute('data-tab-id');
      if (confirm('Tem certeza que deseja excluir esta aba?')) {
        const table = await supabase.from('tabs');
        const deleteOp = await table.delete();
        const { error } = await deleteOp.eq('id', tabId);
        if (!error) {
          tabs = tabs.filter(t => t.id !== tabId);
          renderGroups();
          updateStats();
          await registerKeyboardShortcuts();
          showToast('Aba excluída');
        } else {
          showToast('Erro ao excluir aba', 'error');
        }
      }
    });
  });
}

// ============ SHORTCUTS SCREEN ============
function renderShortcuts() {
  const container = document.getElementById('shortcutsList');
  const emptyState = document.getElementById('shortcutsEmptyState');
  if (!container || !emptyState) return;
  
  if (textShortcuts.length === 0) {
    container.style.display = 'none';
    emptyState.style.display = 'flex';
    return;
  }
  
  container.style.display = 'block';
  emptyState.style.display = 'none';
  
  container.innerHTML = textShortcuts.map(s => `
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <span style="font-family: monospace; background: var(--background); padding: 4px 8px; border-radius: 4px; color: var(--primary);">${s.command}</span>
          ${s.category ? `<span class="badge badge-primary">${s.category}</span>` : ''}
        </div>
        <div class="card-actions">
          <button class="btn btn-sm btn-secondary edit-shortcut-btn" data-shortcut-id="${s.id}">✏️</button>
          <button class="btn btn-sm btn-danger delete-shortcut-btn" data-shortcut-id="${s.id}">🗑️</button>
        </div>
      </div>
      <p style="color: var(--text-muted); font-size: 14px; white-space: pre-wrap;">${s.expanded_text}</p>
    </div>
  `).join('');
  
  container.querySelectorAll('.edit-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      showToast('Edição de atalho em breve...', 'success');
    });
  });
  
  container.querySelectorAll('.delete-shortcut-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const shortcutId = btn.getAttribute('data-shortcut-id');
      if (confirm('Tem certeza que deseja excluir este atalho?')) {
        const table = await supabase.from('text_shortcuts');
        const deleteOp = await table.delete();
        const { error } = await deleteOp.eq('id', shortcutId);
        if (!error) {
          textShortcuts = textShortcuts.filter(s => s.id !== shortcutId);
          renderShortcuts();
          updateStats();
          showToast('Atalho excluído');
        } else {
          showToast('Erro ao excluir atalho', 'error');
        }
      }
    });
  });
}

// ============ EVENT SETUP ============
function setupEventListeners() {
  // Auth tabs
  document.querySelectorAll('.auth-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const tabName = tab.getAttribute('data-tab');
      document.querySelectorAll('.auth-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      
      if (tabName === 'login') {
        document.getElementById('loginForm')!.style.display = 'flex';
        document.getElementById('signupForm')!.style.display = 'none';
      } else {
        document.getElementById('loginForm')!.style.display = 'none';
        document.getElementById('signupForm')!.style.display = 'flex';
      }
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
  document.getElementById('addGroupBtn')?.addEventListener('click', () => {
    showToast('Criação de grupo em breve...', 'success');
  });
  
  // Add shortcut button
  document.getElementById('addShortcutBtn')?.addEventListener('click', () => {
    showToast('Criação de atalho em breve...', 'success');
  });
  
  // Keyboard shortcut triggered
  window.electronAPI.onShortcutTriggered((tabId) => {
    const tab = tabs.find(t => t.id === tabId);
    if (tab) openTab(tab);
  });
}

// ============ INIT ============
async function init() {
  // Wait for electronAPI to be available
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

// Start the app
document.addEventListener('DOMContentLoaded', init);

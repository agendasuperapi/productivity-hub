# Integração do Electron com a API de Configuração

Este documento explica como integrar o navegador Electron com a API de configuração do usuário.

## Visão Geral

O fluxo de integração funciona assim:

1. **Usuário faz login** no Electron usando Supabase Auth
2. **Electron obtém o token JWT** do usuário autenticado
3. **Electron chama a Edge Function** `get-user-config` com o token
4. **API retorna todas as configurações** (grupos, abas, atalhos, layouts)
5. **Electron renderiza** as abas/webviews conforme as configurações

---

## Configuração Inicial

### 1. Instalar Dependências

```bash
npm install @supabase/supabase-js
```

### 2. Configurar Supabase Client

```typescript
// src/supabase.ts
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplZ2pydmdscmpuaHVreHFreG9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MTA4NTAsImV4cCI6MjA4MjA4Njg1MH0.mhrSxMboDPKan4ez71_f5qjwUhxGMCq61GXvuTo93MU';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: localStorage, // ou sessionStorage
    persistSession: true,
    autoRefreshToken: true,
  }
});
```

---

## Autenticação

### Login com Email/Senha

```typescript
// src/auth.ts
import { supabase } from './supabase';

export async function signIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    throw new Error(`Erro no login: ${error.message}`);
  }

  return data;
}

export async function signOut() {
  await supabase.auth.signOut();
}

export async function getSession() {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}
```

---

## Buscar Configurações do Usuário

### Usando a Edge Function

```typescript
// src/config.ts
import { supabase } from './supabase';

const API_URL = 'https://jegjrvglrjnhukxqkxoj.supabase.co/functions/v1/get-user-config';

export interface Tab {
  id: string;
  name: string;
  url: string;
  icon: string | null;
  color: string | null;
  zoom: number | null;
  position: number;
  open_as_window: boolean | null;
  keyboard_shortcut: string | null;
  group_id: string;
}

export interface TabGroup {
  id: string;
  name: string;
  icon: string | null;
  color: string | null;
  position: number;
  tabs: Tab[];
}

export interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description: string | null;
  category: string | null;
}

export interface SplitLayout {
  id: string;
  name: string;
  layout_type: string;
  panels: any;
  is_favorite: boolean | null;
}

export interface UserConfig {
  user_id: string;
  email: string;
  fetched_at: string;
  tab_groups: TabGroup[];
  text_shortcuts: TextShortcut[];
  split_layouts: SplitLayout[];
  stats: {
    total_groups: number;
    total_tabs: number;
    total_shortcuts: number;
    total_layouts: number;
  };
}

export async function fetchUserConfig(): Promise<UserConfig> {
  // Obter sessão atual
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session?.access_token) {
    throw new Error('Usuário não autenticado');
  }

  // Chamar a Edge Function
  const response = await fetch(API_URL, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Erro ao buscar configurações');
  }

  return response.json();
}
```

### Alternativa: Usando supabase.functions.invoke

```typescript
export async function fetchUserConfigAlt(): Promise<UserConfig> {
  const { data, error } = await supabase.functions.invoke('get-user-config');

  if (error) {
    throw new Error(`Erro: ${error.message}`);
  }

  return data;
}
```

---

## Exemplo Completo: Main Process do Electron

```typescript
// main.ts (Electron Main Process)
import { app, BrowserWindow, ipcMain } from 'electron';
import { supabase } from './supabase';
import { fetchUserConfig, UserConfig } from './config';

let mainWindow: BrowserWindow | null = null;
let userConfig: UserConfig | null = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  mainWindow.loadFile('index.html');
}

// IPC: Login
ipcMain.handle('auth:login', async (_, email: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;
  
  // Após login, buscar configurações
  userConfig = await fetchUserConfig();
  return { user: data.user, config: userConfig };
});

// IPC: Buscar configurações
ipcMain.handle('config:fetch', async () => {
  userConfig = await fetchUserConfig();
  return userConfig;
});

// IPC: Obter configurações em cache
ipcMain.handle('config:get', () => {
  return userConfig;
});

app.whenReady().then(createWindow);
```

---

## Exemplo: Preload Script

```typescript
// preload.ts
import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('api', {
  // Autenticação
  login: (email: string, password: string) => 
    ipcRenderer.invoke('auth:login', email, password),
  
  logout: () => 
    ipcRenderer.invoke('auth:logout'),

  // Configurações
  fetchConfig: () => 
    ipcRenderer.invoke('config:fetch'),
  
  getConfig: () => 
    ipcRenderer.invoke('config:get'),

  // Eventos
  onConfigUpdate: (callback: (config: any) => void) => {
    ipcRenderer.on('config:updated', (_, config) => callback(config));
  },
});
```

---

## Exemplo: Renderer (React)

```tsx
// App.tsx
import React, { useEffect, useState } from 'react';

interface Tab {
  id: string;
  name: string;
  url: string;
  icon: string | null;
  color: string | null;
}

interface TabGroup {
  id: string;
  name: string;
  color: string | null;
  tabs: Tab[];
}

function App() {
  const [groups, setGroups] = useState<TabGroup[]>([]);
  const [activeTab, setActiveTab] = useState<Tab | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadConfig();

    // Escutar atualizações em tempo real
    window.api.onConfigUpdate((config) => {
      setGroups(config.tab_groups);
    });
  }, []);

  async function loadConfig() {
    try {
      const config = await window.api.fetchConfig();
      setGroups(config.tab_groups);
      
      // Selecionar primeira aba por padrão
      if (config.tab_groups[0]?.tabs[0]) {
        setActiveTab(config.tab_groups[0].tabs[0]);
      }
    } catch (error) {
      console.error('Erro ao carregar configurações:', error);
    } finally {
      setLoading(false);
    }
  }

  if (loading) {
    return <div className="loading">Carregando...</div>;
  }

  return (
    <div className="app">
      {/* Sidebar com grupos e abas */}
      <aside className="sidebar">
        {groups.map((group) => (
          <div key={group.id} className="group">
            <h3 style={{ color: group.color || '#fff' }}>
              {group.name}
            </h3>
            <ul>
              {group.tabs.map((tab) => (
                <li 
                  key={tab.id}
                  className={activeTab?.id === tab.id ? 'active' : ''}
                  onClick={() => setActiveTab(tab)}
                >
                  {tab.name}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </aside>

      {/* Área principal com webview */}
      <main className="content">
        {activeTab && (
          <webview
            src={activeTab.url}
            style={{ width: '100%', height: '100%' }}
          />
        )}
      </main>
    </div>
  );
}

export default App;
```

---

## Atualizações em Tempo Real (Opcional)

Para receber atualizações instantâneas quando o usuário modificar configurações no painel web:

```typescript
// realtime.ts
import { supabase } from './supabase';
import { fetchUserConfig } from './config';

export function subscribeToConfigChanges(onUpdate: (config: any) => void) {
  const channel = supabase
    .channel('config-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'tab_groups',
      },
      async () => {
        const config = await fetchUserConfig();
        onUpdate(config);
      }
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'tabs',
      },
      async () => {
        const config = await fetchUserConfig();
        onUpdate(config);
      }
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'text_shortcuts',
      },
      async () => {
        const config = await fetchUserConfig();
        onUpdate(config);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
```

---

## Estrutura do JSON Retornado

```json
{
  "user_id": "d82f1fa9-7493-42c9-b934-056fb012dd48",
  "email": "usuario@email.com",
  "fetched_at": "2024-12-23T20:00:00.000Z",
  "tab_groups": [
    {
      "id": "21a7638c-4c8e-4a2d-8505-c080fbd4fa34",
      "name": "Atendimento",
      "icon": "folder",
      "color": "#6366f1",
      "position": 0,
      "tabs": [
        {
          "id": "21dba257-1f8a-4977-976a-8b17c4a5c7f1",
          "name": "WhatsApp",
          "url": "https://web.whatsapp.com/",
          "icon": "message-circle",
          "color": "#22d3ee",
          "zoom": 100,
          "position": 0,
          "open_as_window": false,
          "keyboard_shortcut": null
        }
      ]
    }
  ],
  "text_shortcuts": [],
  "split_layouts": [],
  "stats": {
    "total_groups": 1,
    "total_tabs": 1,
    "total_shortcuts": 0,
    "total_layouts": 0
  }
}
```

---

## Dicas de Segurança

1. **Nunca exponha a service_role key** no código do Electron
2. **Use apenas a anon key** que já tem RLS configurado
3. **Armazene tokens de forma segura** (electron-store ou similar)
4. **Valide sempre a sessão** antes de fazer requisições

---

## Suporte

Para dúvidas ou problemas, verifique:
- Console do Electron (DevTools)
- Logs da Edge Function no painel do Lovable Cloud
- Status da autenticação do usuário

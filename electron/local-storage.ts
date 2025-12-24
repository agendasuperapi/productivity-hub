import Store from 'electron-store';

// Interfaces
export interface Tab {
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
  layout_type?: string;
  urls?: { url: string; position: number }[];
}

export interface TabGroup {
  id: string;
  name: string;
  icon?: string;
  color?: string;
  position: number;
}

export interface TextShortcut {
  id: string;
  command: string;
  expanded_text: string;
  description?: string;
  category?: string;
}

export interface LocalConfig {
  tab_groups: TabGroup[];
  tabs: Tab[];
  text_shortcuts: TextShortcut[];
}

// Schema para validação
const schema = {
  tab_groups: {
    type: 'array' as const,
    default: [] as TabGroup[],
  },
  tabs: {
    type: 'array' as const,
    default: [] as Tab[],
  },
  text_shortcuts: {
    type: 'array' as const,
    default: [] as TextShortcut[],
  },
};

// Criar store
const store = new Store<LocalConfig>({
  name: 'productivity-hub-config',
  schema,
  defaults: {
    tab_groups: [],
    tabs: [],
    text_shortcuts: [],
  },
});

// Gerar UUID simples
function generateId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// ============ CONFIG ============

export function getConfig(): LocalConfig {
  return {
    tab_groups: store.get('tab_groups', []),
    tabs: store.get('tabs', []),
    text_shortcuts: store.get('text_shortcuts', []),
  };
}

export function saveConfig(config: LocalConfig): void {
  store.set('tab_groups', config.tab_groups);
  store.set('tabs', config.tabs);
  store.set('text_shortcuts', config.text_shortcuts);
}

// ============ TAB GROUPS ============

export function getTabGroups(): TabGroup[] {
  return store.get('tab_groups', []);
}

export function addTabGroup(group: Omit<TabGroup, 'id'>): TabGroup {
  const groups = getTabGroups();
  const newGroup: TabGroup = {
    ...group,
    id: generateId(),
  };
  groups.push(newGroup);
  store.set('tab_groups', groups);
  return newGroup;
}

export function updateTabGroup(id: string, data: Partial<TabGroup>): TabGroup | null {
  const groups = getTabGroups();
  const index = groups.findIndex((g) => g.id === id);
  if (index === -1) return null;
  
  groups[index] = { ...groups[index], ...data };
  store.set('tab_groups', groups);
  return groups[index];
}

export function deleteTabGroup(id: string): boolean {
  const groups = getTabGroups();
  const filtered = groups.filter((g) => g.id !== id);
  if (filtered.length === groups.length) return false;
  
  store.set('tab_groups', filtered);
  
  // Também deletar tabs do grupo
  const tabs = getTabs();
  const filteredTabs = tabs.filter((t) => t.group_id !== id);
  store.set('tabs', filteredTabs);
  
  return true;
}

// ============ TABS ============

export function getTabs(): Tab[] {
  return store.get('tabs', []);
}

export function addTab(tab: Omit<Tab, 'id'>): Tab {
  const tabs = getTabs();
  const newTab: Tab = {
    ...tab,
    id: generateId(),
    open_as_window: tab.open_as_window ?? true,
  };
  tabs.push(newTab);
  store.set('tabs', tabs);
  return newTab;
}

export function updateTab(id: string, data: Partial<Tab>): Tab | null {
  const tabs = getTabs();
  const index = tabs.findIndex((t) => t.id === id);
  if (index === -1) return null;
  
  tabs[index] = { ...tabs[index], ...data };
  store.set('tabs', tabs);
  return tabs[index];
}

export function deleteTab(id: string): boolean {
  const tabs = getTabs();
  const filtered = tabs.filter((t) => t.id !== id);
  if (filtered.length === tabs.length) return false;
  
  store.set('tabs', filtered);
  return true;
}

// ============ TEXT SHORTCUTS ============

export function getTextShortcuts(): TextShortcut[] {
  return store.get('text_shortcuts', []);
}

export function addTextShortcut(shortcut: Omit<TextShortcut, 'id'>): TextShortcut {
  const shortcuts = getTextShortcuts();
  const newShortcut: TextShortcut = {
    ...shortcut,
    id: generateId(),
  };
  shortcuts.push(newShortcut);
  store.set('text_shortcuts', shortcuts);
  return newShortcut;
}

export function updateTextShortcut(id: string, data: Partial<TextShortcut>): TextShortcut | null {
  const shortcuts = getTextShortcuts();
  const index = shortcuts.findIndex((s) => s.id === id);
  if (index === -1) return null;
  
  shortcuts[index] = { ...shortcuts[index], ...data };
  store.set('text_shortcuts', shortcuts);
  return shortcuts[index];
}

export function deleteTextShortcut(id: string): boolean {
  const shortcuts = getTextShortcuts();
  const filtered = shortcuts.filter((s) => s.id !== id);
  if (filtered.length === shortcuts.length) return false;
  
  store.set('text_shortcuts', filtered);
  return true;
}

export function importTextShortcuts(shortcuts: Omit<TextShortcut, 'id'>[]): TextShortcut[] {
  const newShortcuts = shortcuts.map((s) => ({
    ...s,
    id: generateId(),
  }));
  const current = getTextShortcuts();
  store.set('text_shortcuts', [...current, ...newShortcuts]);
  return newShortcuts;
}

export function exportTextShortcuts(): TextShortcut[] {
  return getTextShortcuts();
}

// ============ CLEAR ============

export function clearAll(): void {
  store.clear();
}

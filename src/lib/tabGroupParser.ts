export interface ParsedTab {
  name: string;
  url: string;
  urls_count: number;
  keyboard_shortcut: string | null;
  position: number;
}

export interface ParsedGroup {
  name: string;
  icon: string | null;
  position: number;
  tabs: ParsedTab[];
}

export function parseTabGroupsTxt(content: string): ParsedGroup[] {
  const groups: ParsedGroup[] = [];
  const lines = content.split('\n');
  
  let currentGroup: ParsedGroup | null = null;
  let currentTab: Partial<ParsedTab> | null = null;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    
    // Detectar início de grupo: "GRUPO: Nome (Ordem: N)"
    const groupMatch = trimmed.match(/^GRUPO:\s+(.+?)\s+\(Ordem:\s*(\d+)\)/);
    if (groupMatch) {
      // Salvar aba anterior se existir
      if (currentTab && currentTab.name && currentTab.url && currentGroup) {
        currentGroup.tabs.push(currentTab as ParsedTab);
      }
      
      // Salvar grupo anterior se existir
      if (currentGroup) {
        groups.push(currentGroup);
      }
      
      currentGroup = {
        name: groupMatch[1].trim(),
        icon: null,
        position: parseInt(groupMatch[2], 10),
        tabs: []
      };
      currentTab = null;
      continue;
    }
    
    // Capturar ícone do grupo
    const iconMatch = trimmed.match(/^Icone:\s*(.+)/i);
    if (iconMatch && currentGroup) {
      currentGroup.icon = iconMatch[1].trim();
      continue;
    }
    
    // Detectar início de aba: "N. Nome da Aba"
    const tabMatch = trimmed.match(/^\d+\.\s+(.+)$/);
    if (tabMatch && currentGroup) {
      // Salvar aba anterior se existir
      if (currentTab && currentTab.name && currentTab.url) {
        currentGroup.tabs.push(currentTab as ParsedTab);
      }
      
      currentTab = {
        name: tabMatch[1].trim(),
        url: '',
        urls_count: 1,
        keyboard_shortcut: null,
        position: 0
      };
      continue;
    }
    
    // Capturar URL principal
    const urlMatch = trimmed.match(/^URL:\s*(.+)/i);
    if (urlMatch && currentTab) {
      currentTab.url = urlMatch[1].trim();
      continue;
    }
    
    // Capturar URLs múltiplas
    const urlsMultiMatch = trimmed.match(/^URLs multiplas:\s*(\d+)/i);
    if (urlsMultiMatch && currentTab) {
      currentTab.urls_count = parseInt(urlsMultiMatch[1], 10);
      continue;
    }
    
    // Capturar atalho
    const shortcutMatch = trimmed.match(/^Atalho:\s*(.+)/i);
    if (shortcutMatch && currentTab) {
      currentTab.keyboard_shortcut = shortcutMatch[1].trim();
      continue;
    }
    
    // Capturar ordem/posição
    const orderMatch = trimmed.match(/^Ordem:\s*(\d+)/i);
    if (orderMatch && currentTab) {
      currentTab.position = parseInt(orderMatch[1], 10);
      continue;
    }
  }
  
  // Salvar última aba e grupo
  if (currentTab && currentTab.name && currentTab.url && currentGroup) {
    currentGroup.tabs.push(currentTab as ParsedTab);
  }
  if (currentGroup) {
    groups.push(currentGroup);
  }
  
  return groups;
}

export function getLayoutForUrlCount(count: number): string {
  switch (count) {
    case 1: return 'single';
    case 2: return '50-50';
    case 3: return '33-33-33';
    case 4: return '2x2';
    default: return 'single';
  }
}

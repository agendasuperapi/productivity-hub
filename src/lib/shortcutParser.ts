/**
 * Parser for importing shortcuts from TXT files
 * Expected format:
 * --------------------
 * N. Title
 *    Atalho: /command
 *    Mensagem: expanded text (can be multi-line)
 *    ID: numeric_id
 * --------------------
 */

export interface ParsedShortcut {
  command: string;
  description: string;
  expanded_text: string;
  category?: string;
}

export function parseShortcutsTxt(content: string): ParsedShortcut[] {
  const shortcuts: ParsedShortcut[] = [];
  const lines = content.split('\n');
  
  let currentShortcut: {
    title: string;
    command: string;
    message: string;
    isReadingMessage: boolean;
  } | null = null;
  
  const saveCurrentShortcut = () => {
    if (currentShortcut && currentShortcut.command && currentShortcut.message) {
      let command = currentShortcut.command.trim();
      if (!command.startsWith('/')) {
        command = '/' + command;
      }
      shortcuts.push({
        command,
        description: currentShortcut.title || command,
        expanded_text: currentShortcut.message.trim(),
        category: 'geral'
      });
    }
  };
  
  for (const line of lines) {
    const trimmedLine = line.trim();
    
    // Detect start of new shortcut: line starts with "N. Title" (e.g., "1. Obrigado ativação")
    // Title must start with a letter (not emoji like 2️⃣) to avoid false matches in message content
    const titleMatch = trimmedLine.match(/^(\d{1,4})\.\s+([A-Za-zÀ-ÿ].*)$/);
    if (titleMatch) {
      // Save previous shortcut if exists
      saveCurrentShortcut();
      
      // Start new shortcut
      currentShortcut = {
        title: titleMatch[2].trim(),
        command: '',
        message: '',
        isReadingMessage: false
      };
      continue;
    }
    
    if (!currentShortcut) continue;
    
    // Check for "Atalho:" line
    if (trimmedLine.toLowerCase().startsWith('atalho:')) {
      currentShortcut.command = trimmedLine.substring(7).trim();
      currentShortcut.isReadingMessage = false;
      continue;
    }
    
    // Check for "Mensagem:" line - start reading message
    if (trimmedLine.toLowerCase().startsWith('mensagem:')) {
      currentShortcut.isReadingMessage = true;
      currentShortcut.message = trimmedLine.substring(9).trim();
      continue;
    }
    
    // Check for "ID:" line - stop reading message
    if (trimmedLine.toLowerCase().startsWith('id:')) {
      currentShortcut.isReadingMessage = false;
      continue;
    }
    
    // If we're reading message, append lines (preserve empty lines in message)
    if (currentShortcut.isReadingMessage) {
      if (currentShortcut.message) {
        currentShortcut.message += '\n' + line.trim();
      } else {
        currentShortcut.message = line.trim();
      }
    }
  }
  
  // Don't forget to save the last shortcut
  saveCurrentShortcut();
  
  return shortcuts;
}

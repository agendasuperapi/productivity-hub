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
  
  // Split by separator lines (dashes)
  const blocks = content.split(/^-{10,}$/m).filter(block => block.trim());
  
  for (const block of blocks) {
    const lines = block.trim().split('\n');
    
    let title = '';
    let command = '';
    let message = '';
    let isReadingMessage = false;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmedLine = line.trim();
      
      // Skip empty lines at the start
      if (!title && !trimmedLine) continue;
      
      // First non-empty line is the title (e.g., "1. Obrigado ativação")
      if (!title && trimmedLine) {
        // Remove the number prefix (e.g., "1. " or "10. ")
        title = trimmedLine.replace(/^\d+\.\s*/, '').trim();
        continue;
      }
      
      // Check for "Atalho:" line
      if (trimmedLine.toLowerCase().startsWith('atalho:')) {
        command = trimmedLine.substring(7).trim();
        // Ensure command starts with /
        if (!command.startsWith('/')) {
          command = '/' + command;
        }
        continue;
      }
      
      // Check for "Mensagem:" line - start reading message
      if (trimmedLine.toLowerCase().startsWith('mensagem:')) {
        isReadingMessage = true;
        message = trimmedLine.substring(9).trim();
        continue;
      }
      
      // Check for "ID:" line - stop reading message
      if (trimmedLine.toLowerCase().startsWith('id:')) {
        isReadingMessage = false;
        continue;
      }
      
      // If we're reading message, append lines
      if (isReadingMessage) {
        // Preserve the original line (with leading spaces trimmed)
        if (message) {
          message += '\n' + trimmedLine;
        } else {
          message = trimmedLine;
        }
      }
    }
    
    // Only add if we have at least command and message
    if (command && message) {
      shortcuts.push({
        command,
        description: title || command,
        expanded_text: message.trim(),
        category: 'geral'
      });
    }
  }
  
  return shortcuts;
}

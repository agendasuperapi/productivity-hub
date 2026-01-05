/**
 * Processa o texto expandido de um atalho, separando por <ENTER>
 * 
 * - Texto antes de <ENTER> será enviado automaticamente
 * - Texto após o último <ENTER> (se não terminar com <ENTER>) fica na caixa de texto
 * 
 * Exemplo:
 * "Linha 1<ENTER>Linha 2<ENTER>" → Envia "Linha 1" e "Linha 2", caixa vazia
 * "Linha 1<ENTER>Linha 2" → Envia "Linha 1", "Linha 2" fica na caixa
 */
export interface ProcessedShortcut {
  /** Mensagens para enviar automaticamente (simular Enter após cada) */
  messages: string[];
  /** Texto que deve permanecer na caixa de texto (sem enviar) */
  remainingText: string | null;
}

export function processExpandedText(text: string): ProcessedShortcut {
  // Normaliza quebras de linha e divide pelo marcador <ENTER>
  const normalizedText = text.replace(/\r\n/g, '\n');
  const parts = normalizedText.split('<ENTER>');
  
  // Verifica se o texto termina com <ENTER>
  const hasTrailingEnter = normalizedText.trimEnd().endsWith('<ENTER>');
  
  // Filtra partes vazias e faz trim
  const cleanParts = parts
    .map(p => p.trim())
    .filter(p => p.length > 0);
  
  if (cleanParts.length === 0) {
    return { messages: [], remainingText: null };
  }
  
  if (hasTrailingEnter) {
    // Todas as partes são mensagens para enviar
    return {
      messages: cleanParts,
      remainingText: null
    };
  } else {
    // Última parte fica na caixa de texto
    const remaining = cleanParts.pop() || null;
    return {
      messages: cleanParts,
      remainingText: remaining
    };
  }
}

/**
 * Aplica substituições de variáveis no texto
 * Ex: <NOME> → valor do keyword "NOME"
 */
export function applyKeywords(
  text: string, 
  keywords: Array<{ key: string; value: string }>
): string {
  let result = text;
  
  for (const keyword of keywords) {
    const pattern = new RegExp(`<${keyword.key}>`, 'gi');
    result = result.replace(pattern, keyword.value);
  }
  
  // Substituições automáticas
  const now = new Date();
  const hour = now.getHours();
  
  // <SAUDACAO> - Bom dia / Boa tarde / Boa noite
  let greeting = 'Olá';
  if (hour >= 5 && hour < 12) greeting = 'Bom dia';
  else if (hour >= 12 && hour < 18) greeting = 'Boa tarde';
  else greeting = 'Boa noite';
  
  result = result.replace(/<SAUDACAO>/gi, greeting);
  
  // <DATA> - Data atual
  result = result.replace(/<DATA>/gi, now.toLocaleDateString('pt-BR'));
  
  // <HORA> - Hora atual
  result = result.replace(/<HORA>/gi, now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }));
  
  return result;
}

export interface HighlightedPart {
  text: string;
  isHighlighted: boolean;
}

/**
 * Aplica substituições de variáveis no texto e retorna partes para destacar
 * Ex: <NOME> → { text: "João", isHighlighted: true }
 */
export function applyKeywordsWithHighlight(
  text: string, 
  keywords: Array<{ key: string; value: string }>
): HighlightedPart[] {
  // Monta mapa de substituições (keyword -> valor)
  const substitutions: Map<string, string> = new Map();
  
  for (const keyword of keywords) {
    substitutions.set(keyword.key.toLowerCase(), keyword.value);
  }
  
  // Substituições automáticas
  const now = new Date();
  const hour = now.getHours();
  
  let greeting = 'Olá';
  if (hour >= 5 && hour < 12) greeting = 'Bom dia';
  else if (hour >= 12 && hour < 18) greeting = 'Boa tarde';
  else greeting = 'Boa noite';
  
  substitutions.set('saudacao', greeting);
  substitutions.set('data', now.toLocaleDateString('pt-BR'));
  substitutions.set('hora', now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }));
  
  // Regex para encontrar todos os placeholders <...>
  const placeholderRegex = /<([^>]+)>/gi;
  const parts: HighlightedPart[] = [];
  let lastIndex = 0;
  let match;
  
  while ((match = placeholderRegex.exec(text)) !== null) {
    // Adiciona texto antes do placeholder
    if (match.index > lastIndex) {
      parts.push({
        text: text.slice(lastIndex, match.index),
        isHighlighted: false
      });
    }
    
    const keyName = match[1].toLowerCase();
    const replacement = substitutions.get(keyName);
    
    if (replacement !== undefined) {
      // Placeholder tem substituição - adiciona destacado
      parts.push({
        text: replacement,
        isHighlighted: true
      });
    } else {
      // Placeholder não reconhecido - mantém original
      parts.push({
        text: match[0],
        isHighlighted: false
      });
    }
    
    lastIndex = match.index + match[0].length;
  }
  
  // Adiciona texto restante após o último placeholder
  if (lastIndex < text.length) {
    parts.push({
      text: text.slice(lastIndex),
      isHighlighted: false
    });
  }
  
  return parts.length > 0 ? parts : [{ text, isHighlighted: false }];
}

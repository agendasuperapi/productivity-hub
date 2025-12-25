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

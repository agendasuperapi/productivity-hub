/**
 * Gera o script de injeção de atalhos de texto para webviews e janelas flutuantes
 */

interface TextShortcutData {
  command: string;
  expanded_text: string;
}

interface KeywordData {
  key: string;
  value: string;
}

export function generateShortcutScript(
  textShortcuts: TextShortcutData[],
  keywords: KeywordData[]
): string {
  const shortcutsMap: Record<string, string> = {};
  textShortcuts.forEach(s => {
    shortcutsMap[s.command] = s.expanded_text;
  });

  const keywordsMap: Record<string, string> = {};
  keywords.forEach(k => {
    keywordsMap[`<${k.key}>`] = k.value;
  });

  return `
    (function() {
      // Remover injeção anterior para atualizar
      if (window.__gerenciazapInjected) {
        console.log('[GerenciaZap] Atualizando atalhos...');
      }
      window.__gerenciazapInjected = true;
      
      const shortcuts = ${JSON.stringify(shortcutsMap)};
      const keywords = ${JSON.stringify(keywordsMap)};
      
      console.log('[GerenciaZap] Atalhos carregados:', Object.keys(shortcuts).length);
      console.log('[GerenciaZap] Keywords carregadas:', Object.keys(keywords).length);
      
      // Adicionar keywords automáticas
      function getAutoKeywords() {
        const now = new Date();
        const hour = now.getHours();
        
        let greeting = 'Olá';
        if (hour >= 5 && hour < 12) greeting = 'Bom dia';
        else if (hour >= 12 && hour < 18) greeting = 'Boa tarde';
        else greeting = 'Boa noite';
        
        return {
          '<SAUDACAO>': greeting,
          '<DATA>': now.toLocaleDateString('pt-BR'),
          '<HORA>': now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
        };
      }
      
      function replaceKeywords(text) {
        let result = text;
        
        // Keywords do usuário
        for (const [key, value] of Object.entries(keywords)) {
          result = result.split(key).join(value);
        }
        
        // Keywords automáticas
        const autoKeywords = getAutoKeywords();
        for (const [key, value] of Object.entries(autoKeywords)) {
          result = result.split(key).join(value);
        }
        
        return result;
      }
      
      // Função para processar <ENTER> no texto expandido
      function processEnters(text, element) {
        const parts = text.split('<ENTER>');
        if (parts.length <= 1) return text;
        
        // Simular envio de mensagens intermediárias
        const hasTrailingEnter = text.trimEnd().endsWith('<ENTER>');
        const cleanParts = parts.map(p => p.trim()).filter(p => p.length > 0);
        
        if (cleanParts.length === 0) return '';
        
        // Para WhatsApp: enviar cada parte
        if (cleanParts.length > 1) {
          // Agendar envio das partes intermediárias
          let index = 0;
          const sendNextPart = () => {
            if (index < cleanParts.length - (hasTrailingEnter ? 0 : 1)) {
              const part = cleanParts[index];
              
              // Encontrar elemento ativo do WhatsApp
              const activeElement = document.activeElement;
              if (activeElement && activeElement.isContentEditable) {
                activeElement.textContent = part;
                activeElement.dispatchEvent(new InputEvent('input', { bubbles: true }));
                
                // Simular Enter para enviar
                setTimeout(() => {
                  activeElement.dispatchEvent(new KeyboardEvent('keydown', { 
                    key: 'Enter', 
                    code: 'Enter',
                    keyCode: 13,
                    which: 13,
                    bubbles: true 
                  }));
                  
                  index++;
                  if (index < cleanParts.length - (hasTrailingEnter ? 0 : 1)) {
                    setTimeout(sendNextPart, 200);
                  }
                }, 50);
              }
            }
          };
          
          // Se não tem trailing enter, última parte fica na caixa
          if (!hasTrailingEnter && cleanParts.length > 1) {
            setTimeout(() => {
              const activeElement = document.activeElement;
              if (activeElement && activeElement.isContentEditable) {
                activeElement.textContent = cleanParts[cleanParts.length - 1];
                activeElement.dispatchEvent(new InputEvent('input', { bubbles: true }));
              }
            }, cleanParts.length * 250);
          }
          
          sendNextPart();
          return ''; // Processamento é assíncrono
        }
        
        return hasTrailingEnter ? '' : cleanParts[cleanParts.length - 1];
      }
      
      function processInput(element) {
        if (!element) return;
        let text = '';
        let isContentEditable = false;
        
        if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
          text = element.value;
        } else if (element.isContentEditable || element.contentEditable === 'true') {
          text = element.textContent || element.innerText || '';
          isContentEditable = true;
        } else {
          return;
        }
        
        let foundShortcut = false;
        
        for (const [command, expandedText] of Object.entries(shortcuts)) {
          if (text.includes(command)) {
            console.log('[GerenciaZap] Atalho encontrado:', command);
            foundShortcut = true;
            
            let replacement = replaceKeywords(expandedText);
            
            // Processar <ENTER> se presente
            if (replacement.includes('<ENTER>')) {
              const processed = processEnters(replacement, element);
              text = text.split(command).join(processed);
            } else {
              text = text.split(command).join(replacement);
            }
            
            if (isContentEditable) {
              // Para WhatsApp Web - preservar spans internos
              const spans = element.querySelectorAll('span');
              if (spans.length > 0) {
                // WhatsApp usa spans para formatar - limpar e adicionar texto
                element.innerHTML = '';
                const textNode = document.createTextNode(text);
                element.appendChild(textNode);
              } else {
                element.textContent = text;
              }
              
              // Mover cursor para o final
              const selection = window.getSelection();
              if (selection && element.childNodes.length > 0) {
                const range = document.createRange();
                range.selectNodeContents(element);
                range.collapse(false);
                selection.removeAllRanges();
                selection.addRange(range);
              }
              
              // Disparar evento input para WhatsApp detectar
              element.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true }));
            } else {
              const cursorPos = element.selectionStart;
              const diff = text.length - element.value.length;
              element.value = text;
              element.setSelectionRange(cursorPos + diff, cursorPos + diff);
              element.dispatchEvent(new Event('input', { bubbles: true }));
            }
            
            element.dispatchEvent(new Event('change', { bubbles: true }));
            
            console.log('[GerenciaZap] Texto substituído com sucesso');
            break; // Processar apenas um atalho por vez
          }
        }
      }
      
      // Remover listeners antigos se existirem
      if (window.__gerenciazapInputHandler) {
        document.removeEventListener('input', window.__gerenciazapInputHandler, true);
        document.removeEventListener('keyup', window.__gerenciazapKeyHandler, true);
      }
      
      // Criar handlers
      window.__gerenciazapInputHandler = (e) => {
        // Debounce para evitar processamento excessivo
        clearTimeout(window.__gerenciazapDebounce);
        window.__gerenciazapDebounce = setTimeout(() => {
          processInput(e.target);
        }, 50);
      };
      
      window.__gerenciazapKeyHandler = (e) => {
        // Processar ao digitar espaço, Tab ou após o comando
        if (e.key === ' ' || e.key === 'Tab') {
          processInput(e.target);
        }
      };
      
      // Adicionar listeners com capture para pegar antes do WhatsApp
      document.addEventListener('input', window.__gerenciazapInputHandler, true);
      document.addEventListener('keyup', window.__gerenciazapKeyHandler, true);
      
      // MutationObserver para detectar novos elementos editáveis
      if (!window.__gerenciazapObserver) {
        window.__gerenciazapObserver = new MutationObserver((mutations) => {
          // Re-verificar se há novos contentEditables
        });
        window.__gerenciazapObserver.observe(document.body, { 
          childList: true, 
          subtree: true 
        });
      }
      
      console.log('[GerenciaZap] Listeners de atalhos registrados com sucesso');
      
      return 'ok';
    })();
  `;
}

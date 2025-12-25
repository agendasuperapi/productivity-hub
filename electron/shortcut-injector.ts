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
      
      // Criar container de notificações se não existir
      function createToastContainer() {
        let container = document.getElementById('gerenciazap-toast-container');
        if (!container) {
          container = document.createElement('div');
          container.id = 'gerenciazap-toast-container';
          container.style.cssText = \`
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 999999;
            display: flex;
            flex-direction: column;
            gap: 8px;
            pointer-events: none;
          \`;
          document.body.appendChild(container);
        }
        return container;
      }
      
      // Mostrar notificação visual
      function showShortcutToast(command) {
        const container = createToastContainer();
        
        const toast = document.createElement('div');
        toast.style.cssText = \`
          background: linear-gradient(135deg, hsl(180, 100%, 25%) 0%, hsl(180, 100%, 18%) 100%);
          color: hsl(180, 100%, 95%);
          padding: 10px 16px;
          border-radius: 8px;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          font-size: 13px;
          box-shadow: 0 4px 12px rgba(0, 164, 164, 0.4);
          display: flex;
          align-items: center;
          gap: 8px;
          opacity: 0;
          transform: translateX(20px);
          transition: all 0.3s ease;
          pointer-events: auto;
        \`;
        
        toast.innerHTML = \`
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
            <polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
          <span><strong>\${command}</strong> expandido</span>
        \`;
        
        container.appendChild(toast);
        
        // Animar entrada
        requestAnimationFrame(() => {
          toast.style.opacity = '1';
          toast.style.transform = 'translateX(0)';
        });
        
        // Remover após 2.5s
        setTimeout(() => {
          toast.style.opacity = '0';
          toast.style.transform = 'translateX(20px)';
          setTimeout(() => {
            if (toast.parentNode) {
              toast.parentNode.removeChild(toast);
            }
          }, 300);
        }, 2500);
      }
      
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
        
        // Procurar por atalhos no texto - ACEITAR com texto antes E depois
        for (const [command, expandedText] of Object.entries(shortcuts)) {
          // Escapar caracteres especiais do comando para regex
          const escapedCommand = command.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\$&');
          
          // Aceitar: início ou espaço antes | comando | QUALQUER COISA depois (incluindo nada)
          // Isso permite: "/pix", "/pix algo", "texto /pix", "texto /pix algo", "/ai/get.php"
          const regex = new RegExp('(^|\\\\s)(' + escapedCommand + ')');
          
          const match = text.match(regex);
          if (!match) continue;
          
          console.log('[GerenciaZap] Atalho encontrado:', command, 'no texto:', text);
          
          let replacement = replaceKeywords(expandedText);
          
          // Processar <ENTER> se presente
          if (replacement.includes('<ENTER>')) {
            replacement = processEnters(replacement, element);
          }
          
          // Encontrar a posição exata do comando para substituição precisa
          const matchIndex = match.index;
          const prefixSpace = match[1]; // '' ou ' '
          const commandStart = matchIndex + prefixSpace.length;
          const commandEnd = commandStart + command.length;
          
          // Pegar texto antes e depois do comando
          const textBefore = text.substring(0, commandStart);
          const textAfter = text.substring(commandEnd);
          
          // Montar texto final: antes + substituição + depois
          text = textBefore + replacement + textAfter;
          
          console.log('[GerenciaZap] Texto após substituição:', text);
          
          if (isContentEditable) {
            // === WHATSAPP WEB COMPATIBILIDADE ===
            // WhatsApp usa React que monitora mudanças específicas
            
            // 1. Garantir foco no elemento
            element.focus();
            
            // 2. Pequeno delay para garantir que o elemento está pronto
            setTimeout(() => {
              try {
                const selection = window.getSelection();
                
                // 3. Selecionar TODO o conteúdo atual
                const range = document.createRange();
                range.selectNodeContents(element);
                selection.removeAllRanges();
                selection.addRange(range);
                
                // 4. Tentar execCommand primeiro (melhor compatibilidade React)
                const success = document.execCommand('insertText', false, text);
                
                console.log('[GerenciaZap] execCommand result:', success);
                
                // 5. Verificar se funcionou
                const currentContent = (element.textContent || '').trim();
                const expectedContent = text.trim();
                
                if (!success || currentContent !== expectedContent) {
                  console.log('[GerenciaZap] execCommand falhou, usando fallback');
                  
                  // Fallback: manipulação direta + eventos simulados
                  
                  // Limpar elemento
                  while (element.firstChild) {
                    element.removeChild(element.firstChild);
                  }
                  
                  // Inserir texto como nó de texto
                  const textNode = document.createTextNode(text);
                  element.appendChild(textNode);
                  
                  // Posicionar cursor no final
                  const newRange = document.createRange();
                  newRange.setStartAfter(textNode);
                  newRange.collapse(true);
                  selection.removeAllRanges();
                  selection.addRange(newRange);
                  
                  // Disparar eventos em sequência para React detectar
                  
                  // beforeinput
                  element.dispatchEvent(new InputEvent('beforeinput', {
                    bubbles: true,
                    cancelable: true,
                    composed: true,
                    inputType: 'insertText',
                    data: text
                  }));
                  
                  // input
                  element.dispatchEvent(new InputEvent('input', {
                    bubbles: true,
                    cancelable: false,
                    composed: true,
                    inputType: 'insertText',
                    data: text
                  }));
                  
                  // keyup para simular fim de digitação
                  element.dispatchEvent(new KeyboardEvent('keyup', {
                    bubbles: true,
                    cancelable: true,
                    key: ' ',
                    code: 'Space'
                  }));
                }
                
                // 6. Disparar change para finalizar
                element.dispatchEvent(new Event('change', { bubbles: true }));
                
              } catch (err) {
                console.error('[GerenciaZap] Erro na substituição:', err);
              }
            }, 10);
            
          } else {
            // Input/Textarea padrão
            const cursorPos = element.selectionStart;
            const diff = text.length - element.value.length;
            element.value = text;
            element.setSelectionRange(cursorPos + diff, cursorPos + diff);
            element.dispatchEvent(new Event('input', { bubbles: true }));
          }
          
          element.dispatchEvent(new Event('change', { bubbles: true }));
          
          // Mostrar notificação visual
          showShortcutToast(command);
          
          console.log('[GerenciaZap] Texto substituído com sucesso para:', replacement.substring(0, 50));
          break; // Processar apenas um atalho por vez
        }
      }
      
      // Remover listeners antigos se existirem
      if (window.__gerenciazapInputHandler) {
        document.removeEventListener('input', window.__gerenciazapInputHandler, true);
        document.removeEventListener('keyup', window.__gerenciazapKeyHandler, true);
      }
      
      // Criar handlers
      let lastProcessedText = '';
      let lastProcessedTime = 0;
      
      window.__gerenciazapInputHandler = (e) => {
        const target = e.target;
        if (!target) return;
        
        // Verificar se é um elemento editável
        const isEditable = target.tagName === 'INPUT' || 
                          target.tagName === 'TEXTAREA' || 
                          target.isContentEditable || 
                          target.contentEditable === 'true';
        
        if (!isEditable) return;
        
        // Debounce para evitar processamento excessivo
        clearTimeout(window.__gerenciazapDebounce);
        window.__gerenciazapDebounce = setTimeout(() => {
          const currentText = target.value || target.textContent || '';
          const now = Date.now();
          
          // Evitar processar o mesmo texto repetidamente
          if (currentText !== lastProcessedText || now - lastProcessedTime > 500) {
            lastProcessedText = currentText;
            lastProcessedTime = now;
            processInput(target);
          }
        }, 100);
      };
      
      window.__gerenciazapKeyHandler = (e) => {
        // Processar ao digitar espaço, Tab ou Enter
        if (e.key === ' ' || e.key === 'Tab' || e.key === 'Enter') {
          // Pequeno delay para garantir que o texto foi atualizado
          setTimeout(() => {
            processInput(e.target);
          }, 10);
        }
      };
      
      // Adicionar listeners com capture para pegar antes do WhatsApp
      document.addEventListener('input', window.__gerenciazapInputHandler, true);
      document.addEventListener('keyup', window.__gerenciazapKeyHandler, true);
      
      // Também escutar eventos de foco para garantir captura
      document.addEventListener('focusin', (e) => {
        const target = e.target;
        if (target && (target.isContentEditable || target.contentEditable === 'true')) {
          // Re-registrar no elemento focado
          console.log('[GerenciaZap] Elemento editável focado');
        }
      }, true);
      
      console.log('[GerenciaZap] Listeners de atalhos registrados com sucesso');
      
      return 'ok';
    })();
  `;
}

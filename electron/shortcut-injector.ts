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
            // === WHATSAPP WEB - ABORDAGEM VIA CLIPBOARD ===
            // WhatsApp usa Lexical/Draft.js que ignora mudanças diretas no DOM
            // Solução: simular operação de paste que o editor reconhece nativamente
            
            element.focus();
            
            (async () => {
              try {
                // 1. Salvar conteúdo atual do clipboard (para restaurar depois)
                let originalClipboard = '';
                try {
                  originalClipboard = await navigator.clipboard.readText();
                } catch (e) {
                  console.log('[GerenciaZap] Não foi possível ler clipboard original');
                }
                
                // 2. Copiar texto expandido para o clipboard
                await navigator.clipboard.writeText(text);
                console.log('[GerenciaZap] Texto copiado para clipboard:', text.substring(0, 50));
                
                // 3. Selecionar TODO o conteúdo atual do campo
                const selection = window.getSelection();
                const range = document.createRange();
                range.selectNodeContents(element);
                selection.removeAllRanges();
                selection.addRange(range);
                
                // 4. Tentar simular paste de várias formas
                
                // 4a. Criar DataTransfer para evento de paste
                const dataTransfer = new DataTransfer();
                dataTransfer.setData('text/plain', text);
                
                // 4b. Disparar evento clipboardData (paste event)
                const pasteEvent = new ClipboardEvent('paste', {
                  bubbles: true,
                  cancelable: true,
                  clipboardData: dataTransfer
                });
                
                const pasteHandled = element.dispatchEvent(pasteEvent);
                console.log('[GerenciaZap] Paste event handled:', pasteHandled);
                
                // 4c. Disparar InputEvent com tipo insertFromPaste
                const inputEvent = new InputEvent('beforeinput', {
                  bubbles: true,
                  cancelable: true,
                  inputType: 'insertFromPaste',
                  data: text,
                  dataTransfer: dataTransfer
                });
                element.dispatchEvent(inputEvent);
                
                // 4d. Tentar execCommand como fallback
                const execResult = document.execCommand('insertText', false, text);
                console.log('[GerenciaZap] execCommand insertText result:', execResult);
                
                // 4e. Se ainda não funcionou, tentar paste direto
                if (!execResult) {
                  const pasteResult = document.execCommand('paste');
                  console.log('[GerenciaZap] execCommand paste result:', pasteResult);
                }
                
                // 5. Verificar se funcionou, se não, forçar via DOM + eventos específicos do Lexical
                setTimeout(() => {
                  const currentContent = (element.textContent || '').trim();
                  const expectedContent = text.trim();
                  
                  if (currentContent !== expectedContent) {
                    console.log('[GerenciaZap] Clipboard approach falhou, tentando Lexical workaround');
                    
                    // Lexical workaround: simular digitação caractere por caractere
                    // Limpar elemento primeiro
                    while (element.firstChild) {
                      element.removeChild(element.firstChild);
                    }
                    
                    // Inserir texto como nó
                    const textNode = document.createTextNode(text);
                    element.appendChild(textNode);
                    
                    // Posicionar cursor no final
                    const newRange = document.createRange();
                    newRange.setStartAfter(textNode);
                    newRange.collapse(true);
                    selection.removeAllRanges();
                    selection.addRange(newRange);
                    
                    // Disparar eventos que Lexical monitora
                    // compositionstart/end para simular IME input
                    element.dispatchEvent(new CompositionEvent('compositionstart', {
                      bubbles: true,
                      data: ''
                    }));
                    
                    element.dispatchEvent(new CompositionEvent('compositionend', {
                      bubbles: true,
                      data: text
                    }));
                    
                    // Input event
                    element.dispatchEvent(new InputEvent('input', {
                      bubbles: true,
                      inputType: 'insertText',
                      data: text
                    }));
                    
                    // MutationObserver trigger - forçar React a detectar
                    const observer = new MutationObserver(() => {});
                    observer.observe(element, { childList: true, characterData: true, subtree: true });
                    element.normalize();
                    observer.disconnect();
                  }
                  
                  // 6. Restaurar clipboard original
                  if (originalClipboard) {
                    navigator.clipboard.writeText(originalClipboard).catch(() => {});
                  }
                }, 100);
                
                // Disparar change
                element.dispatchEvent(new Event('change', { bubbles: true }));
                
              } catch (err) {
                console.error('[GerenciaZap] Erro na substituição via clipboard:', err);
                
                // Fallback final: manipulação direta
                while (element.firstChild) {
                  element.removeChild(element.firstChild);
                }
                element.appendChild(document.createTextNode(text));
                element.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
              }
            })();
            
          } else {
            // Input/Textarea padrão - REACT COMPATIBILITY
            // React usa seu próprio sistema de eventos, precisamos "hackear" o value descriptor
            
            const cursorPos = element.selectionStart || 0;
            const originalValue = element.value;
            
            // Técnica para forçar React a reconhecer a mudança:
            // Obter o prototype do input para acessar o setter nativo
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
              window.HTMLInputElement.prototype, 'value'
            )?.set;
            const nativeTextAreaValueSetter = Object.getOwnPropertyDescriptor(
              window.HTMLTextAreaElement.prototype, 'value'
            )?.set;
            
            const setter = element.tagName === 'TEXTAREA' 
              ? nativeTextAreaValueSetter 
              : nativeInputValueSetter;
            
            if (setter) {
              // Usar o setter nativo para alterar o valor
              setter.call(element, text);
            } else {
              // Fallback se não conseguir o setter
              element.value = text;
            }
            
            // Disparar evento input que o React reconhece
            const inputEvent = new Event('input', { bubbles: true, cancelable: true });
            // Marcar como evento do usuário para React
            Object.defineProperty(inputEvent, 'target', { writable: false, value: element });
            element.dispatchEvent(inputEvent);
            
            // Disparar change também
            const changeEvent = new Event('change', { bubbles: true, cancelable: true });
            element.dispatchEvent(changeEvent);
            
            // Disparar blur e focus para forçar atualização de validação
            element.dispatchEvent(new FocusEvent('blur', { bubbles: true }));
            setTimeout(() => {
              element.focus();
              // Posicionar cursor no final
              const newPos = text.length;
              element.setSelectionRange(newPos, newPos);
            }, 0);
            
            console.log('[GerenciaZap] Input atualizado via setter nativo');
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

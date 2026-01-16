/**
 * Gera o script de injeção de atalhos de texto para webviews e janelas flutuantes
 */

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface TextShortcutData {
  command: string;
  expanded_text: string;
  auto_send?: boolean;
  messages?: ShortcutMessage[];
}

interface KeywordData {
  key: string;
  value: string;
}

export interface ShortcutConfig {
  activationKey: string; // Tecla/texto de ativação (ex: "/", "!", "#")
  activationTime?: number; // Tempo de ativação em segundos
}

export function generateShortcutScript(
  textShortcuts: TextShortcutData[],
  keywords: KeywordData[],
  config: ShortcutConfig = { activationKey: '/', activationTime: 10 }
): string {
  // Criar mapa de atalhos com suporte a múltiplas mensagens
  const shortcutsMap: Record<string, { messages: Array<{ text: string; auto_send: boolean }> }> = {};
  textShortcuts.forEach(s => {
    if (s.messages && s.messages.length > 0) {
      shortcutsMap[s.command] = { messages: s.messages };
    } else {
      shortcutsMap[s.command] = { 
        messages: [{ text: s.expanded_text, auto_send: s.auto_send || false }] 
      };
    }
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
        // Limpar estado anterior
        if (window.__gerenciazapActivationCleanup) {
          window.__gerenciazapActivationCleanup();
        }
      }
      window.__gerenciazapInjected = true;
      
      const shortcuts = ${JSON.stringify(shortcutsMap)};
      const keywords = ${JSON.stringify(keywordsMap)};
      const activationKey = ${JSON.stringify(config.activationKey || '/')};
      const ACTIVATION_DURATION = ${(config.activationTime || 10) * 1000}; // em milissegundos
      
      // Estado de ativação dos atalhos
      let isShortcutModeActive = false;
      let activationTimeout = null;
      let countdownInterval = null;
      let remainingSeconds = ${config.activationTime || 10};
      
      console.log('[GerenciaZap] Atalhos carregados:', Object.keys(shortcuts).length);
      console.log('[GerenciaZap] Keywords carregadas:', Object.keys(keywords).length);
      console.log('[GerenciaZap] Tecla de ativação:', activationKey);
      console.log('[GerenciaZap] Tempo de ativação:', ACTIVATION_DURATION / 1000, 's');
      
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
      
      // Indicador de ativação com countdown
      function createActivationIndicator() {
        let indicator = document.getElementById('gerenciazap-activation-indicator');
        if (!indicator) {
          indicator = document.createElement('div');
          indicator.id = 'gerenciazap-activation-indicator';
          indicator.style.cssText = \`
            position: fixed;
            top: 10px;
            left: 50%;
            transform: translateX(-50%) translateY(-10px);
            z-index: 999999;
            background: linear-gradient(135deg, hsl(142, 76%, 36%) 0%, hsl(142, 76%, 28%) 100%);
            color: white;
            padding: 8px 14px;
            border-radius: 20px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 12px;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(34, 197, 94, 0.4);
            display: flex;
            align-items: center;
            gap: 6px;
            opacity: 0;
            transition: all 0.2s ease;
            pointer-events: none;
          \`;
          document.body.appendChild(indicator);
        }
        return indicator;
      }
      
      function updateIndicatorContent(seconds) {
        const indicator = document.getElementById('gerenciazap-activation-indicator');
        if (indicator) {
          indicator.innerHTML = \`
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
            </svg>
            <span>Atalhos Ativos</span>
            <span style="margin-left: 4px; padding: 2px 6px; background: rgba(255,255,255,0.2); border-radius: 10px; font-size: 10px; font-weight: 700;">\${seconds}s</span>
          \`;
        }
      }
      
      // Mostrar/ocultar indicador de ativação
      function showActivationIndicator() {
        const indicator = createActivationIndicator();
        updateIndicatorContent(remainingSeconds);
        indicator.style.opacity = '1';
        indicator.style.transform = 'translateX(-50%) translateY(0)';
      }
      
      function hideActivationIndicator() {
        const indicator = document.getElementById('gerenciazap-activation-indicator');
        if (indicator) {
          indicator.style.opacity = '0';
          indicator.style.transform = 'translateX(-50%) translateY(-10px)';
        }
        // Limpar countdown interval
        if (countdownInterval) {
          clearInterval(countdownInterval);
          countdownInterval = null;
        }
      }
      
      // Ativar modo de atalhos
      function activateShortcutMode() {
        // SEMPRE reiniciar o modo de atalhos, mesmo que já esteja ativo
        // Isso garante que pressionar a tecla de ativação novamente sempre funcione
        
        // Limpar timers anteriores
        clearTimeout(activationTimeout);
        if (countdownInterval) {
          clearInterval(countdownInterval);
        }
        
        // Resetar estado completamente
        const wasActive = isShortcutModeActive;
        isShortcutModeActive = true;
        
        // Resetar countdown
        remainingSeconds = ${config.activationTime || 10};
        
        if (wasActive) {
          console.log('[GerenciaZap] Modo de atalhos REINICIADO');
        } else {
          console.log('__GERENCIAZAP_SHORTCUT_MODE__:ACTIVE');
          console.log('[GerenciaZap] Modo de atalhos ATIVADO');
        }
        
        showActivationIndicator();
        
        // Iniciar countdown visual
        countdownInterval = setInterval(() => {
          remainingSeconds--;
          if (remainingSeconds <= 0) {
            deactivateShortcutMode();
          } else {
            updateIndicatorContent(remainingSeconds);
          }
        }, 1000);
        
        // Desativar após o tempo limite
        activationTimeout = setTimeout(() => {
          deactivateShortcutMode();
        }, ACTIVATION_DURATION);
      }
      
      function deactivateShortcutMode() {
        isShortcutModeActive = false;
        hideActivationIndicator();
        clearTimeout(activationTimeout);
        if (countdownInterval) {
          clearInterval(countdownInterval);
          countdownInterval = null;
        }
        console.log('__GERENCIAZAP_SHORTCUT_MODE__:INACTIVE');
        console.log('[GerenciaZap] Modo de atalhos DESATIVADO');
      }
      
      // Listener para tecla de ativação
      function handleActivationKey(e) {
        if (e.key === activationKey || e.code === activationKey) {
          activateShortcutMode();
        }
        // Escape desativa o modo
        if (e.key === 'Escape' && isShortcutModeActive) {
          deactivateShortcutMode();
        }
      }
      
      document.addEventListener('keydown', handleActivationKey, true);
      
      // Expor função de desativação para chamada externa
      window.__gerenciazapDeactivateShortcutMode = deactivateShortcutMode;
      
      // Cleanup function
      window.__gerenciazapActivationCleanup = () => {
        document.removeEventListener('keydown', handleActivationKey, true);
        hideActivationIndicator();
        clearTimeout(activationTimeout);
        if (countdownInterval) {
          clearInterval(countdownInterval);
          countdownInterval = null;
        }
      };
      
      // Debounce para notificações
      const TOAST_DEBOUNCE_MS = 1000;
      let lastToastCommand = '';
      let lastToastTime = 0;
      
      // Mostrar notificação visual
      function showShortcutToast(command) {
        // Debounce: evitar notificações duplicadas
        const now = Date.now();
        if (command === lastToastCommand && now - lastToastTime < TOAST_DEBOUNCE_MS) {
          console.log('[GerenciaZap] Toast ignorado (debounce):', command);
          return;
        }
        lastToastCommand = command;
        lastToastTime = now;
        
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
        
        // Desativar modo de atalhos imediatamente após expansão
        if (isShortcutModeActive) {
          console.log('[GerenciaZap] Desativando modo após expansão do atalho:', command);
          isShortcutModeActive = false;
          hideActivationIndicator();
          clearTimeout(activationTimeout);
          if (countdownInterval) {
            clearInterval(countdownInterval);
            countdownInterval = null;
          }
          console.log('__GERENCIAZAP_SHORTCUT_MODE__:INACTIVE');
        }
        
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

      // Normaliza o elemento editável para o "root" (evita capturar <span> interno do WhatsApp)
      // VERSÃO ROBUSTA: funciona mesmo quando o target não é editável (spans internos com contenteditable=false)
      function normalizeInputElement(el) {
        if (!el) return null;

        // Alguns eventos podem vir com target não-elemento (TEXT_NODE, etc)
        if (el.nodeType && el.nodeType !== 1) {
          el = el.parentElement;
        }

        if (!el || !el.tagName) return null;

        // INPUT/TEXTAREA são sempre válidos
        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') return el;

        // Tentar closest SEMPRE, mesmo que o elemento não seja editável
        // Isso captura spans internos do WhatsApp que são filhos de contenteditable
        if (typeof el.closest === 'function') {
          // Tentar múltiplos seletores em ordem de prioridade
          const selectors = [
            '[data-testid="conversation-compose-box-input"]',  // WhatsApp específico
            'div[role="textbox"][contenteditable="true"]',     // Pattern comum
            '[contenteditable="true"]',                         // Genérico
            '[contenteditable="plaintext-only"]',               // Alguns editores usam isso
          ];
          
          for (const selector of selectors) {
            const root = el.closest(selector);
            if (root) return root;
          }
        }

        // Preferir o root que possui contenteditable="true"
        if (typeof el.getAttribute === 'function' && el.getAttribute('contenteditable') === 'true') {
          return el;
        }

        // isContentEditable pode ser herdado (ex: <span> dentro do editor)
        if (el.isContentEditable || el.contentEditable === 'true') {
          // Fallback: subir até o último pai ainda editável
          let cur = el;
          while (cur && cur.parentElement && (cur.parentElement.isContentEditable || cur.parentElement.contentEditable === 'true')) {
            cur = cur.parentElement;
          }
          return cur;
        }

        // NOVO: Mesmo que o elemento não seja editável, tentar subir na hierarquia
        // Isso captura casos onde o evento vem de um span com contenteditable="false" dentro de um div editável
        let parent = el.parentElement;
        while (parent) {
          if (parent.tagName === 'INPUT' || parent.tagName === 'TEXTAREA') return parent;
          if (typeof parent.getAttribute === 'function' && parent.getAttribute('contenteditable') === 'true') {
            return parent;
          }
          if (parent.isContentEditable || parent.contentEditable === 'true') {
            // Continuar subindo para encontrar o root
            let cur = parent;
            while (cur && cur.parentElement && (cur.parentElement.isContentEditable || cur.parentElement.contentEditable === 'true')) {
              cur = cur.parentElement;
            }
            return cur;
          }
          parent = parent.parentElement;
        }

        return null;
      }
      
      // Busca o melhor candidato editável na página (fallback quando normalizeInputElement falha)
      function findBestEditableCandidate() {
        const selectors = [
          '[data-testid="conversation-compose-box-input"]',  // WhatsApp específico
          'div[role="textbox"][contenteditable="true"]',     // Pattern comum
          '[contenteditable="true"]:not([contenteditable="false"] *)',  // Editável mas não filho de não-editável
          'textarea:not([disabled])',
          'input[type="text"]:not([disabled])',
        ];
        
        for (const selector of selectors) {
          const elements = document.querySelectorAll(selector);
          for (const el of elements) {
            // Verificar se é visível
            const rect = el.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.right > 0) {
              console.log('[GerenciaZap] findBestEditableCandidate encontrou:', el.tagName, selector);
              return el;
            }
          }
        }
        
        console.log('[GerenciaZap] findBestEditableCandidate: nenhum candidato encontrado');
        return null;
      }

      // Extrai elemento editável de composedPath (para eventos)
      function getEditableFromComposedPath(e) {
        if (!e || typeof e.composedPath !== 'function') return null;
        
        const path = e.composedPath();
        for (const el of path) {
          if (!el || !el.tagName) continue;
          if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') return el;
          if (typeof el.getAttribute === 'function' && el.getAttribute('contenteditable') === 'true') {
            return el;
          }
        }
        return null;
      }
      
      function processInput(element) {
        element = normalizeInputElement(element);
        if (!element) return;
        
        // Verificar se o modo de atalhos está ativo
        if (!isShortcutModeActive) {
          return; // Não processar se a tecla de ativação não foi pressionada
        }
        
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
        
        // Procurar por atalhos no texto - ACEITAR com texto antes E depois (case-insensitive)
        const textLower = text.toLowerCase();
        for (const [command, shortcutData] of Object.entries(shortcuts)) {
          // Verificar se o comando começa com o prefixo configurado (usa activationKey)
          const prefixLower = activationKey.toLowerCase();
          if (!command.toLowerCase().startsWith(prefixLower)) {
            continue; // Ignorar comandos que não começam com o prefixo
          }
          
          // Verificar se o texto contém o comando (case-insensitive)
          const commandLower = command.toLowerCase();
          if (!textLower.includes(commandLower)) continue;
          
          // Escapar caracteres especiais do comando para regex
          const escapedCommand = command.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\$&');
          
          // Aceitar: início ou espaço antes | comando | QUALQUER COISA depois (incluindo nada)
          // Isso permite: "/pix", "/pix algo", "texto /pix", "texto /pix algo", "/ai/get.php"
          // Flag 'i' para case-insensitive
          const regex = new RegExp('(^|\\\\s)(' + escapedCommand + ')', 'i');
          
          const match = text.match(regex);
          if (!match) continue;
          
          console.log('[GerenciaZap] Atalho encontrado:', command, 'no texto:', text);

          // Desativar imediatamente o modo ao encontrar um atalho.
          // Isso evita reprocessamentos reentrantes disparados pelos eventos de input/change
          // que acontecem durante a substituição do texto (especialmente em inputs controlados).
          deactivateShortcutMode();
          
          const messages = shortcutData.messages || [];
          if (messages.length === 0) continue;
          
          // Para janelas flutuantes, usar primeira mensagem
          let replacement = replaceKeywords(messages[0].text);
          
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
            // === WHATSAPP WEB - COPIAR VIA TEXTAREA OCULTO ===
            element.focus();
            
            // 1. Criar textarea temporário para copiar (funciona em webviews)
            const tempTextarea = document.createElement('textarea');
            tempTextarea.value = text;
            tempTextarea.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0;';
            document.body.appendChild(tempTextarea);
            tempTextarea.select();
            tempTextarea.setSelectionRange(0, text.length);
            
            let copySuccess = false;
            try {
              copySuccess = document.execCommand('copy');
              console.log('[GerenciaZap] execCommand copy:', copySuccess ? 'sucesso' : 'falhou');
            } catch (e) {
              console.error('[GerenciaZap] Erro execCommand copy:', e);
            }
            
            document.body.removeChild(tempTextarea);
            
            // 2. Re-focar elemento original
            element.focus();
            
            // 3. Selecionar todo conteúdo
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(element);
            selection.removeAllRanges();
            selection.addRange(range);
            
            // 4. Colar via execCommand
            setTimeout(() => {
              try {
                // Primeiro tentar delete + insertText
                document.execCommand('delete');
                const insertSuccess = document.execCommand('insertText', false, text);
                
                if (insertSuccess) {
                  console.log('[GerenciaZap] insertText funcionou');
                  showShortcutToast(command);
                  return;
                }
              } catch (e) {
                console.log('[GerenciaZap] insertText falhou:', e);
              }
              
              // Fallback: manipulação direta + eventos
              console.log('[GerenciaZap] Usando fallback direto');
              element.textContent = text;
              
              // Mover cursor para o final
              const newRange = document.createRange();
              newRange.selectNodeContents(element);
              newRange.collapse(false);
              selection.removeAllRanges();
              selection.addRange(newRange);
              
              // Disparar eventos
              element.dispatchEvent(new InputEvent('input', {
                bubbles: true,
                inputType: 'insertText',
                data: text
              }));
              
              showShortcutToast(command);
            }, 10);
            
            return; // Processamento async
            
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
      if (window.__gerenciazapBeforeInputHandler) {
        document.removeEventListener('beforeinput', window.__gerenciazapBeforeInputHandler, true);
      }
      if (window.__gerenciazapFocusHandler) {
        document.removeEventListener('focusin', window.__gerenciazapFocusHandler, true);
      }
      
      // Criar handlers
      let lastProcessedText = '';
      let lastProcessedTime = 0;
      let activeInputElement = null;
      
      window.__gerenciazapInputHandler = (e) => {
        // Tentar múltiplas formas de encontrar o elemento editável
        let target = normalizeInputElement(e.target);
        
        // Fallback: usar composedPath se normalizeInputElement falhar
        if (!target) {
          target = getEditableFromComposedPath(e);
        }
        
        // Último fallback: buscar candidato global
        if (!target && isShortcutModeActive) {
          target = findBestEditableCandidate();
          if (target) {
            console.log('[GerenciaZap] InputHandler: usando findBestEditableCandidate');
          }
        }
        
        // Atualizar elemento ativo
        if (target) {
          activeInputElement = target;
        }
        
        // Debounce para evitar processamento excessivo
        clearTimeout(window.__gerenciazapDebounce);
        window.__gerenciazapDebounce = setTimeout(() => {
          const currentText = (target || activeInputElement)?.value || (target || activeInputElement)?.textContent || '';
          const now = Date.now();
          
          // Evitar processar o mesmo texto repetidamente
          if (currentText !== lastProcessedText || now - lastProcessedTime > 500) {
            lastProcessedText = currentText;
            lastProcessedTime = now;
            processInput(target || activeInputElement);
          }
        }, 100);
      };
      
      // Handler de beforeinput (mais confiável em alguns editores ricos)
      window.__gerenciazapBeforeInputHandler = (e) => {
        // Tentar múltiplas formas de encontrar o elemento editável
        let target = normalizeInputElement(e.target);
        if (!target) {
          target = getEditableFromComposedPath(e);
        }
        
        // Atualizar elemento ativo
        if (target) {
          activeInputElement = target;
        }
      };
      
      window.__gerenciazapKeyHandler = (e) => {
        // Tentar múltiplas formas de encontrar o elemento editável
        let target = normalizeInputElement(e.target);
        if (!target) {
          target = getEditableFromComposedPath(e);
        }
        if (!target && isShortcutModeActive) {
          target = findBestEditableCandidate();
        }
        
        // Processar ao digitar espaço, Tab ou Enter
        if (e.key === ' ' || e.key === 'Tab' || e.key === 'Enter') {
          // Pequeno delay para garantir que o texto foi atualizado
          setTimeout(() => {
            processInput(target || activeInputElement);
          }, 10);
        }
        
        // NOVO: Em modo ativo, processar qualquer tecla de caractere como fallback
        if (isShortcutModeActive && !e.ctrlKey && !e.altKey && !e.metaKey) {
          const isCharKey = e.key.length === 1 || e.key === 'Backspace' || e.key === 'Delete';
          if (isCharKey) {
            clearTimeout(window.__gerenciazapKeyDebounce);
            window.__gerenciazapKeyDebounce = setTimeout(() => {
              processInput(target || activeInputElement);
            }, 100);
          }
        }
      };
      
      // Handler de foco para sempre manter referência do último campo de entrada focado
      window.__gerenciazapFocusHandler = (e) => {
        // Tentar múltiplas formas de encontrar o elemento editável
        let target = normalizeInputElement(e.target);
        if (!target) {
          target = getEditableFromComposedPath(e);
        }
        
        if (target) {
          activeInputElement = target;
          console.log('[GerenciaZap] Elemento editável focado');
        }
      };
      
      // Adicionar listeners com capture para pegar antes do WhatsApp
      document.addEventListener('input', window.__gerenciazapInputHandler, true);
      document.addEventListener('beforeinput', window.__gerenciazapBeforeInputHandler, true);
      document.addEventListener('keyup', window.__gerenciazapKeyHandler, true);
      document.addEventListener('focusin', window.__gerenciazapFocusHandler, true);
      
      console.log('[GerenciaZap] Listeners de atalhos registrados com sucesso (incluindo beforeinput, focusin)');
      
      return 'ok';
    })();
  `;
}

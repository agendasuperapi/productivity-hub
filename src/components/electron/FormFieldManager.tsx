import { useCallback, useRef, useEffect } from 'react';
import { useFormFieldValues } from '@/hooks/useFormFieldValues';
import { extractDomain } from '@/lib/crypto';

interface FormFieldManagerProps {
  onGetSuggestionsScript: () => string;
}

export function useFormFieldManager() {
  const { getValuesForField, saveFieldValue } = useFormFieldValues();
  const pendingRequestsRef = useRef<Map<string, (values: string[]) => void>>(new Map());

  // Buscar sugestões para um campo
  const getSuggestions = useCallback(async (domain: string, fieldIdentifier: string): Promise<string[]> => {
    const values = await getValuesForField(domain, fieldIdentifier);
    return values.map(v => v.field_value);
  }, [getValuesForField]);

  // Salvar valor do campo
  const saveValue = useCallback(async (
    domain: string, 
    fieldIdentifier: string, 
    value: string,
    fieldLabel?: string
  ): Promise<boolean> => {
    return saveFieldValue(domain, fieldIdentifier, value, fieldLabel);
  }, [saveFieldValue]);

  // Script para injetar nas webviews
  const getFormFieldScript = useCallback(() => {
    return `
      (function() {
        if (window.__formFieldInjected) {
          console.log('[FormField] Script já injetado');
          return 'already_injected';
        }
        window.__formFieldInjected = true;
        
        const domain = window.location.hostname;
        let activeDropdown = null;
        let activeField = null;
        let savedFields = new Set(); // Campos já salvos nesta sessão
        
        // Criar container de dropdown
        function createDropdown() {
          const dropdown = document.createElement('div');
          dropdown.id = 'gerenciazap-form-dropdown';
          dropdown.style.cssText = \`
            position: fixed;
            background: white;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
            max-height: 200px;
            overflow-y: auto;
            z-index: 999999;
            display: none;
            min-width: 200px;
          \`;
          document.body.appendChild(dropdown);
          return dropdown;
        }
        
        // Posicionar dropdown
        function positionDropdown(dropdown, field) {
          const rect = field.getBoundingClientRect();
          var top = rect.bottom + 4;
          var left = rect.left;
          var maxTop = window.innerHeight - 210;
          var maxLeft = window.innerWidth - 210;
          
          dropdown.style.top = Math.min(top, maxTop) + 'px';
          dropdown.style.left = Math.max(0, Math.min(left, maxLeft)) + 'px';
          dropdown.style.width = Math.max(rect.width, 200) + 'px';
        }
        
        // Mostrar dropdown com sugestões
        function showDropdown(field, suggestions) {
          if (!suggestions || suggestions.length === 0) {
            hideDropdown();
            return;
          }
          
          if (!activeDropdown) {
            activeDropdown = createDropdown();
          }
          
          activeDropdown.innerHTML = suggestions.map((s, i) => \`
            <div class="form-suggestion-item" data-index="\${i}" style="
              padding: 10px 14px;
              cursor: pointer;
              border-bottom: 1px solid #f1f5f9;
              font-size: 14px;
              color: #1e293b;
              transition: background-color 0.15s;
            ">\${s}</div>
          \`).join('');
          
          // Adicionar eventos de hover e click
          activeDropdown.querySelectorAll('.form-suggestion-item').forEach((item, index) => {
            item.addEventListener('mouseenter', () => {
              item.style.backgroundColor = '#f1f5f9';
            });
            item.addEventListener('mouseleave', () => {
              item.style.backgroundColor = 'white';
            });
            item.addEventListener('click', (e) => {
              e.preventDefault();
              e.stopPropagation();
              selectSuggestion(field, suggestions[index]);
            });
          });
          
          positionDropdown(activeDropdown, field);
          activeDropdown.style.display = 'block';
          activeField = field;
        }
        
        function hideDropdown() {
          if (activeDropdown) {
            activeDropdown.style.display = 'none';
          }
          activeField = null;
        }
        
        function selectSuggestion(field, value) {
          if (field.tagName === 'INPUT' || field.tagName === 'TEXTAREA') {
            field.value = value;
            field.dispatchEvent(new Event('input', { bubbles: true }));
            field.dispatchEvent(new Event('change', { bubbles: true }));
          } else if (field.isContentEditable) {
            field.textContent = value;
            field.dispatchEvent(new InputEvent('input', { bubbles: true }));
          }
          hideDropdown();
          
          // Salvar uso (incrementar contador)
          const fieldId = getFieldIdentifier(field);
          console.warn('__GERENCIAZAP_FORM_FIELD_USE__:' + JSON.stringify({
            domain: domain,
            field: fieldId,
            value: value
          }));
        }
        
        // Identificador único do campo
        function getFieldIdentifier(field) {
          return field.name || field.id || field.placeholder || field.getAttribute('aria-label') || 'unknown';
        }
        
        // Obter label do campo
        function getFieldLabel(field) {
          // Tentar encontrar label associado
          if (field.id) {
            const label = document.querySelector('label[for="' + field.id + '"]');
            if (label) return label.textContent.trim();
          }
          
          // Verificar label pai
          const parentLabel = field.closest('label');
          if (parentLabel) {
            const text = parentLabel.textContent.replace(field.value || '', '').trim();
            if (text) return text;
          }
          
          // Usar placeholder ou aria-label
          return field.placeholder || field.getAttribute('aria-label') || field.name || field.id || 'Campo';
        }
        
        // Verificar se é campo de senha ou sensível
        function isSensitiveField(field) {
          const type = field.type?.toLowerCase();
          const name = (field.name || '').toLowerCase();
          const id = (field.id || '').toLowerCase();
          
          return type === 'password' || 
                 name.includes('password') || name.includes('senha') ||
                 id.includes('password') || id.includes('senha') ||
                 name.includes('secret') || name.includes('token') ||
                 id.includes('secret') || id.includes('token');
        }
        
        // Handler de foco
        function handleFocus(e) {
          const field = e.target;
          if (!isTextField(field) || isSensitiveField(field)) return;
          
          const fieldId = getFieldIdentifier(field);
          console.warn('[GerenciaZap][FormField] Campo focado:', fieldId, 'no domínio:', domain);
          
          // Pedir sugestões ao app
          console.warn('__GERENCIAZAP_FORM_FIELD_FOCUS__:' + JSON.stringify({
            domain: domain,
            field: fieldId
          }));
        }
        
        // Handler de blur
        function handleBlur(e) {
          const field = e.target;
          if (!isTextField(field) || isSensitiveField(field)) return;
          
          // Aguardar um pouco para permitir clique no dropdown
          setTimeout(() => {
            const value = field.tagName === 'INPUT' || field.tagName === 'TEXTAREA' 
              ? field.value 
              : field.textContent;
            
            if (value && value.trim().length >= 2) {
              const fieldId = getFieldIdentifier(field);
              const fieldLabel = getFieldLabel(field);
              const cacheKey = domain + '|' + fieldId + '|' + value;
              
              // Verificar se já salvou este campo nesta sessão
              if (!savedFields.has(cacheKey)) {
                savedFields.add(cacheKey);
                console.warn('[GerenciaZap][FormField] Salvando valor:', fieldId, '=', value);
                
                // Usar console.warn para garantir que a mensagem chegue
                console.warn('__GERENCIAZAP_FORM_FIELD_SAVE__:' + JSON.stringify({
                  domain: domain,
                  field: fieldId,
                  value: value,
                  label: fieldLabel
                }));
              }
            }
            
            hideDropdown();
          }, 200);
        }
        
        function isTextField(el) {
          if (!el) return false;
          const tagName = el.tagName?.toUpperCase();
          const type = el.type?.toLowerCase();
          
          if (tagName === 'TEXTAREA') return true;
          if (tagName === 'INPUT') {
            return ['text', 'email', 'url', 'search', 'tel', 'number'].includes(type);
          }
          if (el.isContentEditable) return true;
          
          return false;
        }
        
        // Fechar dropdown ao clicar fora
        document.addEventListener('click', (e) => {
          if (activeDropdown && !activeDropdown.contains(e.target) && e.target !== activeField) {
            hideDropdown();
          }
        });
        
        // Scroll fecha dropdown
        window.addEventListener('scroll', hideDropdown, true);
        
        // Registrar eventos
        document.addEventListener('focusin', handleFocus, true);
        document.addEventListener('focusout', handleBlur, true);
        
        // Listener para receber sugestões do app
        window.__gerenciazapFormSuggestions = function(suggestions) {
          if (activeField) {
            showDropdown(activeField, suggestions);
          }
        };
        
        console.warn('[GerenciaZap][FormField] Script de formulários injetado para:', domain);
        return 'ok';
      })();
    `;
  }, []);

  // Handler para processar mensagens do console
  const handleFormFieldMessage = useCallback(async (message: string, webview: any) => {
    // Pedido de sugestões
    if (message.startsWith('__GERENCIAZAP_FORM_FIELD_FOCUS__:')) {
      try {
        const jsonStr = message.replace('__GERENCIAZAP_FORM_FIELD_FOCUS__:', '');
        const data = JSON.parse(jsonStr);
        
        console.log('[FormField] Buscando sugestões para:', data.domain, data.field);
        const suggestions = await getSuggestions(data.domain, data.field);
        
        if (suggestions.length > 0 && webview && typeof webview.executeJavaScript === 'function') {
          webview.executeJavaScript(`
            if (window.__gerenciazapFormSuggestions) {
              window.__gerenciazapFormSuggestions(${JSON.stringify(suggestions)});
            }
          `).catch(() => {});
        }
      } catch (err) {
        console.error('[FormField] Erro ao processar pedido de sugestões:', err);
      }
      return true;
    }
    
    // Salvar valor
    if (message.startsWith('__GERENCIAZAP_FORM_FIELD_SAVE__:')) {
      try {
        const jsonStr = message.replace('__GERENCIAZAP_FORM_FIELD_SAVE__:', '');
        const data = JSON.parse(jsonStr);
        
        console.log('[FormField] Salvando valor:', data.domain, data.field, data.value);
        await saveValue(data.domain, data.field, data.value, data.label);
      } catch (err) {
        console.error('[FormField] Erro ao salvar valor:', err);
      }
      return true;
    }
    
    // Incrementar uso
    if (message.startsWith('__GERENCIAZAP_FORM_FIELD_USE__:')) {
      try {
        const jsonStr = message.replace('__GERENCIAZAP_FORM_FIELD_USE__:', '');
        const data = JSON.parse(jsonStr);
        
        console.log('[FormField] Registrando uso:', data.domain, data.field, data.value);
        await saveValue(data.domain, data.field, data.value);
      } catch (err) {
        console.error('[FormField] Erro ao registrar uso:', err);
      }
      return true;
    }
    
    return false;
  }, [getSuggestions, saveValue]);

  return {
    getFormFieldScript,
    handleFormFieldMessage
  };
}

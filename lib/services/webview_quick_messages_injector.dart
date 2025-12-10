import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/quick_message.dart';
import 'dart:convert';

/// Serviço para injetar suporte a mensagens rápidas no WebView
class WebViewQuickMessagesInjector {
  List<QuickMessage> _messages = [];
  String _activationKey = '/';

  /// Injeta o script no WebView com as mensagens fornecidas
  /// ✅ Agora recebe mensagens como parâmetro para não depender do Supabase
  Future<void> injectQuickMessagesSupport(
    InAppWebViewController controller, {
    String activationKey = '/',
    List<QuickMessage>? messages,
    String? tabName,
    String? url,
  }) async {
    _activationKey = activationKey;
    _messages = messages ?? [];
    
    // ✅ Log detalhado com informações da aba/janela
    debugPrint('[QuickMessages] 📤 Injetando script');
    debugPrint('[QuickMessages]   └─ Aba/Janela: ${tabName ?? "N/A"}');
    debugPrint('[QuickMessages]   └─ URL: ${url ?? "N/A"}');
    debugPrint('[QuickMessages]   └─ Tecla de ativação: "$_activationKey"');
    debugPrint('[QuickMessages]   └─ Mensagens: ${_messages.length}');
    if (_messages.isNotEmpty) {
      debugPrint('[QuickMessages]   └─ Atalhos: ${_messages.map((m) => m.shortcut).join(", ")}');
      debugPrint('[QuickMessages]   └─ Exemplo de uso: Digite "$_activationKey" + atalho (ex: "$_activationKey${_messages.first.shortcut}")');
    }
    
    // Cria o script JavaScript com todas as mensagens
    final script = _createInjectionScript();
    
    try {
      await controller.evaluateJavascript(source: script);
      // Aguarda um pouco para garantir que o script foi executado
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('[QuickMessages] ✅ Script injetado com sucesso em: ${tabName ?? "N/A"}');
    } catch (e) {
      debugPrint('[QuickMessages] ❌ Erro ao injetar script em ${tabName ?? "N/A"}: $e');
    }
  }

  /// Cria o script JavaScript para detectar e substituir atalhos
  String _createInjectionScript() {
    // Cria um mapa de atalhos para mensagens
    final shortcutsMap = <String, String>{};
    for (final message in _messages) {
      shortcutsMap[message.shortcut.toLowerCase()] = message.message;
    }

    final shortcutsJson = jsonEncode(shortcutsMap);
    final activationKeyEscaped = _activationKey.replaceAll("'", "\\'");

    // Escapa caracteres especiais no activationKey para uso em regex
    final escapedKey = _activationKey.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) => '\\${match.group(0)}');
    
    return '''
(function() {
  const activationKey = '$activationKeyEscaped';
  const shortcuts = $shortcutsJson;
  let lastInputValue = '';
  let debounceTimer = null;
  let isProcessingShortcut = false; // ✅ Flag para evitar processamento duplicado
  let lastProcessedShortcut = null; // ✅ Rastreia o último atalho processado para evitar duplicação
  let lastProcessedTime = 0; // ✅ Timestamp do último processamento

  // ✅ Log de inicialização
  console.log('[QuickMessages] Script injetado com sucesso');
  console.log('[QuickMessages] Activation key:', activationKey);
  console.log('[QuickMessages] Shortcuts disponíveis:', Object.keys(shortcuts).length);
  console.log('[QuickMessages] Shortcuts:', shortcuts);

  function replaceShortcut(element, text) {
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      console.log('[QuickMessages] ⏸️ Processamento de atalho em andamento - ignorando replaceShortcut');
      return false;
    }
    
    // ✅ Se um atalho foi processado recentemente (últimos 500ms), ignora para evitar duplicação
    const now = Date.now();
    if (lastProcessedShortcut && (now - lastProcessedTime) < 500) {
      console.log('[QuickMessages] ⏸️ Atalho processado recentemente - ignorando replaceShortcut');
      return false;
    }
    
    const escapedKey = '$escapedKey';
    // Procura pelo padrão no final do texto (onde o usuário está digitando)
    // Procura por tecla_ativação + atalho no final do texto
    const pattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
    const match = text.match(pattern);
    
    console.log('[QuickMessages] 🔍 Verificando texto:', text);
    console.log('[QuickMessages]   └─ Pattern:', pattern);
    console.log('[QuickMessages]   └─ Match encontrado:', match);
    
    if (match && match[1] && shortcuts[match[1].toLowerCase()]) {
      const shortcut = match[1].toLowerCase();
      const message = shortcuts[shortcut];
      console.log('[QuickMessages] ✅✅✅ ATALHO ATIVADO COM SUCESSO ✅✅✅');
      console.log('[QuickMessages]   └─ Tecla de ativação:', activationKey);
      console.log('[QuickMessages]   └─ Atalho digitado:', shortcut);
      console.log('[QuickMessages]   └─ Atalho completo:', activationKey + shortcut);
      console.log('[QuickMessages]   └─ Mensagem encontrada:', message);
      console.log('[QuickMessages]   └─ Substituindo:', match[0], 'por:', message);
      
      // ✅ Marca como processando para evitar duplicação
      isProcessingShortcut = true;
      lastProcessedShortcut = shortcut;
      lastProcessedTime = now;
      
      // ✅ Cancela o timer do listener de input para evitar processamento duplicado
      if (debounceTimer) {
        clearTimeout(debounceTimer);
        debounceTimer = null;
      }
      
      const before = text.substring(0, match.index);
      const after = text.substring(match.index + match[0].length);
      const newText = before + message + after;
      
      console.log('[QuickMessages] ✅ ATALHO ATIVADO - Substituindo:', match[0], 'por:', message);
      
      // Atualiza o valor do campo
      if (element.tagName == 'INPUT' || element.tagName == 'TEXTAREA') {
        console.log('[QuickMessages] Atualizando campo INPUT/TEXTAREA');
        element.value = newText;
        element.setSelectionRange(before.length + message.length, before.length + message.length);
        
        // Dispara eventos para notificar o site
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        console.log('[QuickMessages] ✅ Campo INPUT/TEXTAREA atualizado com sucesso');
      } else if (element.contentEditable == 'true' || element.isContentEditable) {
        console.log('[QuickMessages] Atualizando campo contentEditable');
        
        // Para elementos contentEditable (como no WhatsApp Web)
        // Substitui diretamente o texto completo para garantir que o "/atalho" seja removido
        element.textContent = newText;
        
        // Move o cursor para o final da mensagem inserida
        const range = document.createRange();
        const selection = window.getSelection();
        const textNode = element.firstChild || element;
        if (textNode && textNode.nodeType === Node.TEXT_NODE) {
          const cursorPos = newText.length;
          range.setStart(textNode, cursorPos);
          range.setEnd(textNode, cursorPos);
        } else {
          range.selectNodeContents(element);
          range.collapse(false);
        }
        selection.removeAllRanges();
        selection.addRange(range);
        
        // Dispara eventos para notificar o WhatsApp
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('keyup', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        
        // Tenta disparar eventos específicos do WhatsApp
        if (element.dispatchEvent) {
          const inputEvent = new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: message });
          element.dispatchEvent(inputEvent);
        }
        console.log('[QuickMessages] ✅ Campo contentEditable atualizado com sucesso');
      }
      
      // ✅ Reseta a flag após um pequeno delay para permitir que os eventos sejam processados
      setTimeout(function() {
        isProcessingShortcut = false;
        lastInputValue = newText; // Atualiza o último valor conhecido
      }, 200);
      
      return true;
    } else {
      if (match && match[1]) {
        console.log('[QuickMessages] ⚠️ Atalho digitado mas não encontrado:', match[1].toLowerCase());
        console.log('[QuickMessages] Atalhos disponíveis:', Object.keys(shortcuts));
      }
    }
    return false;
  }

  function handleInput(event) {
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      console.log('[QuickMessages] ⏸️ Processamento de atalho em andamento - ignorando input');
      return;
    }
    
    // ✅ Se um atalho foi processado recentemente (últimos 500ms), ignora para evitar duplicação
    const now = Date.now();
    if (lastProcessedShortcut && (now - lastProcessedTime) < 500) {
      console.log('[QuickMessages] ⏸️ Atalho processado recentemente - ignorando input');
      return;
    }
    
    const element = event.target;
    if (!element) {
      console.log('[QuickMessages] ⚠️ Elemento não encontrado');
      return;
    }
    
    const text = element.value || element.textContent || element.innerText || '';
    const lastChar = text.length > 0 ? text[text.length - 1] : '';
    
    // ✅ LOG: Detecta quando a tecla de ativação é digitada
    if (lastChar === activationKey) {
      console.log('[QuickMessages] 🔑 TECLA DE ATIVAÇÃO PRESSIONADA:', activationKey);
      console.log('[QuickMessages]   └─ Texto atual:', text);
      console.log('[QuickMessages]   └─ Aguardando atalho...');
    }
    
    // ✅ LOG: Detecta quando um atalho está sendo digitado após a tecla de ativação
    const escapedKey = '$escapedKey';
    const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
    const shortcutMatch = text.match(shortcutPattern);
    if (shortcutMatch && shortcutMatch[1]) {
      const detectedShortcut = shortcutMatch[1].toLowerCase();
      console.log('[QuickMessages] ⌨️ ATALHO DETECTADO:', detectedShortcut);
      console.log('[QuickMessages]   └─ Tecla de ativação:', activationKey);
      console.log('[QuickMessages]   └─ Atalho digitado:', detectedShortcut);
      console.log('[QuickMessages]   └─ Texto completo:', text);
      console.log('[QuickMessages]   └─ Atalho existe?', shortcuts.hasOwnProperty(detectedShortcut));
    }
    
    // Se o texto não mudou, ignora
    if (text == lastInputValue) return;
    lastInputValue = text;
    
    // Cancela timer anterior
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }
    
    // Se pressionou espaço ou Enter, substitui imediatamente
    if (event.type == 'keyup' && (event.key == ' ' || event.key == 'Enter')) {
      console.log('[QuickMessages] 🔵 Tecla espaço/Enter pressionada - verificando atalho');
      replaceShortcut(element, text);
      return;
    }
    
    // Caso contrário, aguarda 800ms antes de verificar o atalho
    // Isso dá tempo suficiente para o usuário digitar o atalho completo
    debounceTimer = setTimeout(function() {
      console.log('[QuickMessages] ⏱️ Timer expirado (800ms) - verificando atalho');
      replaceShortcut(element, text);
    }, 800);
  }

  // ✅ Função para inserir texto onde o cursor estiver, removendo o "/atalho" antes
  function insertTextAtCursor(text, shortcutToRemove) {
    const activeElement = document.activeElement;
    if (!activeElement) {
      console.log('[QuickMessages] ⚠️ Nenhum elemento ativo encontrado');
      return false;
    }
    
    // Verifica se é um campo de texto editável
    const isEditable = activeElement.tagName === 'INPUT' || 
                       activeElement.tagName === 'TEXTAREA' || 
                       activeElement.contentEditable === 'true' || 
                       activeElement.isContentEditable;
    
    if (!isEditable) {
      console.log('[QuickMessages] ⚠️ Elemento ativo não é editável:', activeElement.tagName);
      return false;
    }
    
    console.log('[QuickMessages] 📝 Inserindo texto no elemento:', activeElement.tagName);
    console.log('[QuickMessages]   └─ Removendo:', shortcutToRemove);
    
    if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
      const currentText = activeElement.value || '';
      const start = activeElement.selectionStart || 0;
      const end = activeElement.selectionEnd || 0;
      
      // Procura pelo "/atalho" antes da posição do cursor
      const textBeforeCursor = currentText.substring(0, start);
      const escapedKey = '$escapedKey';
      const shortcutPattern = new RegExp(escapedKey + shortcutToRemove + '\$');
      const match = textBeforeCursor.match(shortcutPattern);
      
      let removeStart = start;
      let removeEnd = start;
      
      if (match && match.index !== undefined) {
        removeStart = match.index;
        removeEnd = start;
        console.log('[QuickMessages]   └─ Encontrado "/atalho" na posição:', removeStart, 'até', removeEnd);
      } else {
        // Se não encontrou, tenta remover do final do texto antes do cursor
        const shortcutLength = (activationKey + shortcutToRemove).length;
        removeStart = Math.max(0, start - shortcutLength);
        removeEnd = start;
        console.log('[QuickMessages]   └─ Removendo últimos caracteres antes do cursor');
      }
      
      const before = currentText.substring(0, removeStart);
      const after = currentText.substring(end);
      const newText = before + text + after;
      
      activeElement.value = newText;
      const newCursorPos = before.length + text.length;
      activeElement.setSelectionRange(newCursorPos, newCursorPos);
      
      // Dispara eventos
      activeElement.dispatchEvent(new Event('input', { bubbles: true }));
      activeElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log('[QuickMessages] ✅ Texto inserido em INPUT/TEXTAREA');
      return true;
    } else if (activeElement.contentEditable === 'true' || activeElement.isContentEditable) {
      // Para WhatsApp, usa uma abordagem mais simples e direta
      const currentText = activeElement.textContent || activeElement.innerText || '';
      const escapedKey = '$escapedKey';
      const shortcutPattern = new RegExp(escapedKey + shortcutToRemove + '\$');
      const match = currentText.match(shortcutPattern);
      
      let newText = currentText;
      if (match && match.index !== undefined) {
        // Remove o "/atalho" e insere a mensagem
        const before = currentText.substring(0, match.index);
        const after = currentText.substring(match.index + match[0].length);
        newText = before + text + after;
      } else {
        // Se não encontrou o padrão, tenta remover do final
        const shortcutLength = (activationKey + shortcutToRemove).length;
        const before = currentText.substring(0, Math.max(0, currentText.length - shortcutLength));
        newText = before + text;
      }
      
      // Substitui o texto completo
      activeElement.textContent = newText;
      
      // Move o cursor para o final
      const selection = window.getSelection();
      const range = document.createRange();
      const textNode = activeElement.firstChild || activeElement;
      if (textNode && textNode.nodeType === Node.TEXT_NODE) {
        const cursorPos = newText.length;
        range.setStart(textNode, cursorPos);
        range.setEnd(textNode, cursorPos);
      } else {
        range.selectNodeContents(activeElement);
        range.collapse(false);
      }
      selection.removeAllRanges();
      selection.addRange(range);
      
      // Dispara eventos
      activeElement.dispatchEvent(new Event('input', { bubbles: true }));
      activeElement.dispatchEvent(new Event('keyup', { bubbles: true }));
      activeElement.dispatchEvent(new Event('change', { bubbles: true }));
      console.log('[QuickMessages] ✅ Texto inserido em contentEditable');
      return true;
    }
    
    return false;
  }

  // ✅ Listener global de teclado para detectar "/" + atalho mesmo sem campo de texto detectado
  let globalTypedText = '';
  let globalDebounceTimer = null;
  
  function handleGlobalKeydown(event) {
    // Ignora se for uma tecla especial (Ctrl, Alt, Shift, etc) ou se não for uma tecla imprimível
    if (event.ctrlKey || event.altKey || event.metaKey || event.key.length !== 1) {
      // Se pressionou Enter ou Space e está digitando um atalho, processa
      if ((event.key === 'Enter' || event.key === ' ') && globalTypedText.startsWith(activationKey)) {
        const escapedKey = '$escapedKey';
        const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
        const match = globalTypedText.match(shortcutPattern);
        if (match && match[1] && shortcuts[match[1].toLowerCase()]) {
          event.preventDefault();
          event.stopPropagation();
          const shortcut = match[1].toLowerCase();
          const message = shortcuts[shortcut];
          isProcessingShortcut = true;
          insertTextAtCursor(message, shortcut);
          setTimeout(function() {
            isProcessingShortcut = false;
          }, 100);
          globalTypedText = '';
        }
      }
      return;
    }
    
    // Se pressionou a tecla de ativação
    if (event.key === activationKey) {
      globalTypedText = activationKey;
      console.log('[QuickMessages] 🔑 TECLA DE ATIVAÇÃO PRESSIONADA (global):', activationKey);
      
      // Cancela timer anterior
      if (globalDebounceTimer) {
        clearTimeout(globalDebounceTimer);
      }
      
      // Aguarda para ver se o usuário vai digitar um atalho
      globalDebounceTimer = setTimeout(function() {
        if (globalTypedText === activationKey) {
          // Se ainda é só a tecla de ativação, limpa
          globalTypedText = '';
        }
      }, 1000);
      return;
    }
    
    // Se já digitou a tecla de ativação, continua acumulando
    if (globalTypedText.startsWith(activationKey)) {
      globalTypedText += event.key;
      console.log('[QuickMessages] ⌨️ Texto acumulado (global):', globalTypedText);
      
      // Cancela timer anterior
      if (globalDebounceTimer) {
        clearTimeout(globalDebounceTimer);
      }
      
      // Verifica se é um atalho válido
      const escapedKey = '$escapedKey';
      const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
      const match = globalTypedText.match(shortcutPattern);
      
      if (match && match[1]) {
        const shortcut = match[1].toLowerCase();
        console.log('[QuickMessages] ⌨️ ATALHO DETECTADO (global):', shortcut);
        
        if (shortcuts[shortcut]) {
          const message = shortcuts[shortcut];
          console.log('[QuickMessages] ✅✅✅ ATALHO ENCONTRADO (global) ✅✅✅');
          console.log('[QuickMessages]   └─ Atalho:', shortcut);
          console.log('[QuickMessages]   └─ Mensagem:', message);
          
          // ✅ Verifica se já foi processado recentemente para evitar duplicação
          const now = Date.now();
          if (lastProcessedShortcut === shortcut && (now - lastProcessedTime) < 500) {
            console.log('[QuickMessages] ⏸️ Atalho já processado recentemente - ignorando');
            globalTypedText = '';
            return;
          }
          
          // ✅ Marca como processando para evitar duplicação
          isProcessingShortcut = true;
          lastProcessedShortcut = shortcut;
          lastProcessedTime = now;
          
          // ✅ Cancela o timer do listener de input para evitar processamento duplicado
          if (debounceTimer) {
            clearTimeout(debounceTimer);
            debounceTimer = null;
          }
          
          // Previne o comportamento padrão para não inserir o "/" + atalho
          event.preventDefault();
          event.stopPropagation();
          
          // Tenta inserir onde o cursor estiver, removendo o "/atalho"
          if (insertTextAtCursor(message, shortcut)) {
            console.log('[QuickMessages] ✅ Texto inserido via insertTextAtCursor');
          } else {
            // Se não conseguiu inserir, tenta no elemento ativo diretamente
            const activeElement = document.activeElement;
            if (activeElement) {
              const currentText = activeElement.value || activeElement.textContent || activeElement.innerText || '';
              
              // Procura pelo "/atalho" no texto e remove antes de inserir
              const escapedKey = '$escapedKey';
              const shortcutPattern = new RegExp(escapedKey + shortcut + '\$');
              const match = currentText.match(shortcutPattern);
              
              let before = currentText;
              if (match && match.index !== undefined) {
                before = currentText.substring(0, match.index);
                console.log('[QuickMessages]   └─ Removendo "/atalho" encontrado na posição:', match.index);
              } else {
                // Tenta remover do final
                const shortcutLength = (activationKey + shortcut).length;
                before = currentText.substring(0, Math.max(0, currentText.length - shortcutLength));
                console.log('[QuickMessages]   └─ Removendo últimos caracteres');
              }
              
              if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
                activeElement.value = before + message;
                activeElement.setSelectionRange(before.length + message.length, before.length + message.length);
                activeElement.dispatchEvent(new Event('input', { bubbles: true }));
                activeElement.dispatchEvent(new Event('change', { bubbles: true }));
                console.log('[QuickMessages] ✅ Texto inserido diretamente em INPUT/TEXTAREA');
              } else if (activeElement.contentEditable === 'true' || activeElement.isContentEditable) {
                // Para WhatsApp, substitui o texto completo diretamente
                activeElement.textContent = before + message;
                
                // Move o cursor para o final
                const range = document.createRange();
                const selection = window.getSelection();
                const textNode = activeElement.firstChild || activeElement;
                if (textNode && textNode.nodeType === Node.TEXT_NODE) {
                  const cursorPos = before.length + message.length;
                  range.setStart(textNode, cursorPos);
                  range.setEnd(textNode, cursorPos);
                } else {
                  range.selectNodeContents(activeElement);
                  range.collapse(false);
                }
                selection.removeAllRanges();
                selection.addRange(range);
                
                activeElement.dispatchEvent(new Event('input', { bubbles: true }));
                activeElement.dispatchEvent(new Event('keyup', { bubbles: true }));
                activeElement.dispatchEvent(new Event('change', { bubbles: true }));
                console.log('[QuickMessages] ✅ Texto inserido diretamente em contentEditable');
              } else {
                console.log('[QuickMessages] ⚠️ Não foi possível inserir texto - elemento não é editável');
              }
            } else {
              console.log('[QuickMessages] ⚠️ Não foi possível inserir texto - nenhum elemento ativo');
            }
          }
          
          // ✅ Atualiza lastInputValue para evitar que o listener de input processe novamente
          const activeElement = document.activeElement;
          if (activeElement) {
            const finalText = activeElement.value || activeElement.textContent || activeElement.innerText || '';
            lastInputValue = finalText;
          }
          
          // ✅ Reseta a flag após um pequeno delay
          setTimeout(function() {
            isProcessingShortcut = false;
          }, 200);
          
          globalTypedText = '';
          return;
        } else {
          // Se não encontrou o atalho ainda, aguarda mais um pouco
          globalDebounceTimer = setTimeout(function() {
            const finalMatch = globalTypedText.match(shortcutPattern);
            if (finalMatch && finalMatch[1] && shortcuts[finalMatch[1].toLowerCase()]) {
              const finalShortcut = finalMatch[1].toLowerCase();
              const finalMessage = shortcuts[finalShortcut];
              isProcessingShortcut = true;
              insertTextAtCursor(finalMessage, finalShortcut);
              setTimeout(function() {
                isProcessingShortcut = false;
              }, 100);
            }
            globalTypedText = '';
          }, 800);
        }
      }
    }
  }
  
  // Adiciona listener global de teclado
  document.addEventListener('keydown', handleGlobalKeydown, true);
  console.log('[QuickMessages] ✅ Listener global de teclado adicionado');

  // Adiciona listeners para todos os campos de texto existentes
  function attachListeners() {
    const inputs = document.querySelectorAll('input[type="text"], input[type="search"], textarea, [contenteditable="true"]');
    console.log('[QuickMessages] Encontrados', inputs.length, 'campos de texto');
    inputs.forEach(function(input, index) {
      if (!input.hasAttribute('data-quick-messages-listener')) {
        input.setAttribute('data-quick-messages-listener', 'true');
        input.addEventListener('input', handleInput, true);
        input.addEventListener('keyup', handleInput, true);
        console.log('[QuickMessages] Listener adicionado ao campo', index, input.tagName, input.type || 'contentEditable');
      }
    });
  }

  // Observa novos elementos sendo adicionados ao DOM (importante para SPAs como WhatsApp)
  const observer = new MutationObserver(function(mutations) {
    console.log('[QuickMessages] DOM modificado - reanexando listeners');
    attachListeners();
  });

  // Inicia observação
  if (document.body) {
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
    console.log('[QuickMessages] Observer iniciado no document.body');
  } else {
    console.log('[QuickMessages] ⚠️ document.body não encontrado');
  }

  // Anexa listeners aos elementos existentes
  if (document.readyState == 'loading') {
    console.log('[QuickMessages] Aguardando DOMContentLoaded');
    document.addEventListener('DOMContentLoaded', function() {
      console.log('[QuickMessages] DOMContentLoaded - anexando listeners');
      attachListeners();
    });
  } else {
    console.log('[QuickMessages] DOM já carregado - anexando listeners imediatamente');
    attachListeners();
  }
  
  console.log('[QuickMessages] ✅ Sistema de mensagens rápidas inicializado');
})();
''';
  }

  /// Atualiza as mensagens e reinjeta o script
  Future<void> refreshAndInject(
    InAppWebViewController controller, {
    List<QuickMessage>? messages,
    String? tabName,
    String? url,
  }) async {
    await injectQuickMessagesSupport(
      controller,
      activationKey: _activationKey,
      messages: messages,
      tabName: tabName,
      url: url,
    );
  }
}

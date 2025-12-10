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
  let processingElement = null; // ✅ Elemento que está sendo processado para evitar duplicação
  let shortcutProcessed = false; // ✅ Flag que indica que um atalho foi processado - só reseta quando "/" for digitado novamente

  // ✅ Log de inicialização
  console.log('[QuickMessages] Script injetado com sucesso');
  console.log('[QuickMessages] Activation key:', activationKey);
  console.log('[QuickMessages] Shortcuts disponíveis:', Object.keys(shortcuts).length);
  console.log('[QuickMessages] Shortcuts:', shortcuts);

  function replaceShortcut(element, text) {
    // ✅ Se um atalho já foi processado, para imediatamente - só volta quando "/" for digitado novamente
    if (shortcutProcessed) {
      console.log('[QuickMessages] ⏸️ Atalho já processado - aguardando nova tecla de ativação');
      return false;
    }
    
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      console.log('[QuickMessages] ⏸️ Processamento de atalho em andamento - ignorando replaceShortcut');
      return false;
    }
    
    // ✅ Se este elemento específico já está sendo processado, ignora
    if (processingElement === element) {
      console.log('[QuickMessages] ⏸️ Elemento já está sendo processado - ignorando replaceShortcut');
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
      shortcutProcessed = true; // ✅ Marca que um atalho foi processado - só reseta quando "/" for digitado novamente
      keysTypedAfterActivation = 0; // ✅ Reseta o contador quando um atalho válido é encontrado
      processingElement = element;
      lastProcessedShortcut = shortcut;
      lastProcessedTime = now;
      
      // ✅ Cancela o timer do listener de input para evitar processamento duplicado
      if (debounceTimer) {
        clearTimeout(debounceTimer);
        debounceTimer = null;
      }
      
      // ✅ Cancela o timer global também
      if (globalDebounceTimer) {
        clearTimeout(globalDebounceTimer);
        globalDebounceTimer = null;
      }
      
      // ✅ Limpa o texto acumulado global para evitar processamento duplicado
      globalTypedText = '';
      
      const before = text.substring(0, match.index);
      const after = text.substring(match.index + match[0].length);
      const newText = before + message + after;
      
      // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
      lastInputValue = newText;
      
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
        processingElement = null;
        lastInputValue = newText; // Atualiza o último valor conhecido
      }, 300);
      
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
    const element = event.target;
    
    if (!element) {
      console.log('[QuickMessages] ⚠️ Elemento não encontrado');
      return;
    }
    
    const text = element.value || element.textContent || element.innerText || '';
    const lastChar = text.length > 0 ? text[text.length - 1] : '';
    
    // ✅ LOG: Detecta quando a tecla de ativação é digitada - reseta a flag para permitir novo processamento
    if (lastChar === activationKey) {
      shortcutProcessed = false; // ✅ Reseta a flag quando "/" é digitado novamente
      keysTypedAfterActivation = 0; // ✅ Reseta o contador quando "/" é digitado
      console.log('[QuickMessages] 🔑 TECLA DE ATIVAÇÃO PRESSIONADA:', activationKey);
      console.log('[QuickMessages]   └─ Texto atual:', text);
      console.log('[QuickMessages]   └─ Aguardando atalho...');
    }
    
    // ✅ Se um atalho já foi processado, para imediatamente - só volta quando "/" for digitado novamente
    if (shortcutProcessed) {
      console.log('[QuickMessages] ⏸️ Atalho já processado - aguardando nova tecla de ativação');
      return;
    }
    
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      console.log('[QuickMessages] ⏸️ Processamento de atalho em andamento - ignorando input');
      return;
    }
    
    // ✅ Se este elemento específico já está sendo processado, ignora
    if (processingElement === element) {
      console.log('[QuickMessages] ⏸️ Elemento já está sendo processado - ignorando input');
      return;
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
    
    // Cancela timer anterior (se existir)
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
    
    // Se pressionou espaço ou Enter, substitui imediatamente
    if (event.type == 'keyup' && (event.key == ' ' || event.key == 'Enter')) {
      console.log('[QuickMessages] 🔵 Tecla espaço/Enter pressionada - verificando atalho');
      replaceShortcut(element, text);
      return;
    }
    
    // ✅ Verifica imediatamente se há um atalho válido (sem timer)
    // O sistema agora funciona apenas com base no contador de teclas (até 5 teclas)
    replaceShortcut(element, text);
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
      
      // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
      lastInputValue = newText;
      
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
      
      // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
      lastInputValue = newText;
      
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
  let keysTypedAfterActivation = 0; // ✅ Contador de teclas digitadas após "/"
  const MAX_KEYS_AFTER_ACTIVATION = 5; // ✅ Limite máximo de teclas após "/"
  
  function handleGlobalKeydown(event) {
    // Ignora se for uma tecla especial (Ctrl, Alt, Shift, etc) ou se não for uma tecla imprimível
    if (event.ctrlKey || event.altKey || event.metaKey || event.key.length !== 1) {
      // Se pressionou Enter ou Space e está digitando um atalho, processa
      if ((event.key === 'Enter' || event.key === ' ') && globalTypedText.startsWith(activationKey)) {
        // ✅ Se um atalho já foi processado, para imediatamente
        if (shortcutProcessed) {
          globalTypedText = '';
          return;
        }
        
        const escapedKey = '$escapedKey';
        const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
        const match = globalTypedText.match(shortcutPattern);
        if (match && match[1] && shortcuts[match[1].toLowerCase()]) {
          const shortcut = match[1].toLowerCase();
          
          // ✅ Verifica se já está processando para evitar duplicação
          if (isProcessingShortcut) {
            globalTypedText = '';
            return;
          }
          
          event.preventDefault();
          event.stopPropagation();
          const message = shortcuts[shortcut];
          const activeElement = document.activeElement;
          isProcessingShortcut = true;
          shortcutProcessed = true; // ✅ Marca que um atalho foi processado - só reseta quando "/" for digitado novamente
          processingElement = activeElement;
          lastProcessedShortcut = shortcut;
          lastProcessedTime = Date.now();
          globalTypedText = '';
          
          // ✅ Cancela timers para evitar processamento duplicado
          if (debounceTimer) {
            clearTimeout(debounceTimer);
            debounceTimer = null;
          }
          if (globalDebounceTimer) {
            clearTimeout(globalDebounceTimer);
            globalDebounceTimer = null;
          }
          
          insertTextAtCursor(message, shortcut);
          setTimeout(function() {
            isProcessingShortcut = false;
            processingElement = null;
          }, 300);
        }
      }
      return;
    }
    
    // Se pressionou a tecla de ativação
    if (event.key === activationKey) {
      shortcutProcessed = false; // ✅ Reseta a flag quando "/" é digitado novamente - permite novo processamento
      keysTypedAfterActivation = 0; // ✅ Reseta o contador de teclas quando "/" é digitado
      globalTypedText = activationKey;
      console.log('[QuickMessages] 🔑 TECLA DE ATIVAÇÃO PRESSIONADA (global):', activationKey);
      console.log('[QuickMessages]   └─ Contador de teclas resetado. Aguardando até ' + MAX_KEYS_AFTER_ACTIVATION + ' teclas...');
      
      // Cancela timer anterior
      if (globalDebounceTimer) {
        clearTimeout(globalDebounceTimer);
        globalDebounceTimer = null;
      }
      return;
    }
    
    // Se já digitou a tecla de ativação, continua acumulando
    if (globalTypedText.startsWith(activationKey)) {
      // ✅ Se um atalho já foi processado, para imediatamente - só volta quando "/" for digitado novamente
      if (shortcutProcessed) {
        console.log('[QuickMessages] ⏸️ Atalho já processado - aguardando nova tecla de ativação');
        return;
      }
      
      // ✅ Incrementa o contador de teclas digitadas após "/"
      keysTypedAfterActivation++;
      console.log('[QuickMessages] ⌨️ Tecla digitada após "/":', keysTypedAfterActivation, '/', MAX_KEYS_AFTER_ACTIVATION);
      
      // ✅ Se excedeu o limite de teclas, desativa e limpa
      if (keysTypedAfterActivation > MAX_KEYS_AFTER_ACTIVATION) {
        console.log('[QuickMessages] ⚠️ Limite de ' + MAX_KEYS_AFTER_ACTIVATION + ' teclas atingido - desativando. Digite "/" novamente para ativar.');
        globalTypedText = '';
        keysTypedAfterActivation = 0;
        if (globalDebounceTimer) {
          clearTimeout(globalDebounceTimer);
          globalDebounceTimer = null;
        }
        return;
      }
      
      globalTypedText += event.key;
      console.log('[QuickMessages] ⌨️ Texto acumulado (global):', globalTypedText);
      
      // Verifica se é um atalho válido (sem timer - verifica imediatamente)
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
          
          // ✅ Verifica se já está processando para evitar duplicação
          if (isProcessingShortcut) {
            console.log('[QuickMessages] ⏸️ Processamento já em andamento - ignorando');
            globalTypedText = '';
            keysTypedAfterActivation = 0;
            return;
          }
          
          // ✅ Marca como processando para evitar duplicação ANTES de inserir o texto
          isProcessingShortcut = true;
          shortcutProcessed = true; // ✅ Marca que um atalho foi processado - só reseta quando "/" for digitado novamente
          keysTypedAfterActivation = 0; // ✅ Reseta o contador quando um atalho válido é encontrado
          const activeElement = document.activeElement;
          processingElement = activeElement;
          lastProcessedShortcut = shortcut;
          lastProcessedTime = Date.now();
          
          // ✅ Limpa o texto acumulado imediatamente para evitar processamento duplicado
          globalTypedText = '';
          
          // ✅ Cancela o timer do listener de input para evitar processamento duplicado
          if (debounceTimer) {
            clearTimeout(debounceTimer);
            debounceTimer = null;
          }
          
          // ✅ Cancela o timer global também (se existir)
          if (globalDebounceTimer) {
            clearTimeout(globalDebounceTimer);
            globalDebounceTimer = null;
          }
          
          // Previne o comportamento padrão para não inserir o "/" + atalho
          event.preventDefault();
          event.stopPropagation();
          
          // ✅ Calcula o texto final ANTES de inserir para atualizar lastInputValue imediatamente
          let finalTextToInsert = message;
          if (activeElement) {
            const currentText = activeElement.value || activeElement.textContent || activeElement.innerText || '';
            const escapedKey = '$escapedKey';
            const shortcutPattern = new RegExp(escapedKey + shortcut + '\$');
            const match = currentText.match(shortcutPattern);
            
            if (match && match.index !== undefined) {
              const before = currentText.substring(0, match.index);
              finalTextToInsert = before + message;
            } else {
              const shortcutLength = (activationKey + shortcut).length;
              const before = currentText.substring(0, Math.max(0, currentText.length - shortcutLength));
              finalTextToInsert = before + message;
            }
            
            // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
            lastInputValue = finalTextToInsert;
          }
          
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
              
              // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
              const finalText = before + message;
              lastInputValue = finalText;
              
              if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
                activeElement.value = finalText;
                activeElement.setSelectionRange(before.length + message.length, before.length + message.length);
                activeElement.dispatchEvent(new Event('input', { bubbles: true }));
                activeElement.dispatchEvent(new Event('change', { bubbles: true }));
                console.log('[QuickMessages] ✅ Texto inserido diretamente em INPUT/TEXTAREA');
              } else if (activeElement.contentEditable === 'true' || activeElement.isContentEditable) {
                // Para WhatsApp, substitui o texto completo diretamente
                activeElement.textContent = finalText;
                
                // Move o cursor para o final
                const range = document.createRange();
                const selection = window.getSelection();
                const textNode = activeElement.firstChild || activeElement;
                if (textNode && textNode.nodeType === Node.TEXT_NODE) {
                  const cursorPos = finalText.length;
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
          
          // ✅ Reseta a flag após um pequeno delay
          setTimeout(function() {
            isProcessingShortcut = false;
            processingElement = null;
          }, 300);
          
          return;
        } else {
          // ✅ Se não encontrou um atalho válido ainda, apenas continua aguardando mais teclas
          // Não há timer - o sistema só desativa quando atingir 5 teclas sem encontrar atalho válido
          console.log('[QuickMessages] ⏳ Atalho "' + shortcut + '" não encontrado. Aguardando mais teclas... (' + keysTypedAfterActivation + '/' + MAX_KEYS_AFTER_ACTIVATION + ')');
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

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
  let lastInsertedShortcut = null; // ✅ Último atalho que foi inserido com sucesso
  let lastInsertedTime = 0; // ✅ Timestamp da última inserção bem-sucedida
  const MIN_DELAY_AFTER_INSERTION = 500; // ✅ Delay mínimo em ms antes de aceitar novo "/" após inserção

  // ✅ Função auxiliar para gerar timestamp com milissegundos
  function getTimestamp() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    const milliseconds = String(now.getMilliseconds()).padStart(3, '0');
    return hours + ':' + minutes + ':' + seconds + '.' + milliseconds;
  }

  // ✅ Função auxiliar para log com timestamp
  function log(message) {
    console.log('[' + getTimestamp() + '] [QuickMessages] ' + message);
  }

  // ✅ Log de inicialização
  log('Script injetado com sucesso');
  log('Activation key: ' + activationKey);
  log('Shortcuts disponíveis: ' + Object.keys(shortcuts).length);
  log('Shortcuts: ' + JSON.stringify(shortcuts));

  function replaceShortcut(element, text) {
    // ✅ Se um atalho já foi processado, para imediatamente - só volta quando "/" for digitado novamente
    if (shortcutProcessed) {
      log('⏸️ Atalho já processado - aguardando nova tecla de ativação');
      return false;
    }
    
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      log('⏸️ Processamento de atalho em andamento - ignorando replaceShortcut');
      return false;
    }
    
    // ✅ Se este elemento específico já está sendo processado, ignora
    if (processingElement === element) {
      log('⏸️ Elemento já está sendo processado - ignorando replaceShortcut');
      return false;
    }
    
    const escapedKey = '$escapedKey';
    // Procura pelo padrão no final do texto (onde o usuário está digitando)
    // Procura por tecla_ativação + atalho no final do texto
    const pattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
    const match = text.match(pattern);
    
    log('🔍 Verificando texto: ' + text);
    log('   └─ Pattern: ' + pattern);
    log('   └─ Match encontrado: ' + (match ? match[0] : 'null'));
    
    if (match && match[1] && shortcuts[match[1].toLowerCase()]) {
      const shortcut = match[1].toLowerCase();
      const message = shortcuts[shortcut];
      
      // ✅ Verifica ANTES de processar se este mesmo atalho foi inserido recentemente (últimos 1000ms)
      const now = Date.now();
      if (lastInsertedShortcut === shortcut && (now - lastInsertedTime) < 1000) {
        log('⏸️ Atalho "' + shortcut + '" foi inserido recentemente (' + (now - lastInsertedTime) + 'ms atrás) - ignorando para evitar duplicação');
        return false;
      }
      
      // ✅ Verifica se um atalho já foi processado - para imediatamente
      if (shortcutProcessed) {
        log('⏸️ Atalho já processado - aguardando nova tecla de ativação');
        return false;
      }
      
      // ✅ Verifica se já está processando para evitar duplicação
      if (isProcessingShortcut) {
        log('⏸️ Processamento já em andamento - ignorando replaceShortcut');
        return false;
      }
      
      // ✅ Verifica se o texto já contém a mensagem completa (pode ter sido inserida por outro listener)
      const currentText = element.value || element.textContent || element.innerText || '';
      if (currentText.includes(message) && currentText.length >= message.length) {
        // Verifica se a mensagem está no final do texto (onde esperamos que esteja)
        const messageAtEnd = currentText.substring(Math.max(0, currentText.length - message.length)) === message;
        if (messageAtEnd) {
          log('⏸️ Mensagem já está presente no campo (possivelmente inserida por outro listener) - ignorando');
          // Marca como processado para evitar novas tentativas
          shortcutProcessed = true;
          lastInsertedShortcut = shortcut;
          lastInsertedTime = Date.now();
          return false;
        }
      }
      
      log('✅✅✅ ATALHO ATIVADO COM SUCESSO ✅✅✅');
      log('   └─ Tecla de ativação: ' + activationKey);
      log('   └─ Atalho digitado: ' + shortcut);
      log('   └─ Atalho completo: ' + activationKey + shortcut);
      log('   └─ Mensagem encontrada: ' + message.substring(0, 50) + '...');
      log('   └─ Substituindo: ' + match[0] + ' por: ' + message.substring(0, 50) + '...');
      
      // ✅ Marca como processando e processado IMEDIATAMENTE para evitar duplicação
      // Isso bloqueia outros listeners de tentar processar o mesmo atalho
      isProcessingShortcut = true;
      shortcutProcessed = true; // ✅ Marca IMEDIATAMENTE para bloquear outros listeners
      keysTypedAfterActivation = 0; // ✅ Reseta o contador quando um atalho válido é encontrado
      processingElement = element;
      lastProcessedShortcut = shortcut;
      lastProcessedTime = Date.now();
      // ✅ NÃO marca lastInsertedShortcut aqui - será marcado APENAS após inserção bem-sucedida
      
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
      
      log('✅ ATALHO ATIVADO - Substituindo: ' + match[0] + ' por: ' + message.substring(0, 50) + '...');
      
      // ✅ Insere a mensagem imediatamente sem delay
      // Atualiza o valor do campo
      if (element.tagName == 'INPUT' || element.tagName == 'TEXTAREA') {
        log('Atualizando campo INPUT/TEXTAREA');
        element.value = newText;
        element.setSelectionRange(before.length + message.length, before.length + message.length);
        
        // Dispara eventos para notificar o site
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        
        // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
        lastInsertedShortcut = shortcut;
        lastInsertedTime = Date.now();
        
        log('✅ Campo INPUT/TEXTAREA atualizado com sucesso');
        // ✅ shortcutProcessed já foi marcado acima antes de inserir
      } else if (element.contentEditable == 'true' || element.isContentEditable) {
        log('Atualizando campo contentEditable (WhatsApp) - simulando digitação');
        
        // Para WhatsApp Web, simula digitação real caractere por caractere
        element.focus();
        
        // Remove o "/atalho" primeiro usando eventos de teclado
        const shortcutLength = match[0].length;
        for (let i = 0; i < shortcutLength; i++) {
          const backspaceEvent = new KeyboardEvent('keydown', {
            key: 'Backspace',
            code: 'Backspace',
            keyCode: 8,
            which: 8,
            bubbles: true,
            cancelable: true
          });
          element.dispatchEvent(backspaceEvent);
          
          const backspaceUpEvent = new KeyboardEvent('keyup', {
            key: 'Backspace',
            code: 'Backspace',
            keyCode: 8,
            which: 8,
            bubbles: true,
            cancelable: true
          });
          element.dispatchEvent(backspaceUpEvent);
        }
        
        // Aguarda um pouco antes de inserir o texto
        setTimeout(function() {
          // Insere o texto caractere por caractere para simular digitação real
          let charIndex = 0;
          const insertNextChar = function() {
            if (charIndex < message.length) {
              const char = message[charIndex];
              
              // Cria eventos de teclado para cada caractere
              const keydownEvent = new KeyboardEvent('keydown', {
                key: char,
                code: 'Key' + char.toUpperCase(),
                keyCode: char.charCodeAt(0),
                which: char.charCodeAt(0),
                bubbles: true,
                cancelable: true
              });
              
              const keypressEvent = new KeyboardEvent('keypress', {
                key: char,
                code: 'Key' + char.toUpperCase(),
                keyCode: char.charCodeAt(0),
                which: char.charCodeAt(0),
                bubbles: true,
                cancelable: true
              });
              
              const inputEvent = new InputEvent('input', {
                bubbles: true,
                cancelable: true,
                inputType: 'insertText',
                data: char
              });
              
              const keyupEvent = new KeyboardEvent('keyup', {
                key: char,
                code: 'Key' + char.toUpperCase(),
                keyCode: char.charCodeAt(0),
                which: char.charCodeAt(0),
                bubbles: true,
                cancelable: true
              });
              
              // Dispara os eventos na ordem correta
              element.dispatchEvent(keydownEvent);
              element.dispatchEvent(keypressEvent);
              
              // Insere o caractere usando execCommand (mais compatível com WhatsApp)
              document.execCommand('insertText', false, char);
              
              element.dispatchEvent(inputEvent);
              element.dispatchEvent(keyupEvent);
              
              charIndex++;
              
              // Continua com o próximo caractere após um pequeno delay
              if (charIndex < message.length) {
                setTimeout(insertNextChar, 10);
              } else {
                // Quando terminou de inserir todos os caracteres
                element.dispatchEvent(new Event('change', { bubbles: true }));
                
                // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
                lastInsertedShortcut = shortcut;
                lastInsertedTime = Date.now();
                
                log('✅ Campo contentEditable atualizado com sucesso (WhatsApp) - simulação completa');
              }
            }
          };
          
          // Inicia a inserção caractere por caractere
          insertNextChar();
        }, 50);
      }
      
      // ✅ Reseta a flag após um pequeno delay para permitir novos processamentos
      setTimeout(function() {
        isProcessingShortcut = false;
        processingElement = null;
      }, 300);
      
      // ✅ Reseta a flag após um pequeno delay para permitir que os eventos sejam processados
      setTimeout(function() {
        isProcessingShortcut = false;
        processingElement = null;
        lastInputValue = newText; // Atualiza o último valor conhecido
      }, 300);
      
      return true;
    } else {
      if (match && match[1]) {
        log('⚠️ Atalho digitado mas não encontrado: ' + match[1].toLowerCase());
        log('Atalhos disponíveis: ' + Object.keys(shortcuts).join(', '));
      }
    }
    return false;
  }

  function handleInput(event) {
    const element = event.target;
    
    if (!element) {
      log('⚠️ Elemento não encontrado');
      return;
    }
    
    const text = element.value || element.textContent || element.innerText || '';
    const lastChar = text.length > 0 ? text[text.length - 1] : '';
    
    // ✅ LOG: Detecta quando a tecla de ativação é digitada - reseta a flag para permitir novo processamento
    if (lastChar === activationKey) {
      // ✅ Verifica se passou o delay mínimo desde a última inserção
      const now = Date.now();
      if (lastInsertedTime > 0 && (now - lastInsertedTime) < MIN_DELAY_AFTER_INSERTION) {
        const remainingDelay = MIN_DELAY_AFTER_INSERTION - (now - lastInsertedTime);
        log('⏸️ Aguardando ' + remainingDelay + 'ms antes de aceitar novo "/" (delay mínimo após inserção)');
        return;
      }
      
      shortcutProcessed = false; // ✅ Reseta a flag quando "/" é digitado novamente
      isProcessingShortcut = false; // ✅ Reseta a flag de processamento quando "/" é digitado novamente
      processingElement = null; // ✅ Limpa o elemento sendo processado
      keysTypedAfterActivation = 0; // ✅ Reseta o contador quando "/" é digitado
      lastInsertedShortcut = null; // ✅ Limpa o último atalho inserido
      lastInsertedTime = 0; // ✅ Limpa o tempo da última inserção
      log('🔑 TECLA DE ATIVAÇÃO PRESSIONADA: ' + activationKey);
      log('   └─ Texto atual: ' + text);
      log('   └─ Aguardando atalho...');
    }
    
    // ✅ Se um atalho já foi processado, para imediatamente - só volta quando "/" for digitado novamente
    if (shortcutProcessed) {
      log('⏸️ Atalho já processado - aguardando nova tecla de ativação');
      return;
    }
    
    // ✅ Se já está processando um atalho, ignora para evitar duplicação
    if (isProcessingShortcut) {
      log('⏸️ Processamento de atalho em andamento - ignorando input');
      return;
    }
    
    // ✅ Se este elemento específico já está sendo processado, ignora
    if (processingElement === element) {
      log('⏸️ Elemento já está sendo processado - ignorando input');
      return;
    }
    
    // ✅ LOG: Detecta quando um atalho está sendo digitado após a tecla de ativação
    const escapedKey = '$escapedKey';
    const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
    const shortcutMatch = text.match(shortcutPattern);
    if (shortcutMatch && shortcutMatch[1]) {
      const detectedShortcut = shortcutMatch[1].toLowerCase();
      log('⌨️ ATALHO DETECTADO: ' + detectedShortcut);
      log('   └─ Tecla de ativação: ' + activationKey);
      log('   └─ Atalho digitado: ' + detectedShortcut);
      log('   └─ Texto completo: ' + text);
      log('   └─ Atalho existe? ' + shortcuts.hasOwnProperty(detectedShortcut));
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
      log('🔵 Tecla espaço/Enter pressionada - verificando atalho');
      replaceShortcut(element, text);
      return;
    }
    
    // ✅ Verifica imediatamente se há um atalho válido (sem timer)
    // O sistema agora funciona apenas com base no contador de teclas (até 5 teclas)
    replaceShortcut(element, text);
  }

  // ✅ Função para inserir texto onde o cursor estiver, removendo o "/atalho" antes
  function insertTextAtCursor(text, shortcutToRemove, skipProcessedCheck) {
    // ✅ Verifica se este mesmo atalho foi inserido recentemente (últimos 1000ms)
    const now = Date.now();
    if (lastInsertedShortcut === shortcutToRemove && (now - lastInsertedTime) < 1000) {
      log('⏸️ Atalho "' + shortcutToRemove + '" foi inserido recentemente (' + (now - lastInsertedTime) + 'ms atrás) - não inserindo novamente');
      return false;
    }
    
    const activeElement = document.activeElement;
    if (!activeElement) {
      log('⚠️ Nenhum elemento ativo encontrado');
      return false;
    }
    
    // ✅ Verifica se o texto já contém a mensagem completa antes de inserir
    // Esta verificação deve vir ANTES da verificação de processamento para evitar bloqueio desnecessário
    const currentTextCheck = activeElement.value || activeElement.textContent || activeElement.innerText || '';
    if (currentTextCheck.includes(text) && currentTextCheck.length >= text.length) {
      // Verifica se a mensagem está no final do texto
      const messageAtEnd = currentTextCheck.substring(Math.max(0, currentTextCheck.length - text.length)) === text;
      if (messageAtEnd) {
        log('⏸️ Mensagem já está presente no campo - não inserindo novamente');
        // Marca como inserido para evitar novas tentativas
        lastInsertedShortcut = shortcutToRemove;
        lastInsertedTime = Date.now();
        return false;
      }
    }
    
    // ✅ Verifica se já está processando o mesmo atalho no mesmo elemento (mesmo com skipProcessedCheck)
    // Mas só bloqueia se a mensagem NÃO foi inserida ainda (verificação acima já passou)
    // Isso evita que dois listeners tentem inserir simultaneamente, mas permite inserção se o primeiro falhou
    if (isProcessingShortcut && processingElement === activeElement && lastProcessedShortcut === shortcutToRemove) {
      // Se já passou mais de 500ms desde que começou a processar, permite tentar novamente (pode ter falhado)
      const timeSinceProcessing = Date.now() - lastProcessedTime;
      if (timeSinceProcessing < 500) {
        log('⏸️ Atalho "' + shortcutToRemove + '" já está sendo processado neste elemento (há ' + timeSinceProcessing + 'ms) - não inserindo novamente');
        return false;
      } else {
        log('⏰ Processamento iniciado há ' + timeSinceProcessing + 'ms - permitindo nova tentativa (pode ter falhado)');
        // Reseta as flags para permitir nova tentativa
        isProcessingShortcut = false;
        processingElement = null;
      }
    }
    
    // ✅ Se skipProcessedCheck é false E já foi processado E não estamos processando, NÃO insere novamente
    // skipProcessedCheck=true permite que insira mesmo se shortcutProcessed=true quando chamado do listener global
    if (skipProcessedCheck !== true) {
      if (shortcutProcessed && !isProcessingShortcut) {
        log('⏸️ Atalho já processado - não inserindo texto novamente');
        return false;
      }
      
      // ✅ Se já está processando E não é o processamento atual, não insere novamente
      if (isProcessingShortcut && processingElement !== activeElement) {
        log('⏸️ Processamento em andamento em outro elemento - não inserindo texto novamente');
        return false;
      }
    }
    
    // Verifica se é um campo de texto editável
    const isEditable = activeElement.tagName === 'INPUT' || 
                       activeElement.tagName === 'TEXTAREA' || 
                       activeElement.contentEditable === 'true' || 
                       activeElement.isContentEditable;
    
    if (!isEditable) {
      log('⚠️ Elemento ativo não é editável: ' + activeElement.tagName);
      return false;
    }
    
    // ✅ Marca como processando ANTES de inserir para bloquear inserções simultâneas
    // Isso evita que dois listeners tentem inserir ao mesmo tempo
    // Se já está processando o mesmo atalho no mesmo elemento, não insere
    if (isProcessingShortcut && processingElement === activeElement && lastProcessedShortcut === shortcutToRemove) {
      log('⏸️ Atalho "' + shortcutToRemove + '" já está sendo processado neste elemento - não inserindo novamente');
      return false;
    }
    
    // Marca como processando antes de tentar inserir
    const previousProcessing = isProcessingShortcut;
    const previousProcessingElement = processingElement;
    const previousProcessedShortcut = lastProcessedShortcut;
    
    isProcessingShortcut = true;
    processingElement = activeElement;
    lastProcessedShortcut = shortcutToRemove;
    
    log('📝 Inserindo texto no elemento: ' + activeElement.tagName);
    log('   └─ Removendo: ' + shortcutToRemove);
    
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
        log('   └─ Encontrado "/atalho" na posição: ' + removeStart + ' até ' + removeEnd);
      } else {
        // Se não encontrou, tenta remover do final do texto antes do cursor
        const shortcutLength = (activationKey + shortcutToRemove).length;
        removeStart = Math.max(0, start - shortcutLength);
        removeEnd = start;
        log('   └─ Removendo últimos caracteres antes do cursor');
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
      
      // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
      lastInsertedShortcut = shortcutToRemove;
      lastInsertedTime = Date.now();
      
      log('✅ Texto inserido em INPUT/TEXTAREA');
      // ✅ Não marca shortcutProcessed aqui porque já foi marcado antes de chamar esta função
      return true;
    } else if (activeElement.contentEditable === 'true' || activeElement.isContentEditable) {
      // Para WhatsApp Web, simula digitação real caractere por caractere
      log('📝 Inserindo texto em contentEditable via insertTextAtCursor (WhatsApp) - simulando digitação');
      
      const currentText = activeElement.textContent || activeElement.innerText || '';
      const escapedKey = '$escapedKey';
      const shortcutPattern = new RegExp(escapedKey + shortcutToRemove + '\$');
      const match = currentText.match(shortcutPattern);
      
      // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
      let finalText = currentText;
      if (match && match.index !== undefined) {
        const before = currentText.substring(0, match.index);
        const after = currentText.substring(match.index + match[0].length);
        finalText = before + text + after;
      } else {
        const shortcutLength = (activationKey + shortcutToRemove).length;
        const before = currentText.substring(0, Math.max(0, currentText.length - shortcutLength));
        finalText = before + text;
      }
      lastInputValue = finalText;
      
      // Foca no elemento primeiro
      activeElement.focus();
      
      // Remove o "/atalho" primeiro usando eventos de teclado
      const shortcutLength = match ? match[0].length : (activationKey + shortcutToRemove).length;
      for (let i = 0; i < shortcutLength; i++) {
        const backspaceEvent = new KeyboardEvent('keydown', {
          key: 'Backspace',
          code: 'Backspace',
          keyCode: 8,
          which: 8,
          bubbles: true,
          cancelable: true
        });
        activeElement.dispatchEvent(backspaceEvent);
        
        const backspaceUpEvent = new KeyboardEvent('keyup', {
          key: 'Backspace',
          code: 'Backspace',
          keyCode: 8,
          which: 8,
          bubbles: true,
          cancelable: true
        });
        activeElement.dispatchEvent(backspaceUpEvent);
      }
      
      // Aguarda um pouco antes de inserir o texto
      setTimeout(function() {
        // Insere o texto caractere por caractere para simular digitação real
        let charIndex = 0;
        const insertNextChar = function() {
          if (charIndex < text.length) {
            const char = text[charIndex];
            
            // Cria eventos de teclado para cada caractere
            const keydownEvent = new KeyboardEvent('keydown', {
              key: char,
              code: 'Key' + char.toUpperCase(),
              keyCode: char.charCodeAt(0),
              which: char.charCodeAt(0),
              bubbles: true,
              cancelable: true
            });
            
            const keypressEvent = new KeyboardEvent('keypress', {
              key: char,
              code: 'Key' + char.toUpperCase(),
              keyCode: char.charCodeAt(0),
              which: char.charCodeAt(0),
              bubbles: true,
              cancelable: true
            });
            
            const inputEvent = new InputEvent('input', {
              bubbles: true,
              cancelable: true,
              inputType: 'insertText',
              data: char
            });
            
            const keyupEvent = new KeyboardEvent('keyup', {
              key: char,
              code: 'Key' + char.toUpperCase(),
              keyCode: char.charCodeAt(0),
              which: char.charCodeAt(0),
              bubbles: true,
              cancelable: true
            });
            
            // Dispara os eventos na ordem correta
            activeElement.dispatchEvent(keydownEvent);
            activeElement.dispatchEvent(keypressEvent);
            
            // Insere o caractere usando execCommand (mais compatível com WhatsApp)
            document.execCommand('insertText', false, char);
            
            activeElement.dispatchEvent(inputEvent);
            activeElement.dispatchEvent(keyupEvent);
            
            charIndex++;
            
            // Continua com o próximo caractere após um pequeno delay
            if (charIndex < text.length) {
              setTimeout(insertNextChar, 10);
            } else {
              // Quando terminou de inserir todos os caracteres
              activeElement.dispatchEvent(new Event('change', { bubbles: true }));
              
              // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
              lastInsertedShortcut = shortcutToRemove;
              lastInsertedTime = Date.now();
              
              log('✅ Texto inserido em contentEditable via insertTextAtCursor (WhatsApp) - simulação completa');
            }
          }
        };
        
        // Inicia a inserção caractere por caractere
        insertNextChar();
      }, 50);
      
      // Retorna true imediatamente porque a inserção está em andamento
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
          
          // Marca flags antes de inserir para bloquear outros listeners
          isProcessingShortcut = true;
          shortcutProcessed = true;
          processingElement = activeElement;
          
          // Tenta inserir e marca como processado apenas se inseriu com sucesso
          if (insertTextAtCursor(message, shortcut, true)) {
            // ✅ shortcutProcessed já foi marcado acima
            setTimeout(function() {
              isProcessingShortcut = false;
              processingElement = null;
            }, 300);
          } else {
            // ✅ Se não conseguiu inserir, reseta a flag imediatamente
            isProcessingShortcut = false;
            shortcutProcessed = false;
            processingElement = null;
          }
        }
      }
      return;
    }
    
    // Se pressionou a tecla de ativação
    if (event.key === activationKey) {
      // ✅ Verifica se passou o delay mínimo desde a última inserção
      const now = Date.now();
      if (lastInsertedTime > 0 && (now - lastInsertedTime) < MIN_DELAY_AFTER_INSERTION) {
        const remainingDelay = MIN_DELAY_AFTER_INSERTION - (now - lastInsertedTime);
        log('⏸️ Aguardando ' + remainingDelay + 'ms antes de aceitar novo "/" (delay mínimo após inserção)');
        return;
      }
      
      shortcutProcessed = false; // ✅ Reseta a flag quando "/" é digitado novamente - permite novo processamento
      isProcessingShortcut = false; // ✅ Reseta a flag de processamento quando "/" é digitado novamente
      processingElement = null; // ✅ Limpa o elemento sendo processado
      keysTypedAfterActivation = 0; // ✅ Reseta o contador de teclas quando "/" é digitado
      lastInsertedShortcut = null; // ✅ Limpa o último atalho inserido
      lastInsertedTime = 0; // ✅ Limpa o tempo da última inserção
      globalTypedText = activationKey;
      log('🔑 TECLA DE ATIVAÇÃO PRESSIONADA (global): ' + activationKey);
      log('   └─ Contador de teclas resetado. Aguardando até ' + MAX_KEYS_AFTER_ACTIVATION + ' teclas...');
      
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
        log('⏸️ Atalho já processado - aguardando nova tecla de ativação');
        return;
      }
      
      // ✅ Incrementa o contador de teclas digitadas após "/"
      keysTypedAfterActivation++;
      log('⌨️ Tecla digitada após "/": ' + keysTypedAfterActivation + '/' + MAX_KEYS_AFTER_ACTIVATION);
      
      // ✅ Se excedeu o limite de teclas, desativa e limpa
      if (keysTypedAfterActivation > MAX_KEYS_AFTER_ACTIVATION) {
        log('⚠️ Limite de ' + MAX_KEYS_AFTER_ACTIVATION + ' teclas atingido - desativando. Digite "/" novamente para ativar.');
        globalTypedText = '';
        keysTypedAfterActivation = 0;
        if (globalDebounceTimer) {
          clearTimeout(globalDebounceTimer);
          globalDebounceTimer = null;
        }
        return;
      }
      
      globalTypedText += event.key;
      log('⌨️ Texto acumulado (global): ' + globalTypedText);
      
      // Verifica se é um atalho válido (sem timer - verifica imediatamente)
      const escapedKey = '$escapedKey';
      const shortcutPattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
      const match = globalTypedText.match(shortcutPattern);
      
      if (match && match[1]) {
        const shortcut = match[1].toLowerCase();
        log('⌨️ ATALHO DETECTADO (global): ' + shortcut);
        
        if (shortcuts[shortcut]) {
          const message = shortcuts[shortcut];
          
          // ✅ Verifica ANTES de processar se este mesmo atalho foi inserido recentemente (últimos 1000ms)
          const now = Date.now();
          if (lastInsertedShortcut === shortcut && (now - lastInsertedTime) < 1000) {
            log('⏸️ Atalho "' + shortcut + '" foi inserido recentemente (' + (now - lastInsertedTime) + 'ms atrás) - ignorando para evitar duplicação');
            globalTypedText = '';
            keysTypedAfterActivation = 0;
            return;
          }
          
          // ✅ Verifica se um atalho já foi processado - para imediatamente
          if (shortcutProcessed) {
            log('⏸️ Atalho já processado - aguardando nova tecla de ativação');
            globalTypedText = '';
            keysTypedAfterActivation = 0;
            return;
          }
          
          // ✅ Verifica se já está processando para evitar duplicação
          // Verifica se é o mesmo elemento e o mesmo atalho para evitar bloqueio desnecessário
          const activeElementForCheck = document.activeElement;
          if (isProcessingShortcut) {
            // Se está processando o mesmo atalho no mesmo elemento, ignora
            if (processingElement === activeElementForCheck && lastProcessedShortcut === shortcut) {
              log('⏸️ Processamento já em andamento para o mesmo atalho no mesmo elemento - ignorando');
              globalTypedText = '';
              keysTypedAfterActivation = 0;
              return;
            }
            // Se está processando outro atalho ou em outro elemento, também ignora para evitar conflitos
            log('⏸️ Processamento já em andamento - ignorando');
            globalTypedText = '';
            keysTypedAfterActivation = 0;
            return;
          }
          
          // ✅ Verifica se o texto já contém a mensagem completa (pode ter sido inserida por outro listener)
          const activeElementCheck = document.activeElement;
          if (activeElementCheck) {
            const currentTextCheck = activeElementCheck.value || activeElementCheck.textContent || activeElementCheck.innerText || '';
            if (currentTextCheck.includes(message) && currentTextCheck.length >= message.length) {
              // Verifica se a mensagem está no final do texto (onde esperamos que esteja)
              const messageAtEnd = currentTextCheck.substring(Math.max(0, currentTextCheck.length - message.length)) === message;
              if (messageAtEnd) {
                log('⏸️ Mensagem já está presente no campo (possivelmente inserida por outro listener) - ignorando');
                globalTypedText = '';
                keysTypedAfterActivation = 0;
                // Marca como processado para evitar novas tentativas
                shortcutProcessed = true;
                lastInsertedShortcut = shortcut;
                lastInsertedTime = Date.now();
                return;
              }
            }
          }
          
          // ✅ Verifica ANTES de processar se já está processando o mesmo atalho no mesmo elemento
          // Mas só bloqueia se a mensagem NÃO foi inserida ainda
          // Usa activeElementCheck já declarado acima
          const wasAlreadyProcessing = isProcessingShortcut && processingElement === activeElementCheck && lastProcessedShortcut === shortcut;
          
          if (wasAlreadyProcessing) {
            // Verifica se a mensagem já foi inserida no campo
            const currentTextForCheck = activeElementCheck.value || activeElementCheck.textContent || activeElementCheck.innerText || '';
            const messageAlreadyInserted = currentTextForCheck.includes(message) && currentTextForCheck.length >= message.length;
            const messageAtEnd = messageAlreadyInserted && currentTextForCheck.substring(Math.max(0, currentTextForCheck.length - message.length)) === message;
            
            if (messageAtEnd) {
              log('⏸️ Mensagem já foi inserida no campo - ignorando');
              globalTypedText = '';
              keysTypedAfterActivation = 0;
              return;
            }
            
            // Se não foi inserida ainda, verifica há quanto tempo está processando
            const timeSinceProcessing = Date.now() - lastProcessedTime;
            if (timeSinceProcessing < 500) {
              log('⏸️ Atalho "' + shortcut + '" já está sendo processado neste elemento (há ' + timeSinceProcessing + 'ms) - ignorando');
              globalTypedText = '';
              keysTypedAfterActivation = 0;
              return;
            } else {
              log('⏰ Processamento iniciado há ' + timeSinceProcessing + 'ms sem inserção - permitindo nova tentativa');
              // Reseta as flags para permitir nova tentativa
              isProcessingShortcut = false;
              processingElement = null;
            }
          }
          
          log('✅✅✅ ATALHO ENCONTRADO (global) ✅✅✅');
          log('   └─ Atalho: ' + shortcut);
          log('   └─ Mensagem: ' + message.substring(0, 50) + '...');
          
          // ✅ Marca como processando e processado IMEDIATAMENTE para bloquear outras tentativas
          // Isso evita que o listener de input tente processar o mesmo atalho
          // IMPORTANTE: Marca ANTES de verificar novamente para garantir que apenas um listener prossiga
          const activeElement = document.activeElement;
          
          // ✅ Verifica novamente DEPOIS de marcar para garantir que não foi marcado por outro listener entre as verificações
          // Se outro listener já marcou enquanto estávamos verificando, não prossegue
          if (!wasAlreadyProcessing && isProcessingShortcut && processingElement === activeElement && lastProcessedShortcut === shortcut) {
            log('⏸️ Outro listener já marcou as flags enquanto verificávamos - ignorando');
            globalTypedText = '';
            keysTypedAfterActivation = 0;
            return;
          }
          
          // ✅ Se chegou aqui, este listener é o responsável por inserir
          isProcessingShortcut = true;
          shortcutProcessed = true; // ✅ Marca IMEDIATAMENTE para bloquear outros listeners
          keysTypedAfterActivation = 0; // ✅ Reseta o contador quando um atalho válido é encontrado
          processingElement = activeElement;
          lastProcessedShortcut = shortcut;
          lastProcessedTime = Date.now();
          // ✅ NÃO marca lastInsertedShortcut aqui - será marcado APENAS após inserção bem-sucedida
          
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
          
          // ✅ Verifica ANTES de tentar inserir se a mensagem já foi inserida
          // Se já foi inserida, não tenta inserir novamente
          const activeElementBeforeInsert = document.activeElement;
          if (activeElementBeforeInsert) {
            const currentTextBeforeInsert = activeElementBeforeInsert.value || activeElementBeforeInsert.textContent || activeElementBeforeInsert.innerText || '';
            const messageAlreadyInsertedBefore = currentTextBeforeInsert.includes(message) && currentTextBeforeInsert.length >= message.length;
            const messageAtEndBefore = messageAlreadyInsertedBefore && currentTextBeforeInsert.substring(Math.max(0, currentTextBeforeInsert.length - message.length)) === message;
            
            if (messageAtEndBefore) {
              log('⏸️ Mensagem já foi inserida no campo antes de tentar inserir - não inserindo novamente');
              // Marca como inserido
              lastInsertedShortcut = shortcut;
              lastInsertedTime = Date.now();
              setTimeout(function() {
                isProcessingShortcut = false;
                processingElement = null;
              }, 300);
              return;
            }
          }
          
          // ✅ Insere a mensagem imediatamente sem delay
          // Tenta inserir onde o cursor estiver, removendo o "/atalho"
          // skipProcessedCheck=true porque já marcamos shortcutProcessed=true acima
          const insertedViaCursor = insertTextAtCursor(message, shortcut, true);
          if (insertedViaCursor) {
            log('✅ Texto inserido via insertTextAtCursor');
            // ✅ shortcutProcessed já foi marcado acima antes de inserir
            // ✅ Reseta a flag após um pequeno delay para permitir novos processamentos
            setTimeout(function() {
              isProcessingShortcut = false;
              processingElement = null;
            }, 300);
            // ✅ Não tenta inserir diretamente se já inseriu via insertTextAtCursor
            return;
          }
          
          // ✅ Verifica se o texto já foi inserido (pode ter sido inserido mesmo retornando false)
          // Usa activeElement que já foi declarado acima
          if (activeElement) {
            const currentTextCheck = activeElement.value || activeElement.textContent || activeElement.innerText || '';
            // Se o texto já contém a mensagem completa, não tenta inserir novamente
            if (currentTextCheck.includes(message) && currentTextCheck.length >= message.length) {
              // Verifica se a mensagem está no final do texto
              const messageAtEnd = currentTextCheck.substring(Math.max(0, currentTextCheck.length - message.length)) === message;
              if (messageAtEnd) {
                log('⏸️ Texto já foi inserido - não inserindo novamente');
                // Marca como inserido
                lastInsertedShortcut = shortcut;
                lastInsertedTime = Date.now();
                setTimeout(function() {
                  isProcessingShortcut = false;
                  processingElement = null;
                }, 300);
                return;
              }
            }
          }
          
          // ✅ Verifica novamente se o atalho foi inserido recentemente antes de tentar inserir diretamente
          const nowCheck = Date.now();
          if (lastInsertedShortcut === shortcut && (nowCheck - lastInsertedTime) < 1000) {
            log('⏸️ Atalho "' + shortcut + '" foi inserido recentemente (' + (nowCheck - lastInsertedTime) + 'ms atrás) - não tentando inserir diretamente');
            setTimeout(function() {
              isProcessingShortcut = false;
              processingElement = null;
            }, 300);
            return;
          }
          
          // ✅ IMPORTANTE: Se insertTextAtCursor retornou false mas a mensagem NÃO foi inserida,
          // tenta inserir diretamente mesmo que outro listener esteja processando
          // Isso garante que pelo menos um listener consiga inserir
          log('📝 insertTextAtCursor retornou false - tentando inserir diretamente');
          
          // Se não conseguiu inserir via insertTextAtCursor, tenta no elemento ativo diretamente
          // Usa activeElement que já foi declarado acima
          const activeElementForDirectInsert = activeElement || document.activeElement;
          
          // ✅ Verifica uma última vez se a mensagem já foi inserida antes de tentar inserir diretamente
          if (activeElementForDirectInsert) {
            const finalCheckText = activeElementForDirectInsert.value || activeElementForDirectInsert.textContent || activeElementForDirectInsert.innerText || '';
            if (finalCheckText.includes(message) && finalCheckText.length >= message.length) {
              const finalMessageAtEnd = finalCheckText.substring(Math.max(0, finalCheckText.length - message.length)) === message;
              if (finalMessageAtEnd) {
                log('⏸️ Mensagem já foi inserida - não tentando inserir diretamente');
                // Marca como inserido
                lastInsertedShortcut = shortcut;
                lastInsertedTime = Date.now();
                setTimeout(function() {
                  isProcessingShortcut = false;
                  processingElement = null;
                }, 300);
                return;
              }
            }
            
            const currentText = activeElementForDirectInsert.value || activeElementForDirectInsert.textContent || activeElementForDirectInsert.innerText || '';
            
            // Procura pelo "/atalho" no texto e remove antes de inserir
            const escapedKey = '$escapedKey';
            const shortcutPattern = new RegExp(escapedKey + shortcut + '\$');
            const match = currentText.match(shortcutPattern);
            
            let before = currentText;
            if (match && match.index !== undefined) {
              before = currentText.substring(0, match.index);
              log('   └─ Removendo "/atalho" encontrado na posição: ' + match.index);
            } else {
              // Tenta remover do final
              const shortcutLength = (activationKey + shortcut).length;
              before = currentText.substring(0, Math.max(0, currentText.length - shortcutLength));
              log('   └─ Removendo últimos caracteres');
            }
            
            // ✅ Verifica uma última vez se a mensagem já está presente antes de inserir
            const finalTextCheck = activeElementForDirectInsert.value || activeElementForDirectInsert.textContent || activeElementForDirectInsert.innerText || '';
            if (finalTextCheck.includes(message) && finalTextCheck.length >= message.length) {
              const messageAtEndCheck = finalTextCheck.substring(Math.max(0, finalTextCheck.length - message.length)) === message;
              if (messageAtEndCheck) {
                log('⏸️ Mensagem já está presente no campo antes de inserir diretamente - não inserindo');
                setTimeout(function() {
                  isProcessingShortcut = false;
                  processingElement = null;
                }, 300);
                return;
              }
            }
            
            // ✅ Atualiza lastInputValue ANTES de inserir para evitar que o listener de input processe novamente
            const finalText = before + message;
            lastInputValue = finalText;
            
            if (activeElementForDirectInsert.tagName === 'INPUT' || activeElementForDirectInsert.tagName === 'TEXTAREA') {
              activeElementForDirectInsert.value = finalText;
              activeElementForDirectInsert.setSelectionRange(before.length + message.length, before.length + message.length);
              activeElementForDirectInsert.dispatchEvent(new Event('input', { bubbles: true }));
              activeElementForDirectInsert.dispatchEvent(new Event('change', { bubbles: true }));
              
              // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
              lastInsertedShortcut = shortcut;
              lastInsertedTime = Date.now();
              
              log('✅ Texto inserido diretamente em INPUT/TEXTAREA');
              // ✅ shortcutProcessed já foi marcado acima antes de inserir
              // ✅ Reseta a flag após um pequeno delay para permitir novos processamentos
              setTimeout(function() {
                isProcessingShortcut = false;
                processingElement = null;
              }, 300);
            } else if (activeElementForDirectInsert.contentEditable === 'true' || activeElementForDirectInsert.isContentEditable) {
              // Para WhatsApp Web, usa uma abordagem mais robusta
              log('📝 Inserindo texto diretamente em contentEditable (WhatsApp)');
              
              // Primeiro, foca no elemento
              activeElementForDirectInsert.focus();
              
              // Limpa o conteúdo existente
              activeElementForDirectInsert.innerHTML = '';
              
              // Cria um novo nó de texto com o conteúdo completo
              const textNode = document.createTextNode(finalText);
              activeElementForDirectInsert.appendChild(textNode);
              
              // Move o cursor para o final
              const range = document.createRange();
              const selection = window.getSelection();
              range.selectNodeContents(activeElementForDirectInsert);
              range.collapse(false);
              selection.removeAllRanges();
              selection.addRange(range);
              
              // Dispara eventos para notificar o WhatsApp (na ordem correta)
              // Primeiro o input event com InputEvent para WhatsApp detectar
              const inputEvent = new InputEvent('input', { 
                bubbles: true, 
                cancelable: true, 
                inputType: 'insertText', 
                data: message 
              });
              activeElementForDirectInsert.dispatchEvent(inputEvent);
              
              // Depois os eventos padrão
              activeElementForDirectInsert.dispatchEvent(new Event('input', { bubbles: true }));
              activeElementForDirectInsert.dispatchEvent(new Event('keyup', { bubbles: true }));
              activeElementForDirectInsert.dispatchEvent(new Event('keydown', { bubbles: true }));
              activeElementForDirectInsert.dispatchEvent(new Event('change', { bubbles: true }));
              
              // Dispara também um evento de paste para garantir que o WhatsApp detecte
              const pasteEvent = new ClipboardEvent('paste', { bubbles: true, cancelable: true });
              activeElementForDirectInsert.dispatchEvent(pasteEvent);
              
              // ✅ Marca o atalho como inserido APENAS DEPOIS de inserir com sucesso
              lastInsertedShortcut = shortcut;
              lastInsertedTime = Date.now();
              
              log('✅ Texto inserido diretamente em contentEditable (WhatsApp)');
              // ✅ shortcutProcessed já foi marcado acima antes de inserir
              // ✅ Reseta a flag após um pequeno delay para permitir novos processamentos
              setTimeout(function() {
                isProcessingShortcut = false;
                processingElement = null;
              }, 300);
            } else {
              log('⚠️ Não foi possível inserir texto - elemento não é editável');
              // ✅ Se não conseguiu inserir, reseta as flags imediatamente para permitir nova tentativa
              isProcessingShortcut = false;
              shortcutProcessed = false;
              processingElement = null;
            }
          } else {
            log('⚠️ Não foi possível inserir texto - nenhum elemento ativo');
            // ✅ Se não há elemento ativo, reseta as flags imediatamente para permitir nova tentativa
            isProcessingShortcut = false;
            shortcutProcessed = false;
            processingElement = null;
          }
          
          return;
        } else {
          // ✅ Se não encontrou um atalho válido ainda, apenas continua aguardando mais teclas
          // Não há timer - o sistema só desativa quando atingir 5 teclas sem encontrar atalho válido
          log('⏳ Atalho "' + shortcut + '" não encontrado. Aguardando mais teclas... (' + keysTypedAfterActivation + '/' + MAX_KEYS_AFTER_ACTIVATION + ')');
        }
      }
    }
  }
  
  // Adiciona listener global de teclado
  document.addEventListener('keydown', handleGlobalKeydown, true);
  log('✅ Listener global de teclado adicionado');

  // Adiciona listeners para todos os campos de texto existentes
  function attachListeners() {
    const inputs = document.querySelectorAll('input[type="text"], input[type="search"], textarea, [contenteditable="true"]');
    log('Encontrados ' + inputs.length + ' campos de texto');
    inputs.forEach(function(input, index) {
      if (!input.hasAttribute('data-quick-messages-listener')) {
        input.setAttribute('data-quick-messages-listener', 'true');
        input.addEventListener('input', handleInput, true);
        input.addEventListener('keyup', handleInput, true);
        log('Listener adicionado ao campo ' + index + ' ' + input.tagName + ' ' + (input.type || 'contentEditable'));
      }
    });
  }

  // Observa novos elementos sendo adicionados ao DOM (importante para SPAs como WhatsApp)
  const observer = new MutationObserver(function(mutations) {
    log('DOM modificado - reanexando listeners');
    attachListeners();
  });

  // Inicia observação
  if (document.body) {
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
    log('Observer iniciado no document.body');
  } else {
    log('⚠️ document.body não encontrado');
  }

  // Anexa listeners aos elementos existentes
  if (document.readyState == 'loading') {
    log('Aguardando DOMContentLoaded');
    document.addEventListener('DOMContentLoaded', function() {
      log('DOMContentLoaded - anexando listeners');
      attachListeners();
    });
  } else {
    log('DOM já carregado - anexando listeners imediatamente');
    attachListeners();
  }
  
  log('✅ Sistema de mensagens rápidas inicializado');
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

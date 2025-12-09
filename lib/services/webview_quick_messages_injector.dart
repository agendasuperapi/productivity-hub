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
    debugPrint('[QuickMessages]   └─ Mensagens: ${_messages.length}');
    if (_messages.isNotEmpty) {
      debugPrint('[QuickMessages]   └─ Atalhos: ${_messages.map((m) => m.shortcut).join(", ")}');
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

  // ✅ Log de inicialização
  console.log('[QuickMessages] Script injetado com sucesso');
  console.log('[QuickMessages] Activation key:', activationKey);
  console.log('[QuickMessages] Shortcuts disponíveis:', Object.keys(shortcuts).length);
  console.log('[QuickMessages] Shortcuts:', shortcuts);

  function replaceShortcut(element, text) {
    const escapedKey = '$escapedKey';
    // Procura pelo padrão no final do texto (onde o usuário está digitando)
    // Procura por tecla_ativação + atalho no final do texto
    const pattern = new RegExp(escapedKey + '([a-zA-Z0-9]+)\$');
    const match = text.match(pattern);
    
    console.log('[QuickMessages] Verificando texto:', text);
    console.log('[QuickMessages] Pattern:', pattern);
    console.log('[QuickMessages] Match encontrado:', match);
    
    if (match && match[1] && shortcuts[match[1].toLowerCase()]) {
      const shortcut = match[1].toLowerCase();
      const message = shortcuts[shortcut];
      console.log('[QuickMessages] ✅ ATALHO LOCALIZADO:', shortcut);
      console.log('[QuickMessages] Mensagem:', message);
      
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
        // Limpa o conteúdo atual
        element.innerHTML = '';
        // Insere o novo texto
        const textNode = document.createTextNode(newText);
        element.appendChild(textNode);
        
        // Move o cursor para o final
        const range = document.createRange();
        const selection = window.getSelection();
        if (element.firstChild) {
          range.setStart(element.firstChild, newText.length);
          range.setEnd(element.firstChild, newText.length);
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
    
    // Se o texto não mudou, ignora
    if (text == lastInputValue) return;
    lastInputValue = text;
    
    // Cancela timer anterior
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }
    
    // Se pressionou espaço ou Enter, substitui imediatamente
    if (event.type == 'keyup' && (event.key == ' ' || event.key == 'Enter')) {
      console.log('[QuickMessages] Tecla espaço/Enter pressionada - verificando atalho');
      replaceShortcut(element, text);
      return;
    }
    
    // Caso contrário, aguarda 800ms antes de verificar o atalho
    // Isso dá tempo suficiente para o usuário digitar o atalho completo
    debounceTimer = setTimeout(function() {
      console.log('[QuickMessages] Timer expirado - verificando atalho');
      replaceShortcut(element, text);
    }, 800);
  }

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

// Classe completa para injeção de mensagens rápidas no WebView
// Versão corrigida e ultra-compatível - PRONTA PARA USO
// Copie este arquivo para seu projeto Flutter e use diretamente

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class QuickMessagesInjector {
  // Script JavaScript ultra-compatível (sem arrow functions, sem .startsWith)
  static String getScriptContent() {
    return '''
(function() {
  'use strict';

  if (window.QuickMessagesInitialized) {
    return;
  }
  window.QuickMessagesInitialized = true;

  var ACTIVATION_KEY = '/';
  var shortcuts = {};
  var accumulatedText = '';
  var keyCount = 0;
  var MAX_KEYS = 5;
  var lastKeyTime = 0;
  var KEY_TIMEOUT = 2000;

  window.setQuickMessagesConfig = function(config) {
    if (config.activationKey) {
      ACTIVATION_KEY = config.activationKey;
    }
    if (config.shortcuts) {
      shortcuts = config.shortcuts;
    }
    console.log('[QuickMessages] Config atualizada');
  };

  function getWhatsAppEditor() {
    try {
      var all = document.querySelectorAll('div[contenteditable="true"][role="textbox"]');
      var list = [];
      for (var i = 0; i < all.length; i++) {
        list.push(all[i]);
      }
      var visible = [];
      for (var j = 0; j < list.length; j++) {
        var el = list[j];
        var style = window.getComputedStyle(el);
        if (style.display !== 'none' && style.visibility !== 'hidden') {
          visible.push(el);
        }
      }
      if (visible.length > 0) {
        return visible[visible.length - 1];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  function insertWhatsAppMessage(message) {
    var editor = getWhatsAppEditor();
    if (!editor) {
      return false;
    }
    var text = String(message).replace(/\\\\r\\\\n/g, '\\\\n');
    editor.focus();
    editor.textContent = text;
    try {
      var before = new InputEvent('beforeinput', {
        bubbles: true,
        cancelable: true,
        inputType: 'insertFromPaste',
        data: text
      });
      editor.dispatchEvent(before);
      var input = new InputEvent('input', {
        bubbles: true,
        cancelable: false,
        inputType: 'insertFromPaste',
        data: text
      });
      editor.dispatchEvent(input);
    } catch (e) {
    }
    return true;
  }

  function insertTextAtCursor(element, text) {
    if (!element) return false;
    try {
      if (element.contentEditable === 'true') {
        element.focus();
        var selection = window.getSelection();
        if (selection.rangeCount > 0) {
          var range = selection.getRangeAt(0);
          range.deleteContents();
          var textNode = document.createTextNode(text);
          range.insertNode(textNode);
          range.setStartAfter(textNode);
          selection.removeAllRanges();
          selection.addRange(range);
        }
        element.dispatchEvent(new Event('input', { bubbles: true }));
        return true;
      } else if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
        var start = element.selectionStart || 0;
        var end = element.selectionEnd || 0;
        var value = element.value || '';
        element.value = value.substring(0, start) + text + value.substring(end);
        element.selectionStart = start + text.length;
        element.selectionEnd = start + text.length;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        return true;
      }
    } catch (e) {
    }
    return false;
  }

  function insertDirectInContentEditable(element, text) {
    if (!element || element.contentEditable !== 'true') return false;
    try {
      element.focus();
      element.textContent = text;
      element.dispatchEvent(new Event('input', { bubbles: true }));
      return true;
    } catch (e) {
      return false;
    }
  }

  function handleShortcutResolved(shortcutKey, mensagem, target) {
    if (window.location.host === 'web.whatsapp.com') {
      if (insertWhatsAppMessage(mensagem)) {
        return;
      }
    }
    if (!insertTextAtCursor(target, mensagem)) {
      insertDirectInContentEditable(target, mensagem);
    }
  }

  function resetAccumulator() {
    accumulatedText = '';
    keyCount = 0;
    lastKeyTime = 0;
  }

  function findActiveTextInput() {
    var activeElement = document.activeElement;
    if (activeElement) {
      if (activeElement.contentEditable === 'true' || 
          activeElement.tagName === 'INPUT' || 
          activeElement.tagName === 'TEXTAREA') {
        return activeElement;
      }
    }
    var all = document.querySelectorAll('div[contenteditable="true"], textarea, input[type="text"]');
    var visible = [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      var style = window.getComputedStyle(el);
      if (style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0') {
        visible.push(el);
      }
    }
    if (visible.length > 0) {
      return visible[visible.length - 1];
    }
    return null;
  }

  document.addEventListener('keydown', function(e) {
    var now = Date.now();
    if (lastKeyTime > 0 && (now - lastKeyTime) > KEY_TIMEOUT) {
      resetAccumulator();
    }
    if (e.key === ACTIVATION_KEY && !e.ctrlKey && !e.metaKey && !e.altKey) {
      resetAccumulator();
      accumulatedText = ACTIVATION_KEY;
      keyCount = 0;
      lastKeyTime = now;
      return;
    }
    if (accumulatedText.indexOf(ACTIVATION_KEY) === 0 && keyCount < MAX_KEYS) {
      if (e.key.length === 1 || e.key === 'Backspace' || e.key === 'Delete') {
        if (e.key === 'Backspace' || e.key === 'Delete') {
          if (accumulatedText.length > 1) {
            accumulatedText = accumulatedText.substring(0, accumulatedText.length - 1);
            keyCount = keyCount > 0 ? keyCount - 1 : 0;
          } else {
            resetAccumulator();
          }
          return;
        }
        accumulatedText = accumulatedText + e.key;
        keyCount = keyCount + 1;
        lastKeyTime = now;
        var shortcutKey = accumulatedText.substring(1);
        if (shortcuts[shortcutKey]) {
          var target = findActiveTextInput();
          if (target) {
            handleShortcutResolved(shortcutKey, shortcuts[shortcutKey], target);
            resetAccumulator();
            e.preventDefault();
            e.stopPropagation();
          } else {
            resetAccumulator();
          }
        }
      }
    }
  }, true);

  console.log('[QuickMessages] Script carregado');
})();
''';
  }

  /// Injeta o script no WebView
  static Future<void> injectScript(InAppWebViewController controller) async {
    try {
      final script = getScriptContent();
      await controller.evaluateJavascript(source: script);
      print('[QuickMessages] ✅ Script injetado com sucesso');
    } catch (e) {
      print('[QuickMessages] ❌ Erro ao injetar script: $e');
    }
  }

  /// Atualiza a configuração (atalhos e tecla de ativação)
  static Future<void> updateConfig(
    InAppWebViewController controller, {
    String activationKey = '/',
    required Map<String, String> shortcuts,
  }) async {
    try {
      // Converte o mapa para JSON e escapa corretamente
      final shortcutsJson = shortcuts.entries.map((e) {
        // Escapa a chave
        var key = e.key
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"');
        
        // Escapa o valor (mensagem) - ordem importante!
        var value = e.value
            .replaceAll('\\', '\\\\')  // Primeiro escapa as barras invertidas
            .replaceAll('"', '\\"')    // Depois aspas
            .replaceAll('\n', '\\n')   // Quebras de linha
            .replaceAll('\r', '\\r')   // Carriage return
            .replaceAll('\$', '\\\$'); // Evita interpolação de string
        
        return '"$key": "$value"';
      }).join(', ');

      final script = '''
if (window.setQuickMessagesConfig) {
  window.setQuickMessagesConfig({
    activationKey: "$activationKey",
    shortcuts: {
      $shortcutsJson
    }
  });
} else {
  console.warn('[QuickMessages] setQuickMessagesConfig não está disponível');
}
''';

      await controller.evaluateJavascript(source: script);
      print('[QuickMessages] ✅ Configuração atualizada');
    } catch (e) {
      print('[QuickMessages] ❌ Erro ao atualizar configuração: $e');
      print('[QuickMessages] Erro detalhado: ${e.toString()}');
    }
  }
}


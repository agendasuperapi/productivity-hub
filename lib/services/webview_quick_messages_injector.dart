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
    if (url != null) {
      if (url.startsWith('data:')) {
        debugPrint('[QuickMessages]   └─ URL: data:application/pdf (base64)');
      } else {
        debugPrint('[QuickMessages]   └─ URL: $url');
      }
    } else {
      debugPrint('[QuickMessages]   └─ URL: N/A');
    }
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
  /// ✅ Versão corrigida e ultra-compatível (sem arrow functions, sem .startsWith, sem ===/!==)
  String _createInjectionScript() {
    // Cria um mapa de atalhos para mensagens (inclui ID e mensagem)
    final shortcutsMap = <String, Map<String, String>>{};
    final shortcutsMessageMap = <String, String>{};
    for (final message in _messages) {
      final shortcut = message.shortcut.toLowerCase();
      shortcutsMap[shortcut] = {
        'id': message.id,
        'message': message.message,
      };
      shortcutsMessageMap[shortcut] = message.message;
    }

    // Converte para JSON e escapa corretamente (mapa de IDs)
    final shortcutsJson = shortcutsMap.entries.map((e) {
      final key = e.key.replaceAll('"', '\\"');
      final id = e.value['id']!.replaceAll('"', '\\"');
      final value = e.value['message']!
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      return '"$key": {id: "$id", message: "$value"}';
    }).join(', ');
    
    // Converte mensagens para JSON (mantém compatibilidade)
    final shortcutsMessageJson = shortcutsMessageMap.entries.map((e) {
      final key = e.key.replaceAll('"', '\\"');
      final value = e.value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      return '"$key": "$value"';
    }).join(', ');

    final activationKeyEscaped = _activationKey.replaceAll('"', '\\"');
    
    return '''
(function() {
  'use strict';

  if (window.QuickMessagesInitialized) {
    // Script já foi inicializado, apenas atualiza a configuração
    if (window.setQuickMessagesConfig) {
      window.setQuickMessagesConfig({
        activationKey: '$activationKeyEscaped',
        shortcuts: {
          $shortcutsMessageJson
        },
        shortcutsData: {
          $shortcutsJson
        }
      });
    }
    return;
  }
  window.QuickMessagesInitialized = true;

  var ACTIVATION_KEY = '$activationKeyEscaped';
  var shortcutsData = {
    $shortcutsJson
  };
  // ✅ Mantém compatibilidade com código existente
  var shortcuts = {
    $shortcutsMessageJson
  };
  var accumulatedText = '';
  var keyCount = 0;
  var MAX_KEYS = 8;
  
  // Inicializa timeout para notificações de atalho não encontrado
  if (!window.quickMessageNotFoundTimeout) {
    window.quickMessageNotFoundTimeout = null;
  }

  window.setQuickMessagesConfig = function(config) {
    if (config.activationKey) {
      ACTIVATION_KEY = config.activationKey;
    }
    if (config.shortcuts) {
      shortcuts = config.shortcuts;
    }
    if (config.shortcutsData) {
      shortcutsData = config.shortcutsData;
    }
    console.log('[QuickMessages] Config atualizada');
  };

  function getWhatsAppEditor() {
    try {
      // Tenta encontrar o campo de mensagem do WhatsApp
      // WhatsApp usa DIV contentEditable com role="textbox"
      var all = document.querySelectorAll('div[contenteditable="true"][role="textbox"]');
      var list = [];
      for (var i = 0; i < all.length; i++) {
        list.push(all[i]);
      }
      var visible = [];
      for (var j = 0; j < list.length; j++) {
        var el = list[j];
        var style = window.getComputedStyle(el);
        if (style.display != 'none' && style.visibility != 'hidden') {
          visible.push(el);
        }
      }
      if (visible.length > 0) {
        var editor = visible[visible.length - 1];
        console.log('[QuickMessages] ✅ Editor encontrado: ' + (editor.className || 'sem classe'));
        return editor;
      }
      console.log('[QuickMessages] ⚠️ Nenhum editor visível encontrado');
      return null;
    } catch (e) {
      console.log('[QuickMessages] ⚠️ Erro ao buscar editor: ' + e);
      return null;
    }
  }

  // ✅ Função para obter saudação baseada no horário
  function getGreeting() {
    var now = new Date();
    var hour = now.getHours();
    
    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }
  
  // ✅ Função para substituir placeholders na mensagem
  function replacePlaceholders(text) {
    if (!text) return text;
    
    var result = String(text);
    
    // ✅ Substitui <SAUDACAO> pela saudação apropriada
    var saudacaoPattern = /<SAUDACAO>/gi;
    if (saudacaoPattern.test(result)) {
      var greeting = getGreeting();
      result = result.replace(saudacaoPattern, greeting);
      console.log('[QuickMessages] ✅ <SAUDACAO> substituído por: ' + greeting);
    }
    
    return result;
  }

  function insertWhatsAppMessage(fullText, shortcutTyped) {
    console.log('[QuickMessages] 📝 Tentando inserir mensagem no WhatsApp');
    var editor = getWhatsAppEditor();
    if (!editor) {
      console.log('[QuickMessages] ❌ WhatsApp editor não encontrado');
      return false;
    }
    
    // ✅ Substitui placeholders antes de processar
    fullText = replacePlaceholders(fullText);
    
    // Normaliza quebras de linha
    var message = String(fullText).replace(/\\r\\n/g, '\\n');
    
    // Texto atual no campo
    var current = editor.innerText || editor.textContent || '';
    console.log('[QuickMessages] 📝 Texto atual no campo: "' + current + '"');
    var newText;
    
    if (shortcutTyped) {
      // Se o campo começa com a tecla de ativação, substitui tudo
      // Isso lida com casos onde o campo tem "/x3" mas o atalho completo é "/x32"
      if (current.indexOf(ACTIVATION_KEY) == 0) {
        console.log('[QuickMessages] 🔄 Campo começa com tecla de ativação, substituindo tudo');
        newText = message;
      } else {
        // Tenta substituir o "/atalho" no texto atual
        // Escapa caracteres especiais do regex
        var escaped = '';
        var specialChars = '.*+?^' + String.fromCharCode(36) + '{}()|[\\]';
        for (var i = 0; i < shortcutTyped.length; i++) {
          var char = shortcutTyped.charAt(i);
          if (specialChars.indexOf(char) >= 0) {
            escaped = escaped + '\\\\' + char;
          } else {
            escaped = escaped + char;
          }
        }
        var dollarSign = String.fromCharCode(36);
        var re = new RegExp('/' + escaped + dollarSign);
        newText = current.replace(re, message);
        
        // Se não encontrou no final, tenta substituir em qualquer lugar
        if (newText == current) {
          var reAnywhere = new RegExp('/' + escaped);
          newText = current.replace(reAnywhere, message);
        }
        
        // Se ainda não encontrou, substitui tudo
        if (newText == current) {
          newText = message;
        }
      }
    } else {
      // Se não passar o atalho, substitui tudo
      newText = message;
    }
    
    console.log('[QuickMessages] 📝 Novo texto calculado: "' + newText.substring(0, 60) + (newText.length > 60 ? '...' : '') + '"');
    
    console.log('[QuickMessages] 🟢 Inserindo no WhatsApp: ' + newText.substring(0, 60) + (newText.length > 60 ? '...' : ''));
    
    editor.focus();
    
    // Abordagem 1: Tenta usar Clipboard API para simular paste real
    function insertViaClipboard() {
      return new Promise(function(resolve) {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(newText).then(function() {
            // Seleciona todo o conteúdo
            var range = document.createRange();
            range.selectNodeContents(editor);
            var selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            
            // Simula Ctrl+V
            var pasteEvent = new ClipboardEvent('paste', {
              bubbles: true,
              cancelable: true,
              clipboardData: new DataTransfer()
            });
            pasteEvent.clipboardData.setData('text/plain', newText);
            editor.dispatchEvent(pasteEvent);
            
            setTimeout(function() {
              var finalText = editor.textContent || editor.innerText || '';
              if (finalText.length > 0 && finalText.indexOf('/') != 0 && finalText.length >= newText.length * 0.8) {
                console.log('[QuickMessages] ✅ Texto inserido via Clipboard API');
                resolve(true);
              } else {
                resolve(false);
              }
            }, 200);
          }).catch(function() {
            resolve(false);
          });
        } else {
          resolve(false);
        }
      });
    }
    
    // Abordagem 2: execCommand com seleção completa
    function insertViaExecCommand() {
      try {
        // Limpa primeiro
        editor.textContent = '';
        editor.innerText = '';
        
        setTimeout(function() {
          // Seleciona tudo (mesmo vazio)
          var range = document.createRange();
          range.selectNodeContents(editor);
          var selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          
          // Usa execCommand
          var inserted = document.execCommand('insertText', false, newText);
          if (inserted) {
            setTimeout(function() {
              var finalText = editor.textContent || editor.innerText || '';
              if (finalText.length > 0 && finalText.indexOf('/') != 0 && finalText.length >= newText.length * 0.8) {
                console.log('[QuickMessages] ✅ Texto inserido via execCommand');
                return;
              }
            }, 200);
          }
        }, 50);
      } catch (e) {
        console.log('[QuickMessages] ⚠️ execCommand falhou: ' + e);
      }
    }
    
    // Abordagem 3: Manipulação direta dos nós filhos (para Lexical)
    function insertViaDirectManipulation() {
      var attempts = 0;
      var maxAttempts = 3;
      
      function tryInsert() {
        attempts++;
        console.log('[QuickMessages] 🔄 Tentativa ' + attempts + ' de inserção direta');
        
        try {
          // Limpa todos os nós filhos
          while (editor.firstChild) {
            editor.removeChild(editor.firstChild);
          }
          
          // Cria um novo nó de texto
          var textNode = document.createTextNode(newText);
          editor.appendChild(textNode);
          
          // Também define textContent e innerText
          editor.textContent = newText;
          editor.innerText = newText;
          
          // Dispara eventos na ordem correta
          var before = new InputEvent('beforeinput', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertFromPaste',
            data: newText
          });
          var beforeResult = editor.dispatchEvent(before);
          
          if (!beforeResult.defaultPrevented) {
            var input = new InputEvent('input', {
              bubbles: true,
              cancelable: false,
              inputType: 'insertFromPaste',
              data: newText
            });
            editor.dispatchEvent(input);
            
            editor.dispatchEvent(new Event('input', { bubbles: true }));
            editor.dispatchEvent(new Event('change', { bubbles: true }));
            
            // Tenta forçar atualização do Lexical
            if (editor._lexicalEditor) {
              try {
                editor._lexicalEditor.update(function() {
                  var root = editor._lexicalEditor.getRootElement();
                  if (root) {
                    root.textContent = newText;
                  }
                });
              } catch (e) {
              }
            }
          }
          
          // Verifica após um tempo
          setTimeout(function() {
            var finalText = editor.textContent || editor.innerText || '';
            console.log('[QuickMessages] 📝 Texto após tentativa ' + attempts + ': ' + finalText.substring(0, 60) + (finalText.length > 60 ? '...' : ''));
            
            if (finalText.length > 0 && finalText.indexOf('/') != 0 && finalText.length >= newText.length * 0.8) {
              console.log('[QuickMessages] ✅ Texto inserido via manipulação direta (tamanho: ' + finalText.length + ')');
            } else if (attempts < maxAttempts) {
              // Tenta novamente
              setTimeout(tryInsert, 150);
            } else {
              console.log('[QuickMessages] ⚠️ Todas as tentativas falharam');
            }
          }, 300);
        } catch (e) {
          console.log('[QuickMessages] ⚠️ Erro na tentativa ' + attempts + ': ' + e);
          if (attempts < maxAttempts) {
            setTimeout(tryInsert, 150);
          }
        }
      }
      
      tryInsert();
    }
    
    // Tenta todas as abordagens em sequência
    // ✅ NOTA: A restauração do clipboard será feita pela função handleShortcutResolved após um delay
    insertViaClipboard().then(function(success) {
      if (!success) {
        insertViaExecCommand();
        setTimeout(function() {
          insertViaDirectManipulation();
        }, 300);
      }
    });
    
    return true;
  }

  function insertTextAtCursor(element, text) {
    if (!element) {
      console.log('[QuickMessages] ❌ insertTextAtCursor: elemento não encontrado');
      return false;
    }
    
    // ✅ Substitui placeholders antes de inserir
    text = replacePlaceholders(text);
    try {
      if (element.contentEditable == 'true') {
        console.log('[QuickMessages] 📝 insertTextAtCursor: contentEditable');
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
        console.log('[QuickMessages] ✅ insertTextAtCursor: texto inserido em contentEditable');
        return true;
      } else if (element.tagName == 'INPUT' || element.tagName == 'TEXTAREA') {
        console.log('[QuickMessages] 📝 insertTextAtCursor: INPUT/TEXTAREA');
        var start = element.selectionStart || 0;
        var end = element.selectionEnd || 0;
        var value = element.value || '';
        element.value = value.substring(0, start) + text + value.substring(end);
        element.selectionStart = start + text.length;
        element.selectionEnd = start + text.length;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        console.log('[QuickMessages] ✅ insertTextAtCursor: texto inserido em INPUT/TEXTAREA');
        return true;
      }
    } catch (e) {
      console.log('[QuickMessages] ❌ insertTextAtCursor: erro - ' + e);
    }
    return false;
  }

  function insertDirectInContentEditable(element, text) {
    if (!element || element.contentEditable != 'true') {
      console.log('[QuickMessages] ❌ insertDirectInContentEditable: elemento inválido');
      return false;
    }
    try {
      // ✅ Substitui placeholders antes de inserir
      text = replacePlaceholders(text);
      
      console.log('[QuickMessages] 📝 insertDirectInContentEditable: inserindo texto');
      element.focus();
      element.textContent = text;
      element.dispatchEvent(new Event('input', { bubbles: true }));
      console.log('[QuickMessages] ✅ insertDirectInContentEditable: texto inserido');
      return true;
    } catch (e) {
      console.log('[QuickMessages] ❌ insertDirectInContentEditable: erro - ' + e);
      return false;
    }
  }

  function handleShortcutResolved(shortcutKey, mensagem, target, messageId) {
    console.log('[QuickMessages] 🎯 handleShortcutResolved chamado');
    console.log('[QuickMessages]   └─ Atalho: ' + shortcutKey);
    console.log('[QuickMessages]   └─ Host: ' + window.location.host);
    console.log('[QuickMessages]   └─ Mensagem: ' + mensagem.substring(0, 50) + (mensagem.length > 50 ? '...' : ''));
    console.log('[QuickMessages]   └─ MessageId: ' + (messageId || 'N/A'));
    
    // ✅ Incrementa contador de uso se messageId estiver disponível
    if (messageId) {
      try {
        if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
          window.flutter_inappwebview.callHandler('incrementMessageUsage', {messageId: messageId, shortcut: shortcutKey}).catch(function(err) {
            console.log('[QuickMessages] ⚠️ Erro ao incrementar uso: ' + err);
          });
        }
      } catch (err) {
        console.log('[QuickMessages] ⚠️ Erro ao chamar incrementMessageUsage: ' + err);
      }
    }
    
    // ✅ Função auxiliar para fazer backup do clipboard
    function backupClipboard() {
      return new Promise(function(resolve) {
        try {
          if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
            window.flutter_inappwebview.callHandler('backupClipboard').then(function(result) {
              if (result && result.success) {
                console.log('[QuickMessages] 📋 Clipboard backup criado');
                resolve(true);
              } else {
                console.log('[QuickMessages] ⚠️ Falha ao criar backup do clipboard');
                resolve(false);
              }
            }).catch(function(err) {
              console.log('[QuickMessages] ⚠️ Erro ao chamar backupClipboard: ' + err);
              resolve(false);
            });
          } else {
            console.log('[QuickMessages] ⚠️ Flutter handler não disponível para backup');
            resolve(false);
          }
        } catch (e) {
          console.log('[QuickMessages] ⚠️ Erro ao fazer backup do clipboard: ' + e);
          resolve(false);
        }
      });
    }
    
    // ✅ Função auxiliar para restaurar o clipboard
    function restoreClipboard() {
      return new Promise(function(resolve) {
        try {
          if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
            window.flutter_inappwebview.callHandler('restoreClipboard').then(function(result) {
              if (result && result.success) {
                console.log('[QuickMessages] 📋 Clipboard restaurado');
                resolve(true);
              } else {
                console.log('[QuickMessages] ⚠️ Falha ao restaurar clipboard');
                resolve(false);
              }
            }).catch(function(err) {
              console.log('[QuickMessages] ⚠️ Erro ao chamar restoreClipboard: ' + err);
              resolve(false);
            });
          } else {
            console.log('[QuickMessages] ⚠️ Flutter handler não disponível para restauração');
            resolve(false);
          }
        } catch (e) {
          console.log('[QuickMessages] ⚠️ Erro ao restaurar clipboard: ' + e);
          resolve(false);
        }
      });
    }
    
    // ✅ Substitui placeholders na mensagem antes de inserir
    var mensagemProcessada = replacePlaceholders(mensagem);
    
    // ✅ Faz backup do clipboard antes de inserir mensagem
    backupClipboard().then(function(backupSuccess) {
      // 1) WhatsApp Web: usar modo específico
      if (window.location.host == 'web.whatsapp.com') {
        console.log('[QuickMessages] 🌐 WhatsApp Web detectado, usando inserção específica');
        var ok = insertWhatsAppMessage(mensagemProcessada, shortcutKey);
        if (ok) {
          console.log('[QuickMessages] ✅ Mensagem inserida via modo WhatsApp Web');
          // ✅ Restaura clipboard após inserir
          setTimeout(function() {
            restoreClipboard();
          }, 500);
          return;
        } else {
          console.log('[QuickMessages] ⚠️ Falha no modo WhatsApp Web, usando genérico...');
        }
      }
      
      // 2) Outros sites: lógica genérica
      console.log('[QuickMessages] 📝 Tentando inserção genérica');
      var okGeneric = false;
      try {
        okGeneric = insertTextAtCursor(target, mensagemProcessada);
      } catch (e) {
        console.log('[QuickMessages] ⚠️ Erro em insertTextAtCursor: ' + e);
      }
      
      if (!okGeneric) {
        try {
          insertDirectInContentEditable(target, mensagemProcessada);
          console.log('[QuickMessages] ✅ Mensagem inserida via fallback genérico');
        } catch (e) {
          console.log('[QuickMessages] ❌ Falha total na inserção: ' + e);
        }
      } else {
        console.log('[QuickMessages] ✅ Mensagem inserida via insertTextAtCursor');
      }
      
      // ✅ Restaura clipboard após inserir (com delay para garantir que a inserção terminou)
      setTimeout(function() {
        restoreClipboard();
      }, 500);
    });
  }

  function resetAccumulator() {
    accumulatedText = '';
    keyCount = 0;
  }

  function findActiveTextInput() {
    console.log('[QuickMessages] 🔍 Procurando campo de texto ativo...');
    var activeElement = document.activeElement;
    if (activeElement) {
      console.log('[QuickMessages]   └─ activeElement encontrado: ' + (activeElement.tagName || 'contentEditable'));
      if (activeElement.contentEditable == 'true' || 
          activeElement.tagName == 'INPUT' || 
          activeElement.tagName == 'TEXTAREA') {
        console.log('[QuickMessages] ✅ Usando activeElement');
        return activeElement;
      }
    }
    var all = document.querySelectorAll('div[contenteditable="true"], textarea, input[type="text"]');
    console.log('[QuickMessages]   └─ Campos encontrados: ' + all.length);
    var visible = [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      var style = window.getComputedStyle(el);
      if (style.display != 'none' && style.visibility != 'hidden' && style.opacity != '0') {
        visible.push(el);
      }
    }
    console.log('[QuickMessages]   └─ Campos visíveis: ' + visible.length);
    if (visible.length > 0) {
      console.log('[QuickMessages] ✅ Usando último campo visível');
      return visible[visible.length - 1];
    }
    console.log('[QuickMessages] ❌ Nenhum campo encontrado');
    return null;
  }

  document.addEventListener('keydown', function(e) {
    // Se pressionar a tecla de ativação, reinicia o acumulador
    if (e.key == ACTIVATION_KEY && !e.ctrlKey && !e.metaKey && !e.altKey) {
      resetAccumulator();
      accumulatedText = ACTIVATION_KEY;
      keyCount = 0;
      // Notifica que o atalho foi ativado
      try {
        if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
          window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'activated'});
        }
      } catch (err) {
        console.log('[QuickMessages] Erro ao notificar ativação: ' + err);
      }
      return;
    }
    
    // Se o atalho está ativado (começou com a tecla de ativação)
    if (accumulatedText.indexOf(ACTIVATION_KEY) == 0) {
      // Trata Backspace/Delete - decrementa o contador
      if (e.key == 'Backspace' || e.key == 'Delete') {
        if (accumulatedText.length > 1) {
          accumulatedText = accumulatedText.substring(0, accumulatedText.length - 1);
          keyCount = keyCount > 0 ? keyCount - 1 : 0;
          console.log('[QuickMessages] 🔙 Backspace pressionado. Caracteres restantes: ' + keyCount + '/' + MAX_KEYS);
          // Notifica atualização das teclas digitadas
          var shortcutKey = accumulatedText.substring(1);
          try {
            if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'typing', shortcut: shortcutKey, keyCount: keyCount, maxKeys: MAX_KEYS});
            }
          } catch (err) {
            console.log('[QuickMessages] Erro ao notificar teclas digitadas: ' + err);
          }
        } else {
          // Se só resta a tecla de ativação, reseta
          resetAccumulator();
        }
        return;
      }
      
      // Se é uma tecla de caractere válida
      if (e.key.length == 1) {
        // Verifica se já atingiu o limite antes de permitir adicionar mais um caractere
        if (keyCount >= MAX_KEYS) {
          console.log('[QuickMessages] ⚠️ Limite de caracteres atingido (' + MAX_KEYS + '). Desativando atalho.');
          resetAccumulator();
          // Notifica que não foi encontrado
          try {
            if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'notFound'});
            }
          } catch (err) {
            console.log('[QuickMessages] Erro ao notificar atalho não encontrado: ' + err);
          }
          return;
        }
        
        // Adiciona o caractere ao acumulador
        accumulatedText = accumulatedText + e.key;
        keyCount = keyCount + 1;
        var shortcutKey = accumulatedText.substring(1);
        console.log('[QuickMessages] 🔍 Verificando atalho: "' + shortcutKey + '" (caracteres: ' + keyCount + '/' + MAX_KEYS + ')');
        console.log('[QuickMessages]   └─ Atalhos disponíveis: ' + Object.keys(shortcuts).join(', '));
        
        // Notifica atualização das teclas digitadas
        try {
          if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
            window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'typing', shortcut: shortcutKey, keyCount: keyCount, maxKeys: MAX_KEYS});
          }
        } catch (err) {
          console.log('[QuickMessages] Erro ao notificar teclas digitadas: ' + err);
        }
        
        // Verifica se encontrou um atalho
        if (shortcuts[shortcutKey]) {
          console.log('[QuickMessages] ✅✅✅ ATALHO ENCONTRADO: "' + shortcutKey + '" ✅✅✅');
          
          // ✅ Obtém ID da mensagem para incrementar contador de uso
          var messageId = null;
          var messageData = shortcutsData[shortcutKey];
          if (messageData && messageData.id) {
            messageId = messageData.id;
          }
          
          // Notifica que o atalho foi encontrado
          try {
            if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'found', shortcut: shortcutKey});
            }
          } catch (err) {
            console.log('[QuickMessages] Erro ao notificar atalho encontrado: ' + err);
          }
          // Previne que o texto do atalho seja digitado no campo
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          var target = findActiveTextInput();
          if (target) {
            console.log('[QuickMessages] ✅ Campo de texto encontrado: ' + (target.tagName || 'contentEditable'));
            // Para WhatsApp Web, não limpa o campo aqui - deixa a função específica fazer a substituição
            // Para outros sites, limpa o texto do atalho completo antes de inserir a mensagem
            if (window.location.host != 'web.whatsapp.com') {
              var atalhoCompleto = ACTIVATION_KEY + shortcutKey;
              try {
                if (target.contentEditable == 'true') {
                  var currentText = target.textContent || target.innerText || '';
                  // Remove o atalho completo do texto atual
                  if (currentText.indexOf(atalhoCompleto) >= 0) {
                    var novoTexto = currentText.replace(atalhoCompleto, '');
                    target.textContent = novoTexto;
                    target.innerText = novoTexto;
                    // Dispara evento para notificar a mudança
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                    console.log('[QuickMessages] 🧹 Atalho removido de contentEditable: "' + atalhoCompleto + '"');
                  }
                } else if (target.tagName == 'INPUT' || target.tagName == 'TEXTAREA') {
                  var currentValue = target.value || '';
                  // Remove o atalho completo do valor atual
                  if (currentValue.indexOf(atalhoCompleto) >= 0) {
                    target.value = currentValue.replace(atalhoCompleto, '');
                    // Dispara evento para notificar a mudança
                    target.dispatchEvent(new Event('input', { bubbles: true }));
                    console.log('[QuickMessages] 🧹 Atalho removido de INPUT/TEXTAREA: "' + atalhoCompleto + '"');
                  }
                }
              } catch (e) {
                console.log('[QuickMessages] ⚠️ Erro ao remover atalho: ' + e);
              }
            }
            handleShortcutResolved(shortcutKey, shortcuts[shortcutKey], target, messageId);
            resetAccumulator();
          } else {
            console.log('[QuickMessages] ❌ Campo de texto não encontrado');
            resetAccumulator();
          }
        } else {
          // Verifica se há correspondência parcial (atalho que ainda pode ser completado)
          var hasPartialMatch = false;
          for (var key in shortcuts) {
            if (key.indexOf(shortcutKey) == 0 && key.length > shortcutKey.length) {
              hasPartialMatch = true;
              break;
            }
          }
          
          // Se atingiu o limite de caracteres e não encontrou atalho, desativa
          if (keyCount >= MAX_KEYS) {
            console.log('[QuickMessages] ⚠️ Atalho não encontrado após ' + MAX_KEYS + ' caracteres: "' + shortcutKey + '"');
            resetAccumulator();
            try {
              if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
                window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'notFound'});
              }
            } catch (err) {
              console.log('[QuickMessages] Erro ao notificar atalho não encontrado: ' + err);
            }
          } else if (!hasPartialMatch && shortcutKey.length > 0) {
            // Não há correspondência parcial, mas ainda pode digitar mais caracteres
            console.log('[QuickMessages] ⚠️ Atalho não encontrado ainda: "' + shortcutKey + '". Continuando...');
          }
        }
      }
    }
  }, true);

  console.log('[QuickMessages] Script carregado');
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

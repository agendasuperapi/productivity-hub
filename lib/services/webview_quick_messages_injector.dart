import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';
import 'dart:convert';
import '../models/quick_message.dart';

/// Serviço para injetar suporte a mensagens rápidas no WebView
class WebViewQuickMessagesInjector {
  List<QuickMessage> _messages = [];
  String _activationKey = '/';
  Map<String, String> _keywords = {}; // ✅ Palavras-chave customizadas

  /// Injeta o script no WebView com as mensagens fornecidas
  /// ✅ Agora recebe mensagens como parâmetro para não depender do Supabase
  Future<void> injectQuickMessagesSupport(
    InAppWebViewController controller, {
    String activationKey = '/',
    List<QuickMessage>? messages,
    Map<String, String>? keywords, // ✅ Palavras-chave customizadas
    String? tabName,
    String? url,
  }) async {
    _activationKey = activationKey;
    _messages = messages ?? [];
    _keywords = keywords ?? {};
    
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
    final script = await _createInjectionScript();
    
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
  Future<String> _createInjectionScript() async {
    // Cria um mapa de atalhos para mensagens (inclui ID, mensagem e imagem)
    final shortcutsMap = <String, Map<String, String>>{};
    final shortcutsMessageMap = <String, String>{};
    final shortcutsImageMap = <String, String>{}; // ✅ Mapa de atalhos para imagens (base64)
    
    // ✅ Processa mensagens e imagens de forma assíncrona
    for (final message in _messages) {
      final shortcut = message.shortcut.toLowerCase();
      shortcutsMap[shortcut] = {
        'id': message.id,
        'message': message.message,
      };
      shortcutsMessageMap[shortcut] = message.message;
      // ✅ Se houver imagem, converte para base64
      if (message.imagePath != null && message.imagePath!.isNotEmpty) {
        try {
          final imageFile = File(message.imagePath!);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final base64Image = base64Encode(imageBytes);
            // Detecta o tipo MIME da imagem
            final extension = message.imagePath!.split('.').last.toLowerCase();
            String mimeType = 'image/jpeg';
            if (extension == 'png') mimeType = 'image/png';
            else if (extension == 'gif') mimeType = 'image/gif';
            else if (extension == 'webp') mimeType = 'image/webp';
            shortcutsImageMap[shortcut] = 'data:$mimeType;base64,$base64Image';
          }
        } catch (e) {
          debugPrint('[QuickMessages] Erro ao ler imagem: $e');
        }
      }
    }

    // Converte para JSON e escapa corretamente (mapa de IDs)
    final shortcutsJson = shortcutsMap.entries.map((e) {
      final key = e.key.replaceAll('"', '\\"');
      final id = e.value['id']!.replaceAll('"', '\\"');
      final value = e.value['message']!
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\$', '\\\$')
          .replaceAll('`', '\\`')
          .replaceAll('^', '\\^')
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
          .replaceAll('\$', '\\\$')
          .replaceAll('`', '\\`')
          .replaceAll('^', '\\^')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      return '"$key": "$value"';
    }).join(', ');

    final activationKeyEscaped = _activationKey.replaceAll('"', '\\"');
    
    // ✅ Converte keywords para JSON (se não estiver vazio)
    final keywordsJson = _keywords.isEmpty 
        ? ''
        : _keywords.entries.map((e) {
            final key = e.key.replaceAll('"', '\\"');
            final value = e.value
                .replaceAll('\\', '\\\\')
                .replaceAll('"', '\\"')
                .replaceAll(r'$', r'\$')  // ✅ Usa raw string para evitar problemas
                .replaceAll('`', '\\`')
                .replaceAll('^', '\\^')
                .replaceAll('\n', '\\n')
                .replaceAll('\r', '\\r');
            return '"$key": "$value"';
          }).join(', ');
    
    // ✅ Prepara keywordsJson para inserção no JavaScript (evita problemas com interpolação)
    final keywordsJsonForJS = keywordsJson.isEmpty ? '' : keywordsJson;
    
    // ✅ Converte imagens para JSON (base64)
    final shortcutsImageJson = shortcutsImageMap.entries.map((e) {
      final key = e.key.replaceAll('"', '\\"');
      final value = e.value.replaceAll('"', '\\"').replaceAll('\\', '\\\\');
      return '"$key": "$value"';
    }).join(', ');
    
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
        },
        keywords: {
          $keywordsJsonForJS
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
  // ✅ Palavras-chave customizadas
  var keywords = {
    $keywordsJsonForJS
  };
  // ✅ Mapa de imagens (base64) para anexar
  var shortcutsImages = {
    $shortcutsImageJson
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
    if (config.keywords) {
      keywords = config.keywords;
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
    
    // ✅ Substitui <SAUDACAO> pela saudação apropriada (padrão do sistema)
    var saudacaoPattern = /<SAUDACAO>/gi;
    if (saudacaoPattern.test(result)) {
      var greeting = getGreeting();
      result = result.replace(saudacaoPattern, greeting);
      console.log('[QuickMessages] ✅ <SAUDACAO> substituído por: ' + greeting);
    }
    
    // ✅ Debug: mostra palavras-chave disponíveis
    var keywordsCount = Object.keys(keywords).length;
    if (keywordsCount > 0) {
      console.log('[QuickMessages] 🔑 Palavras-chave disponíveis: ' + keywordsCount);
      for (var k in keywords) {
        console.log('[QuickMessages]   └─ ' + k + ' = ' + keywords[k]);
      }
      console.log('[QuickMessages] 📝 Texto antes da substituição: "' + result + '"');
    } else {
      console.log('[QuickMessages] ⚠️ Nenhuma palavra-chave disponível');
    }
    
    // ✅ Substitui palavras-chave customizadas
    // As chaves já vêm com < > do getKeywordsMap (ex: '<PIX>', '<RAZÃO>')
    for (var key in keywords) {
      if (keywords.hasOwnProperty(key)) {
        // ✅ A chave já contém < e >, então procura diretamente por ela
        // Também procura variações case-insensitive
        var keyUpper = key.toUpperCase();
        var keyLower = key.toLowerCase();
        
        // ✅ Usa substituição simples de string (mais confiável que regex)
        var originalResult = result;
        
        // Substitui a chave exata
        if (result.indexOf(key) !== -1) {
          result = result.split(key).join(keywords[key]);
          console.log('[QuickMessages] ✅ "' + key + '" substituído por: "' + keywords[key] + '"');
        }
        // Substitui versão maiúscula
        if (keyUpper !== key && result.indexOf(keyUpper) !== -1) {
          result = result.split(keyUpper).join(keywords[key]);
          console.log('[QuickMessages] ✅ "' + keyUpper + '" substituído por: "' + keywords[key] + '"');
        }
        // Substitui versão minúscula
        if (keyLower !== key && result.indexOf(keyLower) !== -1) {
          result = result.split(keyLower).join(keywords[key]);
          console.log('[QuickMessages] ✅ "' + keyLower + '" substituído por: "' + keywords[key] + '"');
        }
      }
    }
    
    if (keywordsCount > 0) {
      console.log('[QuickMessages] 📝 Texto após substituição: "' + result + '"');
    }
    
    return result;
  }

  // ✅ Função para anexar imagem no WhatsApp
  function attachImageToWhatsApp(imageDataUrl, callback) {
    console.log('[QuickMessages] 🖼️ Tentando anexar imagem no WhatsApp');
    
    try {
      // Converte data URL para Blob
      function dataURLtoBlob(dataurl) {
        var arr = dataurl.split(',');
        var mime = arr[0].match(/:(.*?);/)[1];
        var bstr = atob(arr[1]);
        var n = bstr.length;
        var u8arr = new Uint8Array(n);
        while (n--) {
          u8arr[n] = bstr.charCodeAt(n);
        }
        return new Blob([u8arr], {type: mime});
      }
      
      var blob = dataURLtoBlob(imageDataUrl);
      var file = new File([blob], 'image.jpg', {type: blob.type});
      
      // Encontra o botão de anexar (clip) no WhatsApp
      var attachButton = document.querySelector('span[data-icon="clip"]') || 
                        document.querySelector('button[aria-label*="Anexar"]') ||
                        document.querySelector('div[title*="Anexar"]') ||
                        document.querySelector('div[title*="Attach"]');
      
      if (!attachButton) {
        console.log('[QuickMessages] ❌ Botão de anexar não encontrado');
        if (callback) callback(false);
        return false;
      }
      
      // Cria um input file temporário
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.style.display = 'none';
      
      // Cria um DataTransfer para simular o arquivo
      var dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);
      input.files = dataTransfer.files;
      
      // Adiciona o input ao DOM temporariamente
      document.body.appendChild(input);
      
      // Simula o clique no botão de anexar
      attachButton.click();
      
      // Aguarda o menu aparecer e então clica em "Fotos e vídeos"
      setTimeout(function() {
        // Procura pelo item "Fotos e vídeos" no menu de forma mais precisa
        var photosMenuItem = null;
        
        // Primeiro, tenta encontrar todos os itens do menu de anexos
        var menuContainer = document.querySelector('div[role="menu"]') ||
                           document.querySelector('div[data-testid*="menu"]') ||
                           document.querySelector('ul[role="menu"]');
        
        var menuItems = [];
        if (menuContainer) {
          menuItems = Array.from(menuContainer.querySelectorAll('div[role="menuitem"], div[role="button"], li[role="menuitem"]'));
        } else {
          // Se não encontrou container, procura todos os itens possíveis
          menuItems = Array.from(document.querySelectorAll('div[role="menuitem"], div[role="button"]'));
        }
        
        console.log('[QuickMessages] 🖼️ Itens do menu encontrados: ' + menuItems.length);
        
        // Procura especificamente por "Fotos e vídeos" ou "Photos and videos"
        for (var i = 0; i < menuItems.length; i++) {
          var item = menuItems[i];
          var text = (item.innerText || item.textContent || '').toLowerCase();
          var ariaLabel = (item.getAttribute('aria-label') || '').toLowerCase();
          var title = (item.getAttribute('title') || '').toLowerCase();
          var fullText = text + ' ' + ariaLabel + ' ' + title;
          
          console.log('[QuickMessages] 🖼️ Item ' + i + ': ' + (item.innerText || item.textContent || 'sem texto'));
          
          // Procura especificamente por "fotos e vídeos" ou "photos and videos"
          // E exclui "figurinha", "sticker", "documento", "document"
          if ((fullText.indexOf('fotos e vídeos') !== -1 || 
               fullText.indexOf('photos and videos') !== -1 ||
               fullText.indexOf('photos & videos') !== -1 ||
               (fullText.indexOf('fotos') !== -1 && fullText.indexOf('vídeos') !== -1) ||
               (fullText.indexOf('photos') !== -1 && fullText.indexOf('videos') !== -1)) &&
              fullText.indexOf('figurinha') === -1 &&
              fullText.indexOf('sticker') === -1 &&
              fullText.indexOf('documento') === -1 &&
              fullText.indexOf('document') === -1) {
            photosMenuItem = item;
            console.log('[QuickMessages] 🖼️ ✅ Item "Fotos e vídeos" encontrado no índice ' + i + ': ' + (item.innerText || item.textContent));
            break;
          }
        }
        
        // Se não encontrou por texto exato, tenta encontrar pelo segundo item (geralmente é "Fotos e vídeos")
        // Mas só se o primeiro não for "Fotos e vídeos"
        if (!photosMenuItem && menuItems.length > 1) {
          var firstItemText = (menuItems[0].innerText || menuItems[0].textContent || '').toLowerCase();
          // Se o primeiro item não é "Fotos e vídeos", tenta o segundo
          if (firstItemText.indexOf('fotos e vídeos') === -1 && 
              firstItemText.indexOf('photos and videos') === -1 &&
              firstItemText.indexOf('documento') !== -1) {
            photosMenuItem = menuItems[1];
            console.log('[QuickMessages] 🖼️ Usando segundo item do menu (índice 1)');
          }
        }
        
        // Se ainda não encontrou, tenta procurar por input file diretamente
        if (!photosMenuItem) {
          var whatsappFileInput = document.querySelector('input[type="file"][accept*="image"]') ||
                                 document.querySelector('input[type="file"][accept*="video"]') ||
                                 document.querySelector('input[type="file"]');
          
          if (whatsappFileInput) {
            console.log('[QuickMessages] 🖼️ Input file encontrado diretamente, anexando...');
            // Substitui os arquivos do input do WhatsApp
            var newDataTransfer = new DataTransfer();
            newDataTransfer.items.add(file);
            whatsappFileInput.files = newDataTransfer.files;
            
            // Dispara evento change
            var changeEvent = new Event('change', {bubbles: true});
            whatsappFileInput.dispatchEvent(changeEvent);
            
            console.log('[QuickMessages] ✅ Imagem anexada com sucesso');
            document.body.removeChild(input);
            if (callback) callback(true);
            return;
          }
        }
        
        if (photosMenuItem) {
          // Clica no item "Fotos e vídeos"
          console.log('[QuickMessages] 🖼️ Clicando no item: ' + (photosMenuItem.innerText || photosMenuItem.textContent));
          photosMenuItem.click();
          
          // Aguarda o input file aparecer após clicar
          setTimeout(function() {
            var whatsappFileInput = document.querySelector('input[type="file"][accept*="image"]') ||
                                   document.querySelector('input[type="file"][accept*="video"]') ||
                                   document.querySelector('input[type="file"]');
            
            if (whatsappFileInput) {
              // Substitui os arquivos do input do WhatsApp
              var newDataTransfer = new DataTransfer();
              newDataTransfer.items.add(file);
              whatsappFileInput.files = newDataTransfer.files;
              
              // Dispara evento change
              var changeEvent = new Event('change', {bubbles: true});
              whatsappFileInput.dispatchEvent(changeEvent);
              
              console.log('[QuickMessages] ✅ Imagem anexada com sucesso');
              document.body.removeChild(input);
              if (callback) callback(true);
            } else {
              console.log('[QuickMessages] ⚠️ Input file não encontrado após clicar em "Fotos e vídeos"');
              document.body.removeChild(input);
              if (callback) callback(false);
            }
          }, 500);
        } else {
          console.log('[QuickMessages] ⚠️ Item "Fotos e vídeos" não encontrado no menu. Itens disponíveis:');
          for (var j = 0; j < menuItems.length; j++) {
            console.log('[QuickMessages]   - Item ' + j + ': ' + (menuItems[j].innerText || menuItems[j].textContent || 'sem texto'));
          }
          document.body.removeChild(input);
          if (callback) callback(false);
        }
      }, 400);
      
      return true;
    } catch (e) {
      console.log('[QuickMessages] ❌ Erro ao anexar imagem: ' + e);
      if (callback) callback(false);
      return false;
    }
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
    
    // ✅ Detecta múltiplos textos separados por |||MULTI_TEXT_SEPARATOR|||
    var separator = '|||MULTI_TEXT_SEPARATOR|||';
    var isMultiText = fullText.indexOf(separator) !== -1;
    var texts = isMultiText ? fullText.split(separator) : [fullText];
    
    console.log('[QuickMessages] 📝 Múltiplos textos detectados: ' + isMultiText + ' (total: ' + texts.length + ')');
    
    // ✅ Se houver múltiplos textos, insere cada um separadamente com Enter
    if (isMultiText && texts.length > 1) {
      console.log('[QuickMessages] 📝 Inserindo ' + texts.length + ' textos separadamente');
      insertMultipleTexts(editor, texts, shortcutTyped);
      return true;
    }
    
    // Normaliza quebras de linha (para texto único)
    var message = String(fullText).replace(/\\r\\n/g, '\\n');
    
    // Texto atual no campo (já deve ter o atalho removido pelos backspaces simulados)
    var current = editor.innerText || editor.textContent || '';
    console.log('[QuickMessages] 📝 Texto atual no campo (após backspaces): "' + current + '"');
    
    // ✅ Como os backspaces já foram simulados, apenas adiciona a mensagem ao texto existente
    // ✅ Se o campo ainda contém o atalho (caso os backspaces não funcionaram), tenta removê-lo
    var newText = current;
    
    if (shortcutTyped) {
      // ✅ Converte para minúsculas para comparação case-insensitive
      var shortcutTypedLower = shortcutTyped.toLowerCase();
      var atalhoCompleto = ACTIVATION_KEY + shortcutTyped;
      var atalhoCompletoLower = ACTIVATION_KEY + shortcutTypedLower;
      
      // ✅ Verifica se ainda contém o atalho completo (case-insensitive)
      var currentLower = current.toLowerCase();
      if (currentLower.indexOf(atalhoCompletoLower) >= 0) {
        // Remove apenas o atalho completo (preserva o case original do texto)
        var index = currentLower.indexOf(atalhoCompletoLower);
        newText = current.substring(0, index) + current.substring(index + atalhoCompleto.length);
        console.log('[QuickMessages] 🔄 Atalho ainda presente, removendo: "' + atalhoCompleto + '"');
      } else if (current.indexOf(ACTIVATION_KEY) == 0) {
        // Se começa com / mas não tem o atalho completo, pode ser um atalho parcial
        // Remove apenas a parte que começa com / até encontrar espaço ou fim
        var atalhoLength = ACTIVATION_KEY.length + shortcutTyped.length;
        if (current.length >= atalhoLength) {
          // ✅ Verifica se os primeiros caracteres correspondem ao atalho (case-insensitive)
          var prefixo = current.substring(0, atalhoLength);
          var prefixoLower = prefixo.toLowerCase();
          if (prefixoLower.indexOf(atalhoCompletoLower) == 0) {
            newText = current.substring(atalhoLength);
            console.log('[QuickMessages] 🔄 Removendo atalho parcial: "' + prefixo + '"');
          } else {
            // Se não corresponde exatamente, remove apenas até encontrar espaço ou fim da linha
            var spaceIndex = current.indexOf(' ');
            if (spaceIndex > 0 && spaceIndex < current.length) {
              newText = current.substring(spaceIndex + 1);
            } else {
              // Se não há espaço, remove tudo que começa com /
              var slashIndex = current.indexOf(ACTIVATION_KEY);
              if (slashIndex == 0) {
                // Encontra o próximo espaço ou fim
                var nextSpace = current.indexOf(' ', slashIndex + 1);
                if (nextSpace > 0) {
                  newText = current.substring(nextSpace + 1);
                } else {
                  newText = '';
                }
              }
            }
          }
        }
      }
    }
    
    // ✅ Adiciona a mensagem ao texto existente (sem substituir tudo)
    newText = newText + message;
    console.log('[QuickMessages] 📝 Novo texto (preservando texto existente): "' + newText.substring(0, 60) + (newText.length > 60 ? '...' : '') + '"');
    
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
    
    // Abordagem 2: execCommand com seleção completa e CompositionEvent para Lexical
    function insertViaExecCommand() {
      try {
        // Limpa primeiro
        editor.textContent = '';
        editor.innerText = '';
        
        setTimeout(function() {
          // Seleciona tudo (mesmo vazio)
          editor.focus();
          
          // ✅ Dispara compositionstart para avisar o Lexical que vai haver input
          try {
            editor.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
          } catch (e) {}
          
          // Usa execCommand selectAll + insertText
          document.execCommand('selectAll', false, null);
          var inserted = document.execCommand('insertText', false, newText);
          
          if (inserted) {
            // ✅ Dispara compositionend com o texto - Lexical escuta isso
            try {
              editor.dispatchEvent(new CompositionEvent('compositionend', { 
                bubbles: true, 
                data: newText 
              }));
            } catch (e) {}
            
            // ✅ Dispara eventos input para confirmar a mudança
            setTimeout(function() {
              editor.dispatchEvent(new Event('input', { bubbles: true }));
              editor.dispatchEvent(new Event('change', { bubbles: true }));
              
              var finalText = editor.textContent || editor.innerText || '';
              if (finalText.length > 0 && finalText.indexOf('/') != 0 && finalText.length >= newText.length * 0.8) {
                console.log('[QuickMessages] ✅ Texto inserido via execCommand com CompositionEvent');
                return;
              }
            }, 100);
          }
        }, 50);
      } catch (e) {
        console.log('[QuickMessages] ⚠️ execCommand falhou: ' + e);
      }
    }
    
    // Abordagem 3: Manipulação direta dos nós filhos (para Lexical) com eventos corretos
    function insertViaDirectManipulation() {
      var attempts = 0;
      var maxAttempts = 3;
      
      function tryInsert() {
        attempts++;
        console.log('[QuickMessages] 🔄 Tentativa ' + attempts + ' de inserção direta');
        
        try {
          editor.focus();
          
          // ✅ Dispara compositionstart antes de modificar
          try {
            editor.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
          } catch (e) {}
          
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
          
          // ✅ Posiciona cursor no final
          try {
            var range = document.createRange();
            var sel = window.getSelection();
            range.setStart(textNode, textNode.length);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
          } catch (e) {}
          
          // ✅ Dispara compositionend para confirmar no Lexical
          try {
            editor.dispatchEvent(new CompositionEvent('compositionend', { 
              bubbles: true, 
              data: newText 
            }));
          } catch (e) {}
          
          // Dispara eventos na ordem correta
          var before = new InputEvent('beforeinput', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertFromPaste',
            data: newText
          });
          editor.dispatchEvent(before);
          
          var input = new InputEvent('input', {
            bubbles: true,
            cancelable: false,
            inputType: 'insertFromPaste',
            data: newText
          });
          editor.dispatchEvent(input);
          
          editor.dispatchEvent(new Event('input', { bubbles: true }));
          editor.dispatchEvent(new Event('change', { bubbles: true }));
          
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

  function simulateBackspaces(element, count) {
    if (!element) return false;
    try {
      // ✅ Garante que o elemento está focado antes de simular backspaces
      element.focus();
      
      if (element.contentEditable == 'true') {
        // Para contentEditable, simula backspaces usando deleteContents
        var selection = window.getSelection();
        if (selection.rangeCount > 0) {
          var range = selection.getRangeAt(0);
          // Move o range para trás pelo número de caracteres
          try {
            var startOffset = range.startOffset;
            var startContainer = range.startContainer;
            // Se o container é o próprio elemento, precisa calcular a posição correta
            if (startContainer === element || startContainer.nodeType === 1) {
              var currentText = element.textContent || element.innerText || '';
              if (currentText.length >= count) {
                // Remove os últimos caracteres
                element.textContent = currentText.substring(0, currentText.length - count);
                element.innerText = currentText.substring(0, currentText.length - count);
                // Posiciona o cursor no final
                var newRange = document.createRange();
                var textNode = element.firstChild;
                if (textNode && textNode.nodeType === 3) {
                  var newLength = textNode.length;
                  newRange.setStart(textNode, newLength);
                  newRange.setEnd(textNode, newLength);
                  selection.removeAllRanges();
                  selection.addRange(newRange);
                }
                element.dispatchEvent(new Event('input', { bubbles: true }));
                console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em contentEditable');
                return true;
              }
            } else {
              // Tenta usar o método de range
              var newStart = Math.max(0, startOffset - count);
              range.setStart(startContainer, newStart);
              range.deleteContents();
              selection.removeAllRanges();
              selection.addRange(range);
              element.dispatchEvent(new Event('input', { bubbles: true }));
              console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em contentEditable (método range)');
              return true;
            }
          } catch (e) {
            // Se falhar, tenta método alternativo simples
            var currentText = element.textContent || element.innerText || '';
            if (currentText.length >= count) {
              element.textContent = currentText.substring(0, currentText.length - count);
              element.innerText = currentText.substring(0, currentText.length - count);
              element.dispatchEvent(new Event('input', { bubbles: true }));
              console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em contentEditable (método alternativo)');
              return true;
            }
          }
        } else {
          // Se não há seleção, tenta método direto
          var currentText = element.textContent || element.innerText || '';
          if (currentText.length >= count) {
            element.textContent = currentText.substring(0, currentText.length - count);
            element.innerText = currentText.substring(0, currentText.length - count);
            element.dispatchEvent(new Event('input', { bubbles: true }));
            console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em contentEditable (sem seleção)');
            return true;
          }
        }
      } else if (element.tagName == 'INPUT' || element.tagName == 'TEXTAREA') {
        // Para INPUT/TEXTAREA, simula backspaces ajustando selectionStart
        var start = element.selectionStart || 0;
        var end = element.selectionEnd || 0;
        var value = element.value || '';
        if (start >= count) {
          var newStart = start - count;
          element.value = value.substring(0, newStart) + value.substring(end);
          element.selectionStart = newStart;
          element.selectionEnd = newStart;
          element.dispatchEvent(new Event('input', { bubbles: true }));
          console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em INPUT/TEXTAREA');
          return true;
        } else if (value.length >= count) {
          // Se o cursor está no início ou antes do atalho, remove do final
          var newLength = value.length - count;
          element.value = value.substring(0, newLength);
          element.selectionStart = newLength;
          element.selectionEnd = newLength;
          element.dispatchEvent(new Event('input', { bubbles: true }));
          console.log('[QuickMessages] 🔙 Simulados ' + count + ' backspaces em INPUT/TEXTAREA (do final)');
          return true;
        }
      }
    } catch (e) {
      console.log('[QuickMessages] ⚠️ Erro ao simular backspaces: ' + e);
    }
    return false;
  }

  // ✅ Função para inserir múltiplos textos com Enter entre eles
  function insertMultipleTexts(editor, texts, shortcutTyped) {
    console.log('[QuickMessages] 📝 Inserindo múltiplos textos: ' + texts.length);
    
    // ✅ Remove o atalho do primeiro texto se necessário (case-insensitive)
    var current = editor.innerText || editor.textContent || '';
    if (shortcutTyped && current.indexOf(ACTIVATION_KEY) === 0) {
      var shortcutTypedLower = shortcutTyped.toLowerCase();
      var atalhoCompleto = ACTIVATION_KEY + shortcutTyped;
      var atalhoCompletoLower = ACTIVATION_KEY + shortcutTypedLower;
      var currentLower = current.toLowerCase();
      if (currentLower.indexOf(atalhoCompletoLower) === 0) {
        current = current.substring(atalhoCompleto.length);
      }
    }
    
    // Função recursiva para inserir textos sequencialmente
    function insertNext(index) {
      if (index >= texts.length) {
        console.log('[QuickMessages] ✅ Todos os textos inseridos');
        return;
      }
      
      var text = texts[index].trim();
      if (!text) {
        // Se o texto estiver vazio, pula para o próximo
        insertNext(index + 1);
        return;
      }
      
      console.log('[QuickMessages] 📝 Inserindo texto ' + (index + 1) + ' de ' + texts.length);
      
      // Normaliza quebras de linha
      text = String(text).replace(/\\r\\n/g, '\\n');
      
      // Insere o texto
      editor.focus();
      
      // Tenta inserir via Clipboard API primeiro
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
          var range = document.createRange();
          range.selectNodeContents(editor);
          var selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          
          var pasteEvent = new ClipboardEvent('paste', {
            bubbles: true,
            cancelable: true,
            clipboardData: new DataTransfer()
          });
          pasteEvent.clipboardData.setData('text/plain', text);
          editor.dispatchEvent(pasteEvent);
          
          setTimeout(function() {
            // Simula Enter para enviar (sempre, inclusive na última mensagem)
            console.log('[QuickMessages] ⏎ Simulando Enter para enviar texto ' + (index + 1));
            simulateEnter(editor);
            
            // Se não for o último texto, aguarda antes de inserir o próximo
            // ✅ macOS: Aumenta delay para garantir que a mensagem foi enviada antes da próxima
            var delay = navigator.platform.toLowerCase().includes('mac') ? 800 : 300;
            if (index < texts.length - 1) {
              setTimeout(function() {
                insertNext(index + 1);
              }, delay);
            } else {
              console.log('[QuickMessages] ✅ Último texto inserido e enviado');
            }
          }, 200);
        }).catch(function(error) {
          console.log('[QuickMessages] ⚠️ Erro ao usar clipboard, usando fallback: ' + error);
          // Fallback: inserção direta
          insertTextDirectly(editor, text);
          // ✅ macOS: Aumenta delay para garantir que a mensagem foi enviada
          var delay = navigator.platform.toLowerCase().includes('mac') ? 800 : 300;
          setTimeout(function() {
            simulateEnter(editor);
            if (index < texts.length - 1) {
              setTimeout(function() {
                insertNext(index + 1);
              }, delay);
            } else {
              console.log('[QuickMessages] ✅ Último texto inserido e enviado');
            }
          }, 200);
        });
      } else {
        // Fallback: inserção direta
        console.log('[QuickMessages] ⚠️ Clipboard API não disponível, usando inserção direta');
        insertTextDirectly(editor, text);
        // ✅ macOS: Aumenta delay para garantir que a mensagem foi enviada
        var delay = navigator.platform.toLowerCase().includes('mac') ? 800 : 300;
        setTimeout(function() {
          simulateEnter(editor);
          if (index < texts.length - 1) {
            setTimeout(function() {
              insertNext(index + 1);
            }, delay);
          } else {
            console.log('[QuickMessages] ✅ Último texto inserido e enviado');
          }
        }, 200);
      }
    }
    
    // Inicia inserção do primeiro texto
    insertNext(0);
  }
  
  // ✅ Função para simular Enter no WhatsApp
  function simulateEnter(editor) {
    try {
      // Tenta várias formas de simular Enter
      var enterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true,
        cancelable: true
      });
      
      editor.dispatchEvent(enterEvent);
      
      var enterUpEvent = new KeyboardEvent('keyup', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true,
        cancelable: true
      });
      
      editor.dispatchEvent(enterUpEvent);
      
      // Também tenta pressionar Enter diretamente
      setTimeout(function() {
        var pressEvent = new KeyboardEvent('keypress', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true,
          cancelable: true
        });
        editor.dispatchEvent(pressEvent);
      }, 50);
      
      console.log('[QuickMessages] ⏎ Enter simulado');
    } catch (e) {
      console.log('[QuickMessages] ⚠️ Erro ao simular Enter: ' + e);
    }
  }
  
  // ✅ Função auxiliar para inserir texto diretamente
  function insertTextDirectly(editor, text) {
    try {
      if (editor.contentEditable === 'true' || editor.isContentEditable) {
        var selection = window.getSelection();
        var range = selection.getRangeAt(0);
        range.deleteContents();
        var textNode = document.createTextNode(text);
        range.insertNode(textNode);
        range.setStartAfter(textNode);
        selection.removeAllRanges();
        selection.addRange(range);
        
        // Dispara evento de input
        var inputEvent = new Event('input', { bubbles: true });
        editor.dispatchEvent(inputEvent);
      } else if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
        editor.value = (editor.value || '') + text;
        var inputEvent = new Event('input', { bubbles: true });
        editor.dispatchEvent(inputEvent);
      }
    } catch (e) {
      console.log('[QuickMessages] ⚠️ Erro ao inserir texto diretamente: ' + e);
    }
  }
  
  // ✅ Função para inserir múltiplos textos em sites genéricos
  function insertMultipleTextsGeneric(target, texts, shortcutTyped) {
    console.log('[QuickMessages] 📝 Inserindo múltiplos textos genéricos: ' + texts.length);
    
    function insertNext(index) {
      if (index >= texts.length) {
        console.log('[QuickMessages] ✅ Todos os textos inseridos');
        return;
      }
      
      var text = texts[index].trim();
      if (!text) {
        insertNext(index + 1);
        return;
      }
      
      console.log('[QuickMessages] 📝 Inserindo texto ' + (index + 1) + ' de ' + texts.length);
      
      // Insere o texto
      var ok = false;
      try {
        ok = insertTextAtCursor(target, text);
      } catch (e) {
        console.log('[QuickMessages] ⚠️ Erro em insertTextAtCursor: ' + e);
      }
      
      if (!ok) {
        try {
          insertDirectInContentEditable(target, text);
        } catch (e) {
          console.log('[QuickMessages] ⚠️ Erro ao inserir texto: ' + e);
        }
      }
      
      // Simula Enter para enviar (sempre, inclusive na última mensagem)
      console.log('[QuickMessages] ⏎ Simulando Enter para enviar texto ' + (index + 1));
      // ✅ macOS: Aumenta delay para garantir que a mensagem foi enviada
      var delay = navigator.platform.toLowerCase().includes('mac') ? 800 : 300;
      setTimeout(function() {
        simulateEnterGeneric(target);
        if (index < texts.length - 1) {
          setTimeout(function() {
            insertNext(index + 1);
          }, delay);
        } else {
          console.log('[QuickMessages] ✅ Último texto inserido e enviado');
        }
      }, 200);
    }
    
    insertNext(0);
  }
  
  // ✅ Função para simular Enter em campos genéricos
  function simulateEnterGeneric(target) {
    try {
      var enterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true,
        cancelable: true
      });
      
      target.dispatchEvent(enterEvent);
      
      var enterUpEvent = new KeyboardEvent('keyup', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true,
        cancelable: true
      });
      
      target.dispatchEvent(enterUpEvent);
      
      setTimeout(function() {
        var pressEvent = new KeyboardEvent('keypress', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true,
          cancelable: true
        });
        target.dispatchEvent(pressEvent);
      }, 50);
      
      console.log('[QuickMessages] ⏎ Enter simulado (genérico)');
    } catch (e) {
      console.log('[QuickMessages] ⚠️ Erro ao simular Enter genérico: ' + e);
    }
  }

  function handleShortcutResolved(shortcutKey, mensagem, target, messageId) {
    console.log('[QuickMessages] 🎯 handleShortcutResolved chamado');
    console.log('[QuickMessages]   └─ Atalho: ' + shortcutKey);
    console.log('[QuickMessages]   └─ Host: ' + window.location.host);
    console.log('[QuickMessages]   └─ Mensagem: ' + mensagem.substring(0, 50) + (mensagem.length > 50 ? '...' : ''));
    console.log('[QuickMessages]   └─ MessageId: ' + (messageId || 'N/A'));
    
    // ✅ Verifica se há imagem para anexar
    var imageDataUrl = shortcutsImages[shortcutKey];
    var hasImage = imageDataUrl && imageDataUrl.length > 0;
    
    if (hasImage) {
      console.log('[QuickMessages] 🖼️ Imagem detectada para o atalho: ' + shortcutKey);
      // ✅ Anexa a imagem primeiro, depois envia a mensagem
      attachImageToWhatsApp(imageDataUrl, function(success) {
        if (success) {
          console.log('[QuickMessages] ✅ Imagem anexada, aguardando antes de enviar mensagem...');
          // Aguarda um pouco para a imagem ser processada antes de enviar a mensagem
          setTimeout(function() {
            processMessageAfterImage(mensagem, target, shortcutKey, messageId);
          }, 1000);
        } else {
          console.log('[QuickMessages] ⚠️ Falha ao anexar imagem, enviando apenas mensagem');
          processMessageAfterImage(mensagem, target, shortcutKey, messageId);
        }
      });
      return;
    }
    
    // ✅ Se não houver imagem, processa a mensagem normalmente
    processMessageAfterImage(mensagem, target, shortcutKey, messageId);
  }
  
  // ✅ Função auxiliar para processar mensagem (com ou sem imagem)
  function processMessageAfterImage(mensagem, target, shortcutKey, messageId) {
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
    
    // ✅ Detecta múltiplos textos separados por |||MULTI_TEXT_SEPARATOR|||
    var separator = '|||MULTI_TEXT_SEPARATOR|||';
    var isMultiText = mensagemProcessada.indexOf(separator) !== -1;
    var texts = isMultiText ? mensagemProcessada.split(separator) : [mensagemProcessada];
    
    console.log('[QuickMessages] 📝 Múltiplos textos detectados: ' + isMultiText + ' (total: ' + texts.length + ')');
    
    // ✅ Faz backup do clipboard antes de inserir mensagem
    backupClipboard().then(function(backupSuccess) {
      // ✅ Se houver múltiplos textos, usa lógica especial
      if (isMultiText && texts.length > 1) {
        console.log('[QuickMessages] 📝 Processando múltiplos textos');
        
        // 1) WhatsApp Web: usar modo específico
        if (window.location.host == 'web.whatsapp.com') {
          console.log('[QuickMessages] 🌐 WhatsApp Web detectado, usando inserção múltipla');
          var editor = getWhatsAppEditor();
          if (editor) {
            insertMultipleTexts(editor, texts, shortcutKey);
            setTimeout(function() {
              restoreClipboard();
            }, 500);
            return;
          }
        }
        
        // 2) Outros sites: inserção genérica múltipla
        insertMultipleTextsGeneric(target, texts, shortcutKey);
        setTimeout(function() {
          restoreClipboard();
        }, 500);
        return;
      }
      
      // ✅ Texto único: lógica original
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
    // ✅ Verificação robusta: só processa se o documento tem foco
    if (!document.hasFocus()) {
      console.log('[QuickMessages] ⚠️ Documento sem foco, ignorando busca de campo');
      return null;
    }
    
    console.log('[QuickMessages] 🔍 Procurando campo de texto ativo...');
    var activeElement = document.activeElement;
    if (activeElement) {
      console.log('[QuickMessages]   └─ activeElement encontrado: ' + (activeElement.tagName || 'contentEditable'));
      // ✅ Verificação mais rigorosa: o elemento deve estar realmente focado
      if ((activeElement.contentEditable == 'true' || 
           activeElement.tagName == 'INPUT' || 
           activeElement.tagName == 'TEXTAREA') &&
          activeElement !== document.body &&
          activeElement !== document.documentElement) {
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

  // ✅ CORREÇÃO DO DUPLO CLIQUE: Listener para marcar campos que acabaram de receber foco
  document.addEventListener('focusin', function(e) {
    var target = e.target;
    if (target && (target.tagName == 'INPUT' || target.tagName == 'TEXTAREA' || target.contentEditable == 'true')) {
      target.dataset.justFocused = 'true';
      setTimeout(function() {
        target.dataset.justFocused = 'false';
      }, 400); // ✅ Ignora eventos por 400ms após foco
    }
  }, true);

  // ✅ CORREÇÃO DO DUPLO CLIQUE: Adiciona delay para garantir que DOM está pronto
  // e verifica se há um campo de texto realmente focado antes de processar
  setTimeout(function() {
    document.addEventListener('keydown', function(e) {
      // ✅ IMPORTANTE: Verifica se o documento tem foco antes de processar qualquer evento
      if (!document.hasFocus()) {
        return;
      }
      
      // ✅ Verifica se há um campo de texto ativo antes de processar atalhos
      var activeEl = document.activeElement;
      var isInTextField = activeEl && (
        activeEl.contentEditable == 'true' || 
        activeEl.tagName == 'INPUT' || 
        activeEl.tagName == 'TEXTAREA'
      ) && activeEl !== document.body && activeEl !== document.documentElement;
      
      // ✅ CORREÇÃO DO DUPLO CLIQUE: Ignora eventos se o campo acabou de receber foco
      if (activeEl && activeEl.dataset && activeEl.dataset.justFocused == 'true') {
        console.log('[QuickMessages] ⚠️ Campo acabou de receber foco, ignorando evento');
        return;
      }
      
      // Se pressionar a tecla de ativação, reinicia o acumulador
      if (e.key == ACTIVATION_KEY && !e.ctrlKey && !e.metaKey && !e.altKey) {
        // ✅ Só processa se estiver em um campo de texto
        if (!isInTextField) {
          console.log('[QuickMessages] ⚠️ Tecla de ativação pressionada fora de campo de texto, ignorando');
          return;
        }
        
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
        // ✅ Converte para minúsculas para comparação case-insensitive
        var shortcutKeyLower = shortcutKey.toLowerCase();
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
        
        // ✅ Verifica se encontrou um atalho (case-insensitive)
        var foundShortcut = shortcuts[shortcutKeyLower];
        if (foundShortcut) {
          console.log('[QuickMessages] ✅✅✅ ATALHO ENCONTRADO: "' + shortcutKeyLower + '" ✅✅✅');
          
          // ✅ Obtém ID da mensagem para incrementar contador de uso
          var messageId = null;
          var messageData = shortcutsData[shortcutKeyLower];
          if (messageData && messageData.id) {
            messageId = messageData.id;
          }
          
          // Notifica que o atalho foi encontrado
          try {
            if (typeof window.flutter_inappwebview !== 'undefined' && window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler('quickMessageHint', {type: 'found', shortcut: shortcutKeyLower});
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
            // ✅ Simula backspaces para remover o texto do atalho antes de inserir a mensagem (tanto WhatsApp quanto outros sites)
            var atalhoCompleto = ACTIVATION_KEY + shortcutKey;
            // ✅ Subtrai 1 porque o último caractere já foi prevenido pelo preventDefault()
            var backspaceCount = atalhoCompleto.length - 1;
            console.log('[QuickMessages] 🔙 Simulando ' + backspaceCount + ' backspaces para remover atalho: "' + atalhoCompleto + '" (total: ' + atalhoCompleto.length + ', menos 1)');
            // Simula backspaces antes de inserir a mensagem
            simulateBackspaces(target, backspaceCount);
            // ✅ Aguarda um pouco para garantir que os backspaces foram processados antes de inserir a mensagem
            setTimeout(function() {
              handleShortcutResolved(shortcutKeyLower, foundShortcut, target, messageId);
            }, 50);
            resetAccumulator();
          } else {
            console.log('[QuickMessages] ❌ Campo de texto não encontrado');
            resetAccumulator();
          }
        } else {
          // ✅ Verifica se há correspondência parcial (atalho que ainda pode ser completado) - case-insensitive
          var hasPartialMatch = false;
          for (var key in shortcuts) {
            var keyLower = key.toLowerCase();
            if (keyLower.indexOf(shortcutKeyLower) == 0 && keyLower.length > shortcutKeyLower.length) {
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
  }, 500); // ✅ Delay aumentado de 300ms para 500ms para garantir que DOM está pronto

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

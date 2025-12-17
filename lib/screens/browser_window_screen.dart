import 'package:flutter/material.dart';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import '../models/saved_tab.dart';
import '../models/quick_message.dart';
import '../widgets/browser_webview_windows.dart';
import '../widgets/multi_page_webview.dart';
import '../models/browser_tab_windows.dart';
import '../utils/window_manager_helper.dart';
import '../services/local_tab_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Tela de navegador para uma janela separada (aberta a partir de uma aba salva)
class BrowserWindowScreen extends StatefulWidget {
  final SavedTab savedTab;
  final List<QuickMessage> quickMessages; // ✅ Mensagens rápidas obrigatórias (passadas como parâmetro)

  const BrowserWindowScreen({
    super.key,
    required this.savedTab,
    required this.quickMessages, // ✅ Obrigatório - sempre passado como parâmetro
  });

  @override
  State<BrowserWindowScreen> createState() => _BrowserWindowScreenState();
}

class _BrowserWindowScreenState extends State<BrowserWindowScreen> with WindowListener {
  BrowserTabWindows? _tab;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isPageLoading = false;
  late TextEditingController _urlController;
  final FocusNode _urlFocusNode = FocusNode();
  WindowController? _windowController;
  final LocalTabSettingsService _localSettings = LocalTabSettingsService();
  bool _listenerAdded = false; // Flag para garantir que o listener seja adicionado apenas uma vez
  bool _isAlwaysOnTop = false; // ✅ Flag para indicar se a janela está fixada
  bool _isMaximized = false; // ✅ Estado para controlar se a janela está maximizada
  bool _showNavigationBars = false; // ✅ Estado para controlar visibilidade das barras de navegação
  GlobalKey _multiPageWebViewKey = GlobalKey(); // ✅ Key para acessar MultiPageWebView quando necessário
  bool _isReadyToLoad = false; // ✅ Flag para controlar quando começar a carregar conteúdo
  bool _isHiding = false; // ✅ Flag para evitar múltiplas chamadas simultâneas de hide
  Map<String, bool>? _enableQuickMessagesByUrl; // ✅ Configuração de atalhos rápidos por URL
  bool _isLoadingQuickMessages = true; // ✅ Flag para indicar se ainda está carregando
  String? _quickMessageHintText; // ✅ Texto do hint de atalho rápido
  Color? _quickMessageHintColor; // ✅ Cor do hint de atalho rápido
  Timer? _quickMessageHintTimer; // ✅ Timer para ocultar o hint após alguns segundos
  String _currentPageTitle = ''; // ✅ Título atual da página para a barra personalizada
  String _openLinksMode = 'same_page'; // ✅ Configuração de como abrir links: 'same_page', 'external_browser', 'webview_window'

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _currentUrl);
    // ✅ Inicializa o título com o nome da aba salva
    _currentPageTitle = widget.savedTab.name;
    // ✅ NÃO configura título, ícones ou qualquer coisa pesada aqui
    // ✅ NÃO carrega WebView ainda - será feito após janela estar posicionada
    
    // ✅ Carrega configuração de atalhos rápidos por URL assincronamente
    if (widget.savedTab.id != null) {
      _loadQuickMessagesByUrl();
    }
    
    // ✅ Carrega configuração de abrir links no navegador externo
    _loadOpenLinksSettings();
    
    // ✅ Configura listeners para aplicar posição e sinalizar quando pronto
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          
          // ✅ CRÍTICO: Adiciona o listener para esta janela específica
          try {
            windowManager.addListener(this);
            _listenerAdded = true;
            debugPrint('✅ Listener de janela adicionado para tabId: ${widget.savedTab.id}');
          } catch (e) {
            _listenerAdded = true;
            debugPrint('✅ Listener já existe para tabId: ${widget.savedTab.id}');
          }
          
          // ✅ Aguarda um pouco para garantir que a janela foi posicionada pelo main.dart
          await Future.delayed(const Duration(milliseconds: 100));
          
          // ✅ Agora sinaliza que está pronto para carregar conteúdo
          if (mounted) {
            setState(() {
              _isReadyToLoad = true;
            });
            
            // ✅ Agora sim carrega tudo que é necessário
            _updateWindowTitle();
            _loadAlwaysOnTop();
            _initializeTab();
            _checkAndUpdateWindowState();
          }
        } catch (e) {
          debugPrint('❌ Erro ao configurar listeners de janela: $e');
          // ✅ Em caso de erro, ainda permite carregar para não travar a janela
          if (mounted) {
            setState(() {
              _isReadyToLoad = true;
            });
            _updateWindowTitle();
            _loadAlwaysOnTop();
            _initializeTab();
          }
        }
      });
    } else {
      // ✅ Para outras plataformas, carrega imediatamente
      _isReadyToLoad = true;
      _updateWindowTitle();
      _loadAlwaysOnTop();
      Future.microtask(() {
        _initializeTab();
      });
    }
    
  }
  

  /// ✅ Carrega a configuração de atalhos rápidos por URL
  Future<void> _loadQuickMessagesByUrl() async {
    if (widget.savedTab.id != null) {
      try {
        final config = await _localSettings.getQuickMessagesByUrl(widget.savedTab.id!);
        if (mounted) {
          setState(() {
            _enableQuickMessagesByUrl = config;
            // ✅ Se não há configuração salva, inicializa como true por padrão para a primeira URL
            if (_enableQuickMessagesByUrl == null || _enableQuickMessagesByUrl!.isEmpty) {
              _enableQuickMessagesByUrl = {'_index_0': true};
            }
            _isLoadingQuickMessages = false;
            debugPrint('[QuickMessages] ✅ Configuração carregada para janela secundária: $_enableQuickMessagesByUrl');
          });
        }
      } catch (e) {
        debugPrint('❌ Erro ao carregar configuração de atalhos rápidos por URL: $e');
        // ✅ Em caso de erro, inicializa como true por padrão
        if (mounted) {
          setState(() {
            _enableQuickMessagesByUrl = {'_index_0': true};
            _isLoadingQuickMessages = false;
          });
        }
      }
    } else {
      // ✅ Se não há tabId, inicializa como true por padrão
      if (mounted) {
        setState(() {
          _enableQuickMessagesByUrl = {'_index_0': true};
          _isLoadingQuickMessages = false;
        });
      }
    }
  }

  /// ✅ Carrega a configuração de como abrir links
  Future<void> _loadOpenLinksSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOpenLinksMode = prefs.getString('open_links_mode');
      if (mounted && savedOpenLinksMode != null && ['same_page', 'external_browser', 'webview_window'].contains(savedOpenLinksMode)) {
        setState(() {
          _openLinksMode = savedOpenLinksMode;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configuração de abrir links: $e');
    }
  }

  Future<void> _updateWindowTitle() async {
    if (Platform.isWindows) {
      try {
        // ✅ Verifica se é um pop-up temporário (não cadastrado no sistema)
        final isTemporaryPopup = widget.savedTab.name == 'Nova Aba' && 
                                 !widget.savedTab.url.toLowerCase().endsWith('.pdf') &&
                                 !widget.savedTab.url.toLowerCase().contains('.pdf?') &&
                                 !widget.savedTab.url.startsWith('data:application/pdf') &&
                                 !widget.savedTab.url.startsWith('data:application/x-pdf');
        
        // ✅ Para pop-ups temporários, não define título inicial (será atualizado quando página carregar)
        // Para abas cadastradas, usa o nome cadastrado
        if (!isTemporaryPopup) {
          await windowManager.setTitle(widget.savedTab.name);
          debugPrint('Título da janela (cadastrada): ${widget.savedTab.name}');
        } else {
          // Para pop-ups temporários, não define título (deixa vazio)
          // O título será atualizado quando a página carregar via _onTitleChanged
          // Não chama setTitle('') para evitar conflitos
          debugPrint('Pop-up temporário - título será atualizado quando página carregar');
        }
      } catch (e) {
        debugPrint('Erro ao atualizar título: $e');
      }
    }
  }
  
  /// ✅ Carrega a configuração de alwaysOnTop
  Future<void> _loadAlwaysOnTop() async {
    if (widget.savedTab.id != null) {
      try {
        final alwaysOnTop = await _localSettings.getAlwaysOnTop(widget.savedTab.id!);
        if (mounted) {
          setState(() {
            _isAlwaysOnTop = alwaysOnTop;
          });
        }
      } catch (e) {
        debugPrint('Erro ao carregar alwaysOnTop: $e');
      }
    }
  }

  @override
  void didUpdateWidget(BrowserWindowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedTab.id != oldWidget.savedTab.id) {
      _urlController.text = _currentUrl;
    }
  }

  @override
  void dispose() {
    // ✅ CRÍTICO: NÃO remove o listener do windowManager aqui
    // ✅ Cada janela mantém seu próprio listener independente
    // ✅ Remover o listener aqui pode afetar outras janelas abertas
    // ✅ O listener será removido automaticamente quando a janela for realmente destruída
    
    // ✅ NÃO faz dispose de _urlController, _urlFocusNode, _tab - serão reutilizados
    // ✅ NÃO remove do registro - a janela permanece registrada para reutilização
    
    // ✅ Cancela timer do hint de atalho
    _quickMessageHintTimer?.cancel();
    
    // Apenas chama super.dispose() para limpar recursos básicos do State
    super.dispose();
  }

  /// ✅ Mostra o hint de mensagem rápida (mesmo sistema da janela principal)
  void _showQuickMessageHint(String type, String? shortcut) {
    setState(() {
      if (type == 'activated') {
        // Quando ativa, mostra o hint mas NÃO inicia o timer
        // O hint permanecerá visível enquanto o atalho estiver ativo
        _quickMessageHintText = 'Atalho ativado';
        _quickMessageHintColor = Colors.yellow;
        // Cancela qualquer timer anterior, pois o hint deve permanecer visível
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = null;
      } else if (type == 'typing' && shortcut != null) {
        // Quando está digitando, atualiza o hint com as teclas digitadas
        // O shortcut vem no formato "teclas|keyCount|maxKeys"
        final parts = shortcut.split('|');
        if (parts.length == 3) {
          final typedKeys = parts[0];
          final keyCount = int.tryParse(parts[1]) ?? 0;
          final maxKeys = int.tryParse(parts[2]) ?? 5;
          if (typedKeys.isEmpty) {
            _quickMessageHintText = 'Atalho ativado';
          } else {
            _quickMessageHintText = 'Atalho ativado: /$typedKeys ($keyCount/$maxKeys)';
          }
          _quickMessageHintColor = Colors.yellow;
          // Cancela qualquer timer anterior, pois o hint deve permanecer visível enquanto digita
          _quickMessageHintTimer?.cancel();
          _quickMessageHintTimer = null;
        }
      } else if (type == 'found' && shortcut != null) {
        // Quando encontra o atalho, atualiza o hint e inicia o timer de 10 segundos
        _quickMessageHintText = 'Atalho localizado: $shortcut';
        _quickMessageHintColor = Colors.white;
        // Cancela timer anterior e inicia novo timer de 10 segundos
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _quickMessageHintText = null;
              _quickMessageHintColor = null;
            });
          }
        });
      } else if (type == 'notFound') {
        // Quando não encontra o atalho, atualiza o hint e inicia o timer de 10 segundos
        _quickMessageHintText = 'Atalho não localizado';
        _quickMessageHintColor = Colors.red;
        // Cancela timer anterior e inicia novo timer de 10 segundos
        _quickMessageHintTimer?.cancel();
        _quickMessageHintTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _quickMessageHintText = null;
              _quickMessageHintColor = null;
            });
          }
        });
      }
    });
  }

  /// ✅ Carrega e aplica tamanho/posição salvos
  /// ✅ REMOVIDO: Não aplica mais aqui porque o main.dart já aplica a posição mais recente
  Future<void> _loadAndApplySavedBounds() async {
    if (widget.savedTab.id == null) return;
    
    try {
      // ✅ Apenas verifica se a posição foi aplicada corretamente
      // ✅ O main.dart já aplicou a posição mais recente antes de mostrar a janela
      debugPrint('✅ Posição carregada pelo main.dart');
    } catch (e) {
      debugPrint('Erro ao verificar tamanho/posição: $e');
    }
  }


  /// ✅ Verifica se esta é uma janela de PDF
  bool _isPdfWindow() {
    return widget.savedTab.id != null && widget.savedTab.id!.startsWith('pdf_');
  }

  // ✅ Listeners do WindowListener para detectar mudanças
  // ✅ REMOVIDO: Salvamentos automáticos - agora só atualiza estado visual
  @override
  void onWindowResize() {
    // ✅ Apenas atualiza estado visual, não salva automaticamente
  }

  @override
  void onWindowMove() {
    // ✅ Apenas atualiza estado visual, não salva automaticamente
  }
  
  @override
  void onWindowMaximize() {
    // ✅ Apenas atualiza estado visual
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      if (mounted) {
        setState(() {
          _isMaximized = true;
        });
      }
    }
  }

  @override
  void onWindowUnmaximize() {
    // ✅ Apenas atualiza estado visual
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      if (mounted) {
        setState(() {
          _isMaximized = false;
        });
      }
    }
  }
  
  /// ✅ Salva todas as configurações da janela (posição, tamanho, maximizado, proporções)
  Future<void> _saveAllSettings() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    try {
      await windowManager.ensureInitialized();
      
      final isMaximized = await windowManager.isMaximized();
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      
      // ✅ Carrega bounds salvos anteriormente para preservar tamanho/posição quando maximizada
      final savedBounds = await _localSettings.getWindowBounds(boundsKey);
      
      Map<String, dynamic> bounds;
      
      if (isMaximized) {
        // ✅ Se está maximizada, salva apenas isMaximized = true
        // ✅ Preserva os valores anteriores de tamanho/posição (antes de maximizar) se existirem
        // ✅ Se não houver valores anteriores, não salva tamanho/posição (apenas isMaximized)
        if (savedBounds != null && 
            savedBounds['x'] != null && 
            savedBounds['y'] != null && 
            savedBounds['width'] != null && 
            savedBounds['height'] != null) {
          // ✅ Mantém valores anteriores (antes de maximizar)
          bounds = {
            'x': savedBounds['x'] as double,
            'y': savedBounds['y'] as double,
            'width': savedBounds['width'] as double,
            'height': savedBounds['height'] as double,
            'isMaximized': true,
          };
          debugPrint('✅ Janela maximizada salva: mantidos tamanho/posição anteriores (x=${savedBounds['x']}, y=${savedBounds['y']}, w=${savedBounds['width']}, h=${savedBounds['height']}), isMaximized=true');
        } else {
          // ✅ Se não há valores anteriores salvos, salva apenas isMaximized
          bounds = {
            'isMaximized': true,
          };
          debugPrint('✅ Janela maximizada salva: apenas isMaximized=true (sem tamanho/posição anteriores)');
        }
      } else {
        // ✅ Se não está maximizada, salva tamanho/posição atuais
        final position = await windowManager.getPosition();
        final size = await windowManager.getSize();
        bounds = {
          'x': position.dx,
          'y': position.dy,
          'width': size.width,
          'height': size.height,
          'isMaximized': false,
        };
        debugPrint('✅ Configurações da janela salvas: x=${position.dx}, y=${position.dy}, width=${size.width}, height=${size.height}, maximized=false');
      }
      
      await _localSettings.saveWindowBounds(boundsKey, bounds);
      
      // ✅ Se for janela com múltiplas páginas, salva também as proporções
      if (widget.savedTab.hasMultiplePages) {
        try {
          await MultiPageWebView.saveProportionsFromKey(_multiPageWebViewKey);
        } catch (e) {
          debugPrint('⚠️ Erro ao salvar proporções: $e');
        }
      }
      
      // ✅ Mostra mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar configurações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// ✅ Verifica e atualiza o estado da janela
  Future<void> _checkAndUpdateWindowState() async {
    if (Platform.isWindows) {
      try {
        final isMaximized = await windowManager.isMaximized();
        if (mounted && isMaximized != _isMaximized) {
          setState(() {
            _isMaximized = isMaximized;
          });
        }
      } catch (e) {
        debugPrint('Erro ao verificar estado da janela: $e');
      }
    }
  }
  
  /// ✅ Maximiza ou restaura a janela
  Future<void> _toggleMaximizeWindow() async {
    if (Platform.isWindows) {
      try {
        if (_isMaximized) {
          await windowManager.restore();
        } else {
          await windowManager.maximize();
        }
        // ✅ Aguarda um pouco e verifica o estado real para garantir sincronização
        await Future.delayed(const Duration(milliseconds: 100));
        await _checkAndUpdateWindowState();
      } catch (e) {
        debugPrint('Erro ao maximizar/restaurar janela: $e');
      }
    }
  }
  
  /// ✅ Oculta a janela ao invés de fechar (permite reabrir depois)
  Future<void> _closeWindow() async {
    if (Platform.isWindows) {
      // ✅ Evita múltiplas chamadas simultâneas
      if (_isHiding) return;
      _isHiding = true;
      
      try {
        // ✅ Remove listener temporariamente para evitar callbacks desnecessários
        if (_listenerAdded) {
          try {
            windowManager.removeListener(this);
            _listenerAdded = false;
          } catch (e) {
            // Ignora erros ao remover listener
          }
        }
        
        // ✅ Adiciona um pequeno delay aleatório para evitar que todas as janelas executem simultaneamente
        // Isso reduz a carga na thread principal quando múltiplas janelas são fechadas rapidamente
        final delay = Duration(milliseconds: (widget.savedTab.id?.hashCode ?? 0).abs() % 50);
        await Future.delayed(delay);
        
        // ✅ Executa hide de forma não-bloqueante para não travar a thread principal
        windowManager.hide().then((_) {
          _isHiding = false;
        }).catchError((e) {
          _isHiding = false;
          // Ignora erros silenciosamente para não bloquear
        });
      } catch (e) {
        _isHiding = false;
        // Ignora erros silenciosamente para não bloquear
      }
    }
  }
  
  
  @override
  void onWindowBlur() {
    // ✅ Não salva ao perder foco - apenas ao mover, maximizar ou restaurar
    // ✅ Isso evita salvamentos desnecessários
  }
  
  @override
  void onWindowFocus() {
    // ✅ Quando a janela ganha foco, apenas marca que não está mais ocultando
    // ✅ NÃO chama focus()/show() aqui para evitar loop infinito de foco
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      // ✅ Se estava ocultando, marca como não ocultando
      if (_isHiding) {
        _isHiding = false;
      }
      
      // ✅ Reativa listener quando janela ganha foco (se necessário)
      if (!_listenerAdded) {
        _ensureListenerActive();
      }
    }
  }
  
  /// ✅ Garante que o listener está ativo
  /// ✅ Reativa o listener se necessário (útil quando outras janelas fecham)
  /// ✅ CRÍTICO: Sempre tenta adicionar o listener, mesmo se já foi adicionado antes
  /// ✅ Isso garante que o listener continue funcionando mesmo quando outras janelas fecham
  void _ensureListenerActive() {
    if (!mounted || widget.savedTab.id == null) return;
    
    // ✅ CRÍTICO: Garante que o windowManager está inicializado antes de adicionar listener
    // ✅ Isso evita problemas quando outras janelas fecham
    try {
      // ✅ Tenta garantir inicialização (pode falhar silenciosamente se já está inicializado)
      windowManager.ensureInitialized().catchError((e) {
        // Ignora erros de inicialização - pode já estar inicializado
      });
      
      // ✅ Sempre tenta adicionar o listener (pode já existir, mas garante que está ativo)
      windowManager.addListener(this);
      if (!_listenerAdded) {
        _listenerAdded = true;
        debugPrint('✅ Listener ativado para tabId: ${widget.savedTab.id}');
      }
    } catch (e) {
      // ✅ Se falhar, tenta novamente após um pequeno delay
      // ✅ Isso ajuda quando outras janelas estão fechando
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && widget.savedTab.id != null) {
          try {
            windowManager.addListener(this);
            _listenerAdded = true;
          } catch (e2) {
            // Se ainda falhar, apenas marca como adicionado para evitar loops
            _listenerAdded = true;
          }
        }
      });
    }
  }

  Future<void> _initializeTab() async {
    try {
      // ✅ Log quando aba é inicializada pela primeira vez
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🆕 NOVA ABA/JANELA ABERTA');
      debugPrint('   └─ Nome: ${widget.savedTab.name}');
      debugPrint('   └─ ID: ${widget.savedTab.id}');
      final firstUrl = widget.savedTab.urlList.isNotEmpty ? widget.savedTab.urlList.first : "N/A";
      if (firstUrl.startsWith('data:')) {
        debugPrint('   └─ URL: data:application/pdf (base64)');
      } else {
        debugPrint('   └─ URL: $firstUrl');
      }
      // ✅ Usa mensagens rápidas passadas como parâmetro (não acessa Supabase)
      debugPrint('   └─ Mensagens rápidas: ${widget.quickMessages.length}');
      if (widget.quickMessages.isNotEmpty) {
        debugPrint('   └─ Atalhos disponíveis: ${widget.quickMessages.map((m) => m.shortcut).join(", ")}');
      } else {
        debugPrint('   └─ ⚠️ NENHUMA MENSAGEM RÁPIDA DISPONÍVEL!');
    }
      debugPrint('═══════════════════════════════════════════════════════════');
      
      final urls = widget.savedTab.urlList;
      
      if (urls.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ OTIMIZAÇÃO 4: Cria WebView de forma assíncrona e não bloqueante
      // ✅ Carrega URL automaticamente para janelas secundárias (elas são abertas por demanda)
      // ✅ IMPORTANTE: Usa o mesmo ID da aba salva para manter o mesmo diretório de cookies/cache
      // Isso garante que ao converter entre aba e janela, os cookies sejam preservados
      final tab = await BrowserTabWindows.createAsync(
        id: widget.savedTab.id!,
        initialUrl: urls.first, // ✅ Janelas secundárias carregam imediatamente
      );

      tab.updateTitle(widget.savedTab.name);
      tab.updateUrl(urls.first);
      tab.isLoaded = true;

      if (mounted) {
        setState(() {
          _tab = tab;
          _currentUrl = urls.first;
          _isLoading = false;
        });
        
        // ✅ IMPORTANTE: Para arquivos locais (file://), o carregamento será feito
        // automaticamente no onWebViewCreated do BrowserWebViewWindows
        // Não precisa carregar aqui também para evitar duplicação
        if (urls.first.startsWith('file://')) {
          debugPrint('📄 Arquivo local detectado - será carregado automaticamente pelo WebView');
        }
      }
    } catch (e) {
      // ✅ OTIMIZAÇÃO 4: Apenas logar erros críticos
      debugPrint('Erro ao inicializar aba na janela: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUrlSubmitted(String url) async {
    if (_tab != null) {
      _tab!.updateUrl(url);
      await _tab!.loadUrl(url);
      setState(() {
        _currentUrl = url;
      });
    }
  }

  void _onBackPressed() async {
    if (_tab != null && _tab!.canGoBack && _tab!.controller != null) {
      await _tab!.controller!.goBack();
    }
  }

  void _onForwardPressed() async {
    if (_tab != null && _tab!.canGoForward && _tab!.controller != null) {
      await _tab!.controller!.goForward();
    }
  }

  void _onRefreshPressed() async {
    if (_tab != null && _tab!.controller != null) {
      await _tab!.controller!.reload();
    }
  }

  void _onUrlChanged(String url) {
    setState(() {
      _currentUrl = url;
      _urlController.text = url;
    });
  }

  void _handleUrlSubmitted(String value) {
    String url = value.trim();
    
    // Adiciona https:// se não tiver protocolo
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Verifica se parece ser um domínio ou IP
      if (url.contains('.') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(url)) {
        url = 'https://$url';
      } else {
        // Se não parecer URL, faz busca no Google
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    
    _onUrlSubmitted(url);
    _urlFocusNode.unfocus();
  }

  void _onTitleChanged(String title, String tabId) async {
    // ✅ Atualiza o título da janela quando a página carrega
    if (Platform.isWindows && title.isNotEmpty && title != 'about:blank') {
      try {
        // ✅ Verifica se é um pop-up temporário (não cadastrado no sistema)
        // Pop-ups temporários têm nome inicial "Nova Aba" e não são PDFs
        // Também verifica se o ID é um timestamp (pop-ups temporários usam timestamp como ID)
        final isTemporaryPopup = widget.savedTab.name == 'Nova Aba' && 
                                 !widget.savedTab.url.toLowerCase().endsWith('.pdf') &&
                                 !widget.savedTab.url.toLowerCase().contains('.pdf?') &&
                                 !widget.savedTab.url.startsWith('data:application/pdf') &&
                                 !widget.savedTab.url.startsWith('data:application/x-pdf');
        
        // ✅ Atualiza o título da barra personalizada sempre que o título mudar
        if (mounted) {
          setState(() {
            if (isTemporaryPopup) {
              // Para pop-ups temporários, usa o título real da página
              _currentPageTitle = title;
            } else {
              // Para abas cadastradas, mantém o nome cadastrado mas pode mostrar o título da página se disponível
              _currentPageTitle = title.isNotEmpty ? title : widget.savedTab.name;
            }
          });
        }
        
        // ✅ Se for pop-up temporário, sempre atualiza com o título real da página
        // Se for aba cadastrada, mantém o nome cadastrado (não atualiza)
        if (isTemporaryPopup) {
          debugPrint('🪟 Atualizando título do pop-up temporário: $title');
          try {
            await windowManager.setTitle(title);
            debugPrint('✅ Título atualizado para: $title');
          } catch (e) {
            debugPrint('❌ Erro ao atualizar título: $e');
          }
        } else {
          debugPrint('📌 Mantendo título cadastrado: ${widget.savedTab.name} (título da página: $title)');
        }
      } catch (e) {
        debugPrint('Erro ao atualizar título da janela: $e');
      }
    }
  }

  void _onNavigationStateChanged(bool isLoading, bool canGoBack, bool canGoForward) {
    setState(() {
      _isPageLoading = isLoading;
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Se ainda está carregando, mostra indicador
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Carregando: ${widget.savedTab.name}'),
            ],
          ),
        ),
      );
    }
    
    // Se não tem tab, mostra erro
    if (_tab == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao carregar aba'),
              Text('Aba: ${widget.savedTab.name}'),
            ],
          ),
        ),
      );
    }
    
    // ✅ OTIMIZAÇÃO 4: Renderiza WebView apenas quando visível
    // ✅ Janelas secundárias fecham direto sem diálogo (configurado no GerenciaZapApp)
    // ✅ Barra de navegação do topo foi removida - apenas as barras dentro das páginas são exibidas
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.savedTab.id != null && Platform.isWindows
            ? _DraggableAppBar(
                onWindowStateChanged: _checkAndUpdateWindowState,
                child: AppBar(
                  backgroundColor: const Color(0xFF00a4a4),
                  foregroundColor: Colors.white,
                  leading: widget.savedTab.iconUrl != null && widget.savedTab.iconUrl!.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              widget.savedTab.iconUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.language,
                                  color: Colors.white,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 24,
                        ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentPageTitle.isNotEmpty ? _currentPageTitle : widget.savedTab.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_quickMessageHintText != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _quickMessageHintColor?.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _quickMessageHintColor ?? Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _quickMessageHintText!,
                            style: TextStyle(
                              color: _quickMessageHintColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    // ✅ Botão Mostrar/Esconder Barras de Navegação
                    IconButton(
                      icon: Icon(
                        _showNavigationBars ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showNavigationBars = !_showNavigationBars;
                        });
                      },
                      tooltip: _showNavigationBars ? 'Ocultar barras de navegação' : 'Mostrar barras de navegação',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Salvar
                    IconButton(
                      icon: const Icon(Icons.save, size: 20),
                      onPressed: _saveAllSettings,
                      tooltip: 'Salvar configurações da janela',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Maximizar/Restaurar (sem botão minimizar)
                    IconButton(
                      icon: Icon(
                        _isMaximized ? Icons.filter_none : Icons.crop_square,
                        size: 18,
                      ),
                      onPressed: _toggleMaximizeWindow,
                      tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    // ✅ Botão Fechar
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _closeWindow,
                      tooltip: 'Fechar',
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              )
            : null,
        body: widget.savedTab.hasMultiplePages && _tab != null
            ? MultiPageWebView(
                key: _multiPageWebViewKey,
                urls: widget.savedTab.urlList,
                columns: widget.savedTab.columns ?? 2,
                rows: widget.savedTab.rows ?? 2,
                tabId: widget.savedTab.id ?? _tab!.id, // ✅ Usa o ID do savedTab para salvar proporções corretamente
                onUrlChanged: _onUrlChanged,
                onTitleChanged: _onTitleChanged,
                onNavigationStateChanged: _onNavigationStateChanged,
                quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                enableQuickMessages: widget.savedTab.enableQuickMessages ?? true, // ✅ DEPRECATED: Mantido para compatibilidade, padrão true se não configurado
                enableQuickMessagesByUrl: _enableQuickMessagesByUrl, // ✅ Configuração por URL
                iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                pageName: widget.savedTab.name, // ✅ Passa nome da aba
                isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                isAlwaysOnTop: _isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                externalNavBarVisibility: _showNavigationBars, // ✅ Passa controle externo de visibilidade
                onNavBarVisibilityChanged: (isVisible) {
                  // ✅ Atualiza o estado do toggle quando a barra é ocultada automaticamente
                  if (mounted && _showNavigationBars != isVisible) {
                    setState(() {
                      _showNavigationBars = isVisible;
                    });
                  }
                },
                hideFloatingButton: true, // ✅ Oculta botão flutuante em janelas secundárias
                onQuickMessageHint: _showQuickMessageHint, // ✅ Callback para hints de atalhos rápidos
                openLinksMode: _openLinksMode, // ✅ Passa configuração de abrir links
              )
            : _tab != null
                ? SizedBox.expand(
                    child: BrowserWebViewWindows(
                      tab: _tab!,
                      onUrlChanged: _onUrlChanged,
                      onTitleChanged: _onTitleChanged,
                      onNavigationStateChanged: _onNavigationStateChanged,
                      quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                      enableQuickMessages: _isLoadingQuickMessages ? true : (_enableQuickMessagesByUrl?['_index_0'] ?? widget.savedTab.enableQuickMessages ?? true), // ✅ Usa configuração por índice (permite URLs duplicadas), padrão true se não configurado ou ainda carregando
                      iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                      pageName: widget.savedTab.name, // ✅ Passa nome da aba
                      isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                      isAlwaysOnTop: _isAlwaysOnTop, // ✅ Passa informação de alwaysOnTop
                      externalNavBarVisibility: _showNavigationBars, // ✅ Passa controle externo de visibilidade
                      onNavBarVisibilityChanged: (isVisible) {
                        // ✅ Atualiza o estado do toggle quando a barra é ocultada automaticamente
                        if (mounted && _showNavigationBars != isVisible) {
                          setState(() {
                            _showNavigationBars = isVisible;
                          });
                        }
                      },
                      onQuickMessageHint: _showQuickMessageHint, // ✅ Callback para hints de atalhos rápidos
                      openLinksMode: _openLinksMode, // ✅ Passa configuração de abrir links
                    ),
                  )
                : const Center(child: Text('Carregando...')),
    );
  }
}

/// ✅ Widget que torna o AppBar arrastável usando a API nativa do sistema
class _DraggableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  final VoidCallback? onWindowStateChanged;

  const _DraggableAppBar({
    required this.child,
    this.onWindowStateChanged,
  });

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }

    // ✅ Usa DragToMoveArea nativo do window_manager
    // Isso usa a API nativa do Windows para arrastar a janela sem tremor
    return DragToMoveArea(
      child: GestureDetector(
        onDoubleTap: () async {
          // Double tap para maximizar/restaurar
          try {
            final isMaximized = await windowManager.isMaximized();
            if (isMaximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
            // ✅ Aguarda um pouco e atualiza o estado
            await Future.delayed(const Duration(milliseconds: 100));
            onWindowStateChanged?.call();
          } catch (e) {
            debugPrint('Erro ao maximizar/restaurar: $e');
          }
        },
        child: child,
      ),
    );
  }
}


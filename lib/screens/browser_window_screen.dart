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
  Timer? _saveBoundsTimer; // Timer para debounce ao salvar bounds
  Timer? _savePreMaximizeTimer; // Timer para debounce ao salvar tamanho pré-maximizado
  bool _listenerAdded = false; // Flag para garantir que o listener seja adicionado apenas uma vez
  bool _isSaving = false; // Flag para evitar salvamentos simultâneos
  Map<String, dynamic>? _lastSavedBounds; // Última posição salva para evitar duplicatas
  Map<String, dynamic>? _preMaximizeBounds; // Tamanho/posição antes de maximizar

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _currentUrl);
    // ✅ Configura título da janela
    _updateWindowTitle();
    // ✅ Listener de fechamento foi movido para GerenciaZapApp
    // Janelas secundárias fecham direto sem diálogo
    
    // ✅ OTIMIZAÇÃO 4: Carregar WebView apenas quando necessário (lazy loading)
    Future.microtask(() {
      _initializeTab();
    });
    
    // ✅ Configura listeners para salvar tamanho/posição
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          
          // ✅ CRÍTICO: Adiciona o listener para esta janela específica
          // ✅ Cada janela mantém seu próprio listener independente
          // ✅ Sempre adiciona (mesmo se já existe) para garantir que está ativo
          try {
            windowManager.addListener(this);
            _listenerAdded = true;
            debugPrint('✅ Listener de janela adicionado para tabId: ${widget.savedTab.id}');
          } catch (e) {
            // ✅ Se já existe, tudo bem - marca como adicionado
            _listenerAdded = true;
            debugPrint('✅ Listener já existe para tabId: ${widget.savedTab.id}');
          }
          
          // ✅ Carrega e aplica tamanho/posição salvos
          await _loadAndApplySavedBounds();
        } catch (e) {
          debugPrint('❌ Erro ao configurar listeners de janela: $e');
        }
      });
    }
  }
  

  Future<void> _updateWindowTitle() async {
    if (Platform.isWindows) {
      try {
        // O título é definido no MaterialApp, mas vamos garantir que está atualizado
        // O MaterialApp title já está configurado com widget.savedTab.name
        debugPrint('Título da janela: ${widget.savedTab.name}');
      } catch (e) {
        debugPrint('Erro ao atualizar título: $e');
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
    // ✅ Cancela timers de salvamento
    _saveBoundsTimer?.cancel();
    _savePreMaximizeTimer?.cancel();
    
    // ✅ REMOVIDO: Não salva mais a posição no dispose
    // ✅ Deixa o sistema operacional fechar a janela nativamente
    // ✅ O salvamento já acontece durante o uso (ao mover, maximizar, restaurar)
    
    // ✅ CRÍTICO: NÃO remove o listener do windowManager aqui
    // ✅ Cada janela mantém seu próprio listener independente
    // ✅ Remover o listener aqui pode afetar outras janelas abertas
    // ✅ O listener será removido automaticamente quando a janela for realmente destruída
    
    // ✅ NÃO faz dispose de _urlController, _urlFocusNode, _tab - serão reutilizados
    // ✅ NÃO remove do registro - a janela permanece registrada para reutilização
    
    // Apenas chama super.dispose() para limpar recursos básicos do State
    super.dispose();
  }

  /// ✅ Carrega e aplica tamanho/posição salvos
  /// ✅ REMOVIDO: Não aplica mais aqui porque o main.dart já aplica a posição mais recente
  /// ✅ Esta função agora apenas verifica se a posição está correta e carrega tamanho pré-maximizado
  Future<void> _loadAndApplySavedBounds() async {
    if (widget.savedTab.id == null) return;
    
    try {
      // ✅ Para janelas de PDF, usa uma chave fixa para compartilhar posição/tamanho
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      final bounds = await _localSettings.getWindowBounds(boundsKey);
      
      // ✅ Apenas verifica se a posição está correta (não aplica novamente)
      // ✅ O main.dart já aplicou a posição mais recente antes de mostrar a janela
      if (bounds != null && bounds['x'] != null && bounds['y'] != null) {
        final currentPosition = await windowManager.getPosition();
        final savedX = bounds['x'] as double;
        final savedY = bounds['y'] as double;
        
        final positionDiff = (currentPosition.dx - savedX).abs() + (currentPosition.dy - savedY).abs();
        if (positionDiff > 10) {
          debugPrint('⚠️ Posição atual difere da salva: atual=(${currentPosition.dx}, ${currentPosition.dy}), salva=($savedX, $savedY)');
        } else {
          debugPrint('✅ Posição já aplicada corretamente no main.dart');
        }
        
        // ✅ CRÍTICO: Se a janela está maximizada, salva o tamanho pré-maximizado
        final isMaximized = bounds['isMaximized'] as bool? ?? false;
        if (isMaximized && bounds['width'] != null && bounds['height'] != null) {
          _preMaximizeBounds = {
            'x': savedX,
            'y': savedY,
            'width': bounds['width'] as double,
            'height': bounds['height'] as double,
          };
          debugPrint('✅ Tamanho pré-maximizado carregado: width=${bounds['width']}, height=${bounds['height']}');
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar tamanho/posição: $e');
    }
  }

  /// ✅ Salva tamanho e posição da janela (com debounce)
  /// ✅ IMPORTANTE: Salva apenas a última posição, sobrescrevendo qualquer posição anterior
  /// ✅ CRÍTICO: Evita loops infinitos ao maximizar/restaurar
  /// ✅ CRÍTICO: Debounce maior durante movimento para evitar travamentos e muitos salvamentos
  Future<void> _saveWindowBounds({bool forceImmediate = false, bool skipSize = false}) async {
    if (widget.savedTab.id == null || !mounted || _isSaving) return;
    
    // Cancela timer anterior se existir (garante que apenas o último movimento seja salvo)
    _saveBoundsTimer?.cancel();
    
    // ✅ Se forçado (maximizar/restaurar), salva com um pequeno delay
    if (forceImmediate) {
      _saveBoundsTimer = Timer(const Duration(milliseconds: 150), () async {
        if (mounted && !_isSaving) {
          await _doSaveBounds(skipSize: skipSize);
        }
      });
      return;
    }
    
    // ✅ Debounce maior durante movimento/redimensionamento (800ms) para evitar muitos salvamentos
    _saveBoundsTimer = Timer(const Duration(milliseconds: 800), () async {
      if (mounted && !_isSaving) {
        await _doSaveBounds(skipSize: skipSize);
      }
    });
  }
  
  /// ✅ Executa o salvamento real da posição
  /// ✅ Garante que apenas uma posição seja salva por vez
  /// ✅ CRÍTICO: Evita salvamentos duplicados e loops infinitos
  /// ✅ CRÍTICO: Não salva tamanho quando maximizado (mantém tamanho antes de maximizar)
  Future<void> _doSaveBounds({bool silent = false, bool skipSize = false}) async {
    if (widget.savedTab.id == null || !mounted) return;
    
    // ✅ CRÍTICO: Evita salvamentos simultâneos
    if (_isSaving) {
      return; // Já está salvando, ignora
    }
    
    _isSaving = true;
    
    try {
      // ✅ CRÍTICO: Garante que o windowManager está inicializado antes de usar
      // ✅ Tenta apenas uma vez durante movimento (retry só em casos críticos)
      // ✅ Isso evita delays que podem travar durante o arrasto
      try {
        await windowManager.ensureInitialized();
      } catch (e) {
        // ✅ Se falhar, tenta mais uma vez após um delay curto (só se não for movimento)
        if (!silent) {
          try {
            await Future.delayed(const Duration(milliseconds: 50));
            await windowManager.ensureInitialized();
          } catch (e2) {
            if (!silent) {
              debugPrint('⚠️ Erro ao garantir inicialização do windowManager: $e2');
            }
            _isSaving = false;
            return; // Não conseguiu inicializar, aborta
          }
        } else {
          _isSaving = false;
          return; // Durante movimento silencioso, aborta se falhar
        }
      }
      
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final isMaximized = await windowManager.isMaximized();
      
      // ✅ CRÍTICO: Se está maximizado ou skipSize=true, usa o tamanho salvo antes de maximizar
      // ✅ Não salva o tamanho da tela maximizada
      double? widthToSave = size.width;
      double? heightToSave = size.height;
      
      if (isMaximized || skipSize) {
        // ✅ Usa o tamanho que estava antes de maximizar (se disponível)
        if (_preMaximizeBounds != null) {
          widthToSave = _preMaximizeBounds!['width'] as double?;
          heightToSave = _preMaximizeBounds!['height'] as double?;
        } else {
          // ✅ Se não tem tamanho pré-maximizado salvo, carrega do storage
          final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
          final savedBounds = await _localSettings.getWindowBounds(boundsKey);
          if (savedBounds != null && savedBounds['width'] != null && savedBounds['height'] != null) {
            widthToSave = savedBounds['width'] as double?;
            heightToSave = savedBounds['height'] as double?;
          }
        }
      }
      
      // ✅ CRÍTICO: Verifica se a posição realmente mudou antes de salvar
      final currentBounds = {
        'x': position.dx,
        'y': position.dy,
        'width': widthToSave,
        'height': heightToSave,
        'isMaximized': isMaximized,
      };
      
      // ✅ Compara com a última posição salva para evitar duplicatas
      if (_lastSavedBounds != null) {
        final currentX = currentBounds['x'] as double;
        final currentY = currentBounds['y'] as double;
        final currentWidth = currentBounds['width'] as double;
        final currentHeight = currentBounds['height'] as double;
        final savedX = _lastSavedBounds!['x'] as double;
        final savedY = _lastSavedBounds!['y'] as double;
        final savedWidth = _lastSavedBounds!['width'] as double;
        final savedHeight = _lastSavedBounds!['height'] as double;
        
        final xDiff = (currentX - savedX).abs();
        final yDiff = (currentY - savedY).abs();
        final widthDiff = (currentWidth - savedWidth).abs();
        final heightDiff = (currentHeight - savedHeight).abs();
        final maximizedChanged = currentBounds['isMaximized'] != _lastSavedBounds!['isMaximized'];
        
        // ✅ Só salva se houver mudança significativa (> 1 pixel) ou se maximizado mudou
        if (xDiff < 1 && yDiff < 1 && widthDiff < 1 && heightDiff < 1 && !maximizedChanged) {
          _isSaving = false;
          return; // Não mudou, não salva
        }
      }
      
      // ✅ Para janelas de PDF, usa uma chave fixa para compartilhar posição/tamanho
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      
      // ✅ Salva apenas a última posição (setString sobrescreve automaticamente)
      await _localSettings.saveWindowBounds(boundsKey, currentBounds);
      
      // ✅ Atualiza a última posição salva
      _lastSavedBounds = currentBounds;
      
      if (!silent) {
        debugPrint('✅ Posição salva: x=${position.dx}, y=${position.dy}, width=${size.width}, height=${size.height}, maximized=$isMaximized');
      }
    } catch (e) {
      if (!silent) {
        debugPrint('❌ Erro ao salvar tamanho/posição: $e');
      }
    } finally {
      _isSaving = false;
    }
  }

  /// ✅ Verifica se esta é uma janela de PDF
  bool _isPdfWindow() {
    return widget.savedTab.id != null && widget.savedTab.id!.startsWith('pdf_');
  }

  // ✅ Listeners do WindowListener para detectar mudanças
  // ✅ CRÍTICO: Cada janela tem seus próprios listeners independentes
  // ✅ Salva apenas ao mover, maximizar ou restaurar (não ao redimensionar manualmente)
  @override
  void onWindowResize() {
    // ✅ Salva ao redimensionar manualmente (mas com debounce maior)
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      // ✅ Salva o tamanho atual antes de maximizar (se não estiver maximizado)
      _savePreMaximizeBounds();
      // ✅ Salva com debounce maior para evitar muitos salvamentos durante redimensionamento
      _saveWindowBounds();
    }
  }

  @override
  void onWindowMove() {
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      // ✅ REMOVIDO: Não chama _ensureListenerActive() durante movimento
      // ✅ Isso evita operações desnecessárias que podem travar durante o arrasto
      // ✅ O listener já está ativo desde o initState
      
      // ✅ CRÍTICO: Salva o tamanho atual ANTES de maximizar (se não estiver maximizado)
      // ✅ Usa debounce maior para evitar muitos salvamentos durante arrasto
      _savePreMaximizeBounds();
      _saveWindowBounds();
    }
  }

  bool _isMaximizing = false; // Flag para evitar loops ao maximizar
  bool _isRestoring = false; // Flag para evitar loops ao restaurar
  
  @override
  void onWindowMaximize() {
    if (widget.savedTab.id != null && Platform.isWindows && mounted && !_isSaving && !_isMaximizing) {
      _isMaximizing = true;
      
      // ✅ CRÍTICO: onWindowMaximize() é chamado DEPOIS que a janela já foi maximizada
      // ✅ Então precisamos carregar o tamanho do storage (que foi salvo antes de maximizar)
      // ✅ Não tentamos salvar o tamanho aqui porque já está maximizado
      
      // ✅ Carrega o tamanho pré-maximizado do storage
      _loadPreMaximizeBoundsFromStorage().then((_) {
        // ✅ Salva apenas maximized=true (sem alterar outros dados)
        _saveMaximizedStateOnly().then((_) {
          _isMaximizing = false;
        });
      });
    }
  }

  @override
  void onWindowUnmaximize() {
    if (widget.savedTab.id != null && Platform.isWindows && mounted && !_isSaving && !_isRestoring) {
      _isRestoring = true;
      
      // ✅ CRÍTICO: Aguarda um pouco para garantir que a janela foi realmente restaurada
      // ✅ Depois restaura o tamanho que estava antes de maximizar
      Future.delayed(const Duration(milliseconds: 100), () async {
        await _restorePreMaximizeBounds();
        // ✅ Aguarda mais um pouco para garantir que o tamanho foi aplicado
        await Future.delayed(const Duration(milliseconds: 50));
        // ✅ Salva apenas maximized=false (sem alterar outros dados)
        await _saveUnmaximizedStateOnly();
        _isRestoring = false;
      });
    }
  }
  
  /// ✅ Carrega o tamanho pré-maximizado do storage
  /// ✅ Usado quando a janela é maximizada (onWindowMaximize é chamado depois)
  Future<void> _loadPreMaximizeBoundsFromStorage() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    try {
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      final savedBounds = await _localSettings.getWindowBounds(boundsKey);
      
      if (savedBounds != null && savedBounds['width'] != null && savedBounds['height'] != null) {
        // ✅ CRÍTICO: Só atualiza se ainda não tem ou se o tamanho salvo é menor (não maximizado)
        // ✅ Isso evita carregar o tamanho maximizado por engano
        final savedWidth = savedBounds['width'] as double;
        final savedHeight = savedBounds['height'] as double;
        final isMaximized = savedBounds['isMaximized'] as bool? ?? false;
        
        // ✅ Só carrega se não estiver maximizado no storage
        if (!isMaximized && (_preMaximizeBounds == null || 
            (_preMaximizeBounds!['width'] as double) > savedWidth ||
            (_preMaximizeBounds!['height'] as double) > savedHeight)) {
          _preMaximizeBounds = {
            'x': savedBounds['x'] as double? ?? 0.0,
            'y': savedBounds['y'] as double? ?? 0.0,
            'width': savedWidth,
            'height': savedHeight,
          };
          
          debugPrint('✅ Tamanho pré-maximizado carregado do storage: width=$savedWidth, height=$savedHeight');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar tamanho pré-maximizado: $e');
    }
  }
  
  /// ✅ Salva o tamanho/posição atual ANTES de maximizar
  /// ✅ Chamado sempre que a janela é movida ou redimensionada (quando não está maximizada)
  /// ✅ Isso garante que temos o tamanho correto antes de maximizar
  /// ✅ CRÍTICO: Usa debounce para evitar muitos salvamentos durante movimento/redimensionamento
  Future<void> _savePreMaximizeBounds() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    // ✅ Cancela timer anterior se existir
    _savePreMaximizeTimer?.cancel();
    
    // ✅ Salva com debounce para evitar muitos salvamentos
    _savePreMaximizeTimer = Timer(const Duration(milliseconds: 500), () async {
      if (widget.savedTab.id == null || !mounted) return;
      
      try {
        await windowManager.ensureInitialized();
        final isMaximized = await windowManager.isMaximized();
        
        // ✅ CRÍTICO: Só salva se NÃO estiver maximizado
        if (!isMaximized) {
          final position = await windowManager.getPosition();
          final size = await windowManager.getSize();
          
          // ✅ Atualiza _preMaximizeBounds sempre que não estiver maximizado
          _preMaximizeBounds = {
            'x': position.dx,
            'y': position.dy,
            'width': size.width,
            'height': size.height,
          };
          
          debugPrint('✅ Tamanho atual salvo (antes de maximizar): width=${size.width}, height=${size.height}');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao salvar tamanho antes de maximizar: $e');
      }
    });
  }
  
  /// ✅ Restaura o tamanho que estava antes de maximizar (apenas uma vez)
  Future<void> _restorePreMaximizeBounds() async {
    if (widget.savedTab.id == null || !mounted || _preMaximizeBounds == null) return;
    
    try {
      await windowManager.ensureInitialized();
      
      final width = _preMaximizeBounds!['width'] as double?;
      final height = _preMaximizeBounds!['height'] as double?;
      final x = _preMaximizeBounds!['x'] as double?;
      final y = _preMaximizeBounds!['y'] as double?;
      
      if (width != null && height != null) {
        // ✅ CRÍTICO: Primeiro restaura a posição (se disponível)
        if (x != null && y != null) {
          await windowManager.setPosition(Offset(x, y));
        }
        
        // ✅ CRÍTICO: Depois aplica o tamanho
        await windowManager.setSize(Size(width, height));
        
        // ✅ CRÍTICO: Verifica se o tamanho foi aplicado corretamente
        final currentSize = await windowManager.getSize();
        if ((currentSize.width - width).abs() > 1 || (currentSize.height - height).abs() > 1) {
          // ✅ Se não foi aplicado corretamente, tenta novamente
          await Future.delayed(const Duration(milliseconds: 50));
          await windowManager.setSize(Size(width, height));
        }
        
        debugPrint('✅ Tamanho restaurado: width=$width, height=$height');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao restaurar tamanho: $e');
    }
  }
  
  /// ✅ Salva APENAS o estado maximized=true (sem alterar outros dados)
  Future<void> _saveMaximizedStateOnly() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    try {
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      final currentBounds = await _localSettings.getWindowBounds(boundsKey);
      
      if (currentBounds != null) {
        // ✅ Mantém todos os dados existentes, apenas altera maximized
        await _localSettings.saveWindowBounds(boundsKey, {
          'x': currentBounds['x'],
          'y': currentBounds['y'],
          'width': currentBounds['width'],
          'height': currentBounds['height'],
          'isMaximized': true,
        });
        debugPrint('✅ Estado maximizado salvo (sem alterar outros dados)');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar estado maximizado: $e');
    }
  }
  
  /// ✅ Salva APENAS o estado maximized=false (sem alterar outros dados)
  Future<void> _saveUnmaximizedStateOnly() async {
    if (widget.savedTab.id == null || !mounted) return;
    
    try {
      final boundsKey = _isPdfWindow() ? 'pdf_window' : widget.savedTab.id!;
      final currentBounds = await _localSettings.getWindowBounds(boundsKey);
      
      if (currentBounds != null) {
        // ✅ Mantém todos os dados existentes, apenas altera maximized
        await _localSettings.saveWindowBounds(boundsKey, {
          'x': currentBounds['x'],
          'y': currentBounds['y'],
          'width': currentBounds['width'],
          'height': currentBounds['height'],
          'isMaximized': false,
        });
        debugPrint('✅ Estado desmaximizado salvo (sem alterar outros dados)');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar estado desmaximizado: $e');
    }
  }
  
  @override
  void onWindowBlur() {
    // ✅ Não salva ao perder foco - apenas ao mover, maximizar ou restaurar
    // ✅ Isso evita salvamentos desnecessários
  }
  
  @override
  void onWindowFocus() {
    // ✅ Quando a janela ganha foco, garante que o listener está ativo
    if (widget.savedTab.id != null && Platform.isWindows && mounted) {
      _ensureListenerActive();
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
      final tab = await BrowserTabWindows.createAsync(
        id: 'window_${widget.savedTab.id}_${DateTime.now().millisecondsSinceEpoch}',
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
    // ✅ O título da janela é definido no MaterialApp (main.dart)
    // Não é possível atualizar dinamicamente em janelas secundárias do desktop_multi_window
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
        body: Column(
                  children: [
                    // Conteúdo WebView (sem barra de navegação no topo)
                    Expanded(
                      child: widget.savedTab.hasMultiplePages && _tab != null
                          ? MultiPageWebView(
                              urls: widget.savedTab.urlList,
                              columns: widget.savedTab.columns ?? 2,
                              rows: widget.savedTab.rows ?? 2,
                              tabId: widget.savedTab.id ?? _tab!.id, // ✅ Usa o ID do savedTab para salvar proporções corretamente
                              onUrlChanged: _onUrlChanged,
                              onTitleChanged: _onTitleChanged,
                              onNavigationStateChanged: _onNavigationStateChanged,
                    quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                    enableQuickMessages: widget.savedTab.enableQuickMessages, // ✅ Usa configuração da aba salva
                    iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                    pageName: widget.savedTab.name, // ✅ Passa nome da aba
                    isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                            )
                          : _tab != null
                              ? BrowserWebViewWindows(
                                  tab: _tab!,
                                  onUrlChanged: _onUrlChanged,
                                  onTitleChanged: _onTitleChanged,
                                  onNavigationStateChanged: _onNavigationStateChanged,
                        quickMessages: widget.quickMessages, // ✅ Sempre usa as mensagens passadas como parâmetro
                        enableQuickMessages: widget.savedTab.enableQuickMessages, // ✅ Usa configuração da aba salva
                        iconUrl: widget.savedTab.iconUrl, // ✅ Passa ícone da aba
                        pageName: widget.savedTab.name, // ✅ Passa nome da aba
                        isPdfWindow: _isPdfWindow(), // ✅ Indica se é uma janela de PDF
                                )
                              : const Center(child: Text('Carregando...')),
                    ),
                  ],
                ),
    );
  }
}


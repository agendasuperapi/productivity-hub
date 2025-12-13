import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'utils/window_registry.dart';
import 'screens/auth_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/browser_screen_windows.dart';
import 'screens/browser_window_screen.dart';
import 'models/saved_tab.dart';
import 'models/quick_message.dart';
import 'services/global_quick_messages_service.dart';
import 'services/local_tab_settings_service.dart';
import 'utils/webview_platform_init.dart';
import 'utils/window_manager_helper.dart';

Future<void> _writeErrorToFile(String error) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/gerencia_zap_errors.log');
    final timestamp = DateTime.now().toIso8601String();
    await file.writeAsString(
      '[$timestamp] $error\n',
      mode: FileMode.append,
    );
  } catch (e) {
    // Se não conseguir escrever no arquivo, apenas ignora
    debugPrint('Erro ao escrever log: $e');
  }
}

void main(List<String> args) async {
  // Executa tudo dentro de uma zona protegida para capturar erros assíncronos
  // IMPORTANTE: ensureInitialized deve estar dentro da mesma zona que runApp
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Captura erros não tratados do Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final errorMsg = '''
=== ERRO FLUTTER NÃO TRATADO ===
Exception: ${details.exception}
Stack: ${details.stack}
Library: ${details.library}
Context: ${details.context}
=================================
''';
      debugPrint(errorMsg);
      _writeErrorToFile(errorMsg);
    };

    // Captura erros de plataforma
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorMsg = '''
=== ERRO DE PLATAFORMA ===
Error: $error
Stack: $stack
==========================
''';
      debugPrint(errorMsg);
      _writeErrorToFile(errorMsg);
      // Retorna true para indicar que o erro foi tratado e evitar crash
      return true;
    };
    
    // Inicializa o WebViewPlatform antes de rodar o app
    initializeWebViewPlatform();
    
    // Verifica se é uma janela secundária ANTES de inicializar Supabase
    Map<String, dynamic>? windowArgs;
    bool isSecondaryWindow = false;
    
    // ✅ OTIMIZAÇÃO 2: Detecta janela secundária pelos args sem delay
    if (Platform.isWindows) {
      try {
        // Tenta obter WindowController sem delay
        final windowController = await WindowController.fromCurrentEngine();
        if (windowController.arguments.isNotEmpty) {
      try {
            windowArgs = jsonDecode(windowController.arguments) as Map<String, dynamic>;
            isSecondaryWindow = true;
          } catch (e) {
            // Não é JSON válido
            windowArgs = null;
            isSecondaryWindow = false;
          }
        }
      } catch (e) {
        // É a janela principal ou erro ao obter controller
        windowArgs = null;
        isSecondaryWindow = false;
      }
    }
    
    // ✅ OTIMIZAÇÃO 1: Inicializar Supabase APENAS na janela principal
    // Janelas secundárias usam a instância já inicializada
    if (!isSecondaryWindow) {
    await Supabase.initialize(
      url: 'https://ytrscprtyqlufrsusylb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0cnNjcHJ0eXFsdWZyc3VzeWxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwNjIxMzQsImV4cCI6MjA4MDYzODEzNH0.acbTkf2oSBQSDm0f-ZgonNcqCyd9r7tp4EdsaCpHbgk',
    );
    
      // ✅ Carrega mensagens rápidas globalmente após inicializar Supabase
      try {
        final globalQuickMessages = GlobalQuickMessagesService();
        await globalQuickMessages.loadMessages();
      } catch (e) {
        debugPrint('Erro ao carregar mensagens rápidas globais: $e');
      }
    }
    
    // ✅ OTIMIZAÇÃO 3: window_manager APENAS na janela principal
    if (Platform.isWindows && !isSecondaryWindow) {
      await windowManager.ensureInitialized();
      
      final windowOptions = WindowOptions(
        size: const Size(1400, 900),
        center: true,
        backgroundColor: Colors.white,
        skipTaskbar: false,
        // ✅ Oculta os botões nativos da barra de título (incluindo o botão fechar)
        titleBarStyle: TitleBarStyle.hidden,
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        // ✅ Define o título da janela principal
        await windowManager.setTitle('Gerencia Zap');
      });
      
      // ✅ NÃO configura preventClose aqui - será feito no GerenciaZapApp.initState()
      // O listener precisa ser configurado ANTES de setPreventClose(true)
    }
    
    // ✅ Para janelas secundárias: aplica tamanho/posição ANTES de mostrar
    if (Platform.isWindows && isSecondaryWindow && windowArgs != null) {
      try {
        await windowManager.ensureInitialized();
        
          // ✅ CRÍTICO: Carrega a posição MAIS RECENTE diretamente do storage
          // ✅ Não usa savedBounds dos argumentos que pode estar desatualizado
          final tabId = windowArgs['tabId'] as String?;
          if (tabId != null) {
            try {
              // ✅ Obtém o serviço de configurações locais
              final localSettings = LocalTabSettingsService();
              final boundsKey = tabId.startsWith('pdf_') ? 'pdf_window' : tabId;
              final savedBounds = await localSettings.getWindowBounds(boundsKey);
            
            if (savedBounds != null && savedBounds['x'] != null && savedBounds['y'] != null) {
              final x = savedBounds['x'] as double;
              final y = savedBounds['y'] as double;
              final width = savedBounds['width'] as double?;
              final height = savedBounds['height'] as double?;
              final isMaximized = savedBounds['isMaximized'] as bool? ?? false;
              
              // ✅ CRÍTICO: Se está maximizada, NÃO aplica tamanho (mantém tamanho antes de maximizar)
              // ✅ Apenas aplica posição e maximiza
              if (!isMaximized) {
                // ✅ Aplica tamanho e posição apenas se NÃO estiver maximizada
                if (width != null && height != null) {
                  await windowManager.setSize(Size(width, height));
                }
                await windowManager.setPosition(Offset(x, y));
                debugPrint('✅ Tamanho/posição aplicados no main() ANTES de runApp (do storage): x=$x, y=$y, width=$width, height=$height, maximized=$isMaximized');
              } else {
                // ✅ Se está maximizada, aplica apenas posição (tamanho será restaurado ao desmaximizar)
                await windowManager.setPosition(Offset(x, y));
                debugPrint('✅ Posição aplicada no main() (maximizada): x=$x, y=$y, width=$width, height=$height (tamanho preservado)');
              }
              
              // ✅ Se estava maximizada, maximiza após um pequeno delay (depois do runApp)
              if (isMaximized) {
                Future.delayed(const Duration(milliseconds: 100), () async {
                  try {
                    await windowManager.maximize();
                  } catch (e) {
                    debugPrint('Erro ao maximizar: $e');
                  }
                });
              }
              
              // ✅ Aplica alwaysOnTop se configurado
              final alwaysOnTop = await localSettings.getAlwaysOnTop(boundsKey);
              if (alwaysOnTop) {
                try {
                  await windowManager.setAlwaysOnTop(true);
                  debugPrint('✅ AlwaysOnTop aplicado para janela: $boundsKey');
                } catch (e) {
                  debugPrint('⚠️ Erro ao aplicar alwaysOnTop: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao carregar posição do storage: $e');
            // ✅ Fallback: usa savedBounds dos argumentos se não conseguir carregar do storage
            final savedBounds = windowArgs['savedBounds'] as Map<String, dynamic>?;
            if (savedBounds != null && savedBounds['x'] != null && savedBounds['y'] != null) {
              final x = savedBounds['x'] as double;
              final y = savedBounds['y'] as double;
              final width = savedBounds['width'] as double?;
              final height = savedBounds['height'] as double?;
              
              if (width != null && height != null) {
                await windowManager.setSize(Size(width, height));
              }
              await windowManager.setPosition(Offset(x, y));
              debugPrint('✅ Tamanho/posição aplicados no main() (fallback dos argumentos): x=$x, y=$y');
            }
          }
        }
        
        // ✅ Define o título ANTES de mostrar
        final windowTitle = windowArgs['windowTitle'] as String?;
        if (windowTitle != null) {
          await windowManager.setTitle(windowTitle);
        }
        
        // ✅ Mostra a janela após configurar tudo
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        debugPrint('⚠️ Erro ao configurar janela secundária no main(): $e');
      }
    }
    
    // Passa os argumentos da janela para o app
    runApp(GerenciaZapApp(windowArgs: windowArgs, isSecondaryWindow: isSecondaryWindow));
  }, (error, stack) {
    final errorMsg = '''
=== ERRO ASSÍNCRONO NÃO TRATADO ===
Error: $error
Stack: $stack
====================================
''';
    debugPrint(errorMsg);
    _writeErrorToFile(errorMsg);
  });
}

class GerenciaZapApp extends StatefulWidget {
  final Map<String, dynamic>? windowArgs;
  final bool isSecondaryWindow;
  
  const GerenciaZapApp({super.key, this.windowArgs, this.isSecondaryWindow = false});
  
  @override
  State<GerenciaZapApp> createState() => _GerenciaZapAppState();
  
  // ✅ GlobalKey para acessar o estado da janela principal
  static final GlobalKey<_GerenciaZapAppState> mainWindowKey = GlobalKey<_GerenciaZapAppState>();
}

class _GerenciaZapAppState extends State<GerenciaZapApp> with WindowListener {
  // ✅ GlobalKey para o Navigator para garantir que o diálogo sempre funcione
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  // ✅ Armazena o WindowController específico desta janela (para janelas secundárias)
  WindowController? _thisWindowController;
  // ✅ Armazena o tabId desta janela (para janelas secundárias)
  String? _thisWindowTabId;
  // ✅ Identificador único desta instância para debug
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  
  @override
  void initState() {
    super.initState();
    
    // ✅ Para janelas secundárias, obtém e armazena o WindowController e tabId
    if (Platform.isWindows && widget.isSecondaryWindow) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // ✅ Obtém o tabId dos argumentos primeiro
          if (widget.windowArgs != null && widget.windowArgs!.containsKey('tabId')) {
            _thisWindowTabId = widget.windowArgs!['tabId'] as String?;
            debugPrint('✅ Janela secundária identificada: tabId=$_thisWindowTabId');
            debugPrint('   Instância ID: $_instanceId');
          }
          
          // ✅ Obtém o WindowController desta janela específica
          _thisWindowController = await WindowController.fromCurrentEngine();
          
          // ✅ Garante que o controller está registrado corretamente no registro
          // ✅ Isso garante que sempre temos o controller correto associado ao tabId
          if (_thisWindowController != null && _thisWindowTabId != null) {
            WindowRegistry.register(_thisWindowTabId!, _thisWindowController!);
            debugPrint('✅ WindowController registrado para tabId: $_thisWindowTabId');
          }
          
          // ✅ Janelas secundárias usam fechamento nativo (não interceptam fechamento)
          debugPrint('✅ Janela secundária configurada com fechamento nativo');
          debugPrint('   TabId: $_thisWindowTabId');
        } catch (e) {
          debugPrint('⚠️ Erro ao configurar janela secundária: $e');
        }
      });
    } else if (Platform.isWindows && !widget.isSecondaryWindow) {
      // ✅ Janela principal
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          // ✅ Adiciona o listener ANTES de setPreventClose(true)
          windowManager.addListener(this);
          // ✅ Intercepta o fechamento para mostrar o diálogo (mesma lógica do botão "Sair")
          await windowManager.setPreventClose(true);
          debugPrint('✅ Listener de fechamento configurado - botão fechar executa botão "Sair"');
        } catch (e) {
          debugPrint('⚠️ Erro ao configurar listener de fechamento: $e');
        }
      });
    }
  }
  
  @override
  void dispose() {
    // ✅ Remove listener apenas da janela principal
    // ✅ Janelas secundárias não têm listener (usam fechamento nativo)
    if (Platform.isWindows && !widget.isSecondaryWindow) {
      try {
        windowManager.removeListener(this);
      } catch (e) {
        debugPrint('⚠️ Erro ao remover listener: $e');
      }
    }
    super.dispose();
  }
  
  @override
  void onWindowFocus() {
    // ✅ Quando a janela principal recebe foco, ativa janelas alwaysOnTop
    if (Platform.isWindows && !widget.isSecondaryWindow) {
      _activateAlwaysOnTopWindows();
    }
  }
  
  /// ✅ Ativa todas as janelas configuradas como alwaysOnTop
  Future<void> _activateAlwaysOnTopWindows() async {
    try {
      final localSettings = LocalTabSettingsService();
      final alwaysOnTopSettings = await localSettings.getAllAlwaysOnTopSettings();
      
      for (final entry in alwaysOnTopSettings.entries) {
        if (entry.value == true) {
          final tabId = entry.key;
          try {
            // ✅ Tenta ativar a janela se estiver aberta
            final windowManager = WindowManagerHelper();
            await windowManager.activateWindowIfOpen(tabId);
          } catch (e) {
            // Ignora erros ao ativar janela (pode não estar aberta)
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao ativar janelas alwaysOnTop: $e');
    }
  }
  
  @override
  Future<void> onWindowClose() async {
    debugPrint('🔴 Botão fechar nativo clicado');
    
    // ✅ Janelas secundárias: permitem fechamento nativo SEM ações customizadas
    if (widget.isSecondaryWindow) {
      // ✅ REMOVIDO: Não salva mais posição nem remove registro
      // ✅ Deixa o sistema operacional fechar a janela nativamente
      // ✅ O salvamento já acontece durante o uso (ao mover, maximizar, restaurar)
      return;
    } else {
      // ✅ Janela principal: usa a mesma lógica do botão "Sair" personalizado
      debugPrint('Executando lógica do botão "Sair"');
      final shouldClose = await _showExitDialog();
      
      if (shouldClose) {
        // ✅ Fecha o aplicativo (mesma lógica do botão "Sair")
        if (Platform.isWindows) {
          try {
            await windowManager.setPreventClose(false);
            await windowManager.close();
          } catch (e) {
            // Se close falhar, usa exit como fallback
            exit(0);
          }
        } else {
          exit(0);
        }
      }
      // Se cancelar, simplesmente não faz nada (preventClose continua true)
    }
  }
  
  /// Mostra o diálogo de confirmação (mesma lógica do botão "Sair")
  Future<bool> _showExitDialog() async {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) {
      // Context nulo = não há árvore montada (situação de erro)
      return true; // fallback: fecha sem perguntar para não travar
    }
    
    try {
      final result = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Fechar aplicativo'),
          content: const Text('Deseja realmente sair do Gerencia Zap?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Erro ao mostrar diálogo: $e');
      return false; // Em caso de erro, cancela o fechamento
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Se abriu pela DesktopMultiWindow (janela secundária)
    if (widget.windowArgs != null && widget.windowArgs!.containsKey('tabId')) {
      // ✅ Passa os dados do SavedTab diretamente, sem depender do Supabase
      final savedTabData = widget.windowArgs!['savedTab'] as Map<String, dynamic>?;
      final windowTitle = widget.windowArgs!['windowTitle'] as String?;
      final quickMessagesData = widget.windowArgs!['quickMessages'] as List<dynamic>?;
      
      if (savedTabData != null) {
        // Cria SavedTab a partir dos dados passados
        final savedTab = SavedTab.fromMap(savedTabData);
        // ✅ Usa o título passado nos argumentos ou o nome da aba como fallback
        final title = windowTitle ?? savedTab.name;
        
        // ✅ Converte mensagens rápidas de Map para QuickMessage (sempre passa como parâmetro, não usa Supabase)
        List<QuickMessage> quickMessages = [];
        if (quickMessagesData != null && quickMessagesData.isNotEmpty) {
          quickMessages = quickMessagesData
              .map((m) => QuickMessage.fromMap(m as Map<String, dynamic>))
              .toList();
        }
        
        // ✅ Log quando janela secundária recebe mensagens
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('🪟 JANELA SECUNDÁRIA INICIALIZADA');
        debugPrint('   └─ Nome: $title');
        debugPrint('   └─ Tab ID: ${savedTab.id}');
        final firstUrl = savedTab.urlList.isNotEmpty ? savedTab.urlList.first : "N/A";
        if (firstUrl.startsWith('data:')) {
          debugPrint('   └─ URL: data:application/pdf (base64)');
        } else {
          debugPrint('   └─ URL: $firstUrl');
        }
        debugPrint('   └─ Mensagens rápidas: ${quickMessages.length}');
        if (quickMessages.isNotEmpty) {
          debugPrint('   └─ Atalhos: ${quickMessages.map((m) => m.shortcut).join(", ")}');
        } else {
          debugPrint('   └─ ⚠️ NENHUMA MENSAGEM RÁPIDA DISPONÍVEL!');
        }
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // ✅ A configuração da janela (tamanho/posição) é feita no initState do _GerenciaZapAppState
        // Isso garante que a janela já abra na posição correta
        
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: title, // ✅ Define o título da janela
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          // ✅ Não precisa verificar sessão - janela secundária não depende do Supabase
          home: BrowserWindowScreen(
            savedTab: savedTab,
            quickMessages: quickMessages, // ✅ Sempre passa como parâmetro (lista vazia se não houver)
          ),
        );
      }
      
      // Fallback: se não tem dados, mostra erro
      return MaterialApp(
        title: 'Gerencia Zap - Erro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Erro: Dados da aba não foram passados'),
              ],
            ),
          ),
        ),
      );
    }
    
    // Janela principal - usa Supabase normalmente
    final supabase = Supabase.instance.client;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Gerencia Zap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          
          if (session == null) {
            return const AuthScreen();
          }
          
          return Platform.isWindows 
              ? const BrowserScreenWindows()
              : const BrowserScreen();
        },
      ),
    );
  }
}


// ✅ _WindowLoader removido - não é mais necessário
// Os dados do SavedTab são passados diretamente como parâmetros

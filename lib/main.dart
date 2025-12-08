import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'screens/auth_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/browser_screen_windows.dart';
import 'screens/browser_window_screen.dart';
import 'models/saved_tab.dart';
import 'services/saved_tabs_service.dart';
import 'utils/webview_platform_init.dart';

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
    
    // Inicializar Supabase primeiro (necessário para todas as janelas)
    await Supabase.initialize(
      url: 'https://ytrscprtyqlufrsusylb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0cnNjcHJ0eXFsdWZyc3VzeWxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwNjIxMzQsImV4cCI6MjA4MDYzODEzNH0.acbTkf2oSBQSDm0f-ZgonNcqCyd9r7tp4EdsaCpHbgk',
    );
    
    // Verifica se é uma janela secundária (passada via desktop_multi_window)
    Map<String, dynamic>? windowArgs;
    bool isSecondaryWindow = false;
    
    if (Platform.isWindows) {
      try {
        // Tenta obter o WindowController da janela atual
        // IMPORTANTE: Aguarda um pouco para garantir que a janela está totalmente inicializada
        await Future.delayed(const Duration(milliseconds: 100));
        
        final windowController = await WindowController.fromCurrentEngine();
        debugPrint('WindowController obtido: windowId=${windowController.windowId}, arguments=${windowController.arguments}');
        
        if (windowController.arguments.isNotEmpty) {
          try {
            windowArgs = jsonDecode(windowController.arguments) as Map<String, dynamic>;
            isSecondaryWindow = true;
            debugPrint('✅ Janela secundária detectada: $windowArgs');
          } catch (e) {
            debugPrint('❌ Erro ao fazer parse dos argumentos: $e');
            debugPrint('   Arguments raw: ${windowController.arguments}');
            // Não é JSON, ignora
            windowArgs = null;
            isSecondaryWindow = false;
          }
        } else {
          debugPrint('ℹ️ Arguments vazio - janela principal');
          isSecondaryWindow = false;
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Erro ao obter WindowController (provavelmente janela principal): $e');
        debugPrint('   Stack trace: $stackTrace');
        // É a janela principal ou erro ao obter controller
        windowArgs = null;
        isSecondaryWindow = false;
      }
    }
    
    // Inicializar window_manager APENAS na janela principal (não funciona em janelas secundárias)
    if (Platform.isWindows && !isSecondaryWindow) {
      await windowManager.ensureInitialized();
      
      debugPrint('Configurando janela principal');
      // Configura apenas a janela principal
      final windowOptions = WindowOptions(
        size: const Size(1400, 900),
        center: true,
        backgroundColor: Colors.white,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } else if (Platform.isWindows && isSecondaryWindow) {
      debugPrint('ℹ️ Janela secundária detectada - pulando window_manager (não suportado)');
    }
    
    // Passa os argumentos da janela para o app
    runApp(GerenciaZapApp(windowArgs: windowArgs));
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

class GerenciaZapApp extends StatelessWidget {
  final Map<String, dynamic>? windowArgs;
  
  const GerenciaZapApp({super.key, this.windowArgs});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    
    // Se abriu pela DesktopMultiWindow (janela secundária)
    if (windowArgs != null && windowArgs!.containsKey('tabId')) {
      final tabId = windowArgs!['tabId'] as String;
      debugPrint('✅ GerenciaZapApp: Criando MaterialApp para janela secundária com tabId: $tabId');
      return MaterialApp(
        title: 'Gerencia Zap - Janela',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: StreamBuilder<AuthState>(
          stream: supabase.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final session = supabase.auth.currentSession;
            
            debugPrint('GerenciaZapApp: StreamBuilder - session=${session != null}, snapshot.hasData=${snapshot.hasData}, snapshot.hasError=${snapshot.hasError}');
            
            if (session == null) {
              debugPrint('❌ GerenciaZapApp: Sem sessão, mostrando AuthScreen');
              return const AuthScreen();
            }
            
            debugPrint('✅ GerenciaZapApp: Sessão encontrada, criando _WindowLoader');
            return _WindowLoader(tabId: tabId);
          },
        ),
      );
    }
    
    debugPrint('ℹ️ GerenciaZapApp: Criando MaterialApp para janela principal (windowArgs=$windowArgs)');
    
    // Janela principal
    return MaterialApp(
      title: 'Gerencia Zap - Navegador Multi-Aba',
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

class _WindowLoader extends StatefulWidget {
  final String tabId;
  
  const _WindowLoader({required this.tabId});

  @override
  State<_WindowLoader> createState() => _WindowLoaderState();
}

class _WindowLoaderState extends State<_WindowLoader> {
  SavedTab? _savedTab;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTab();
  }

  Future<void> _loadTab() async {
    try {
      debugPrint('_WindowLoader: Carregando aba com ID: ${widget.tabId}');
      final savedTabsService = SavedTabsService();
      final savedTabs = await savedTabsService.getSavedTabs();
      debugPrint('_WindowLoader: Total de abas encontradas: ${savedTabs.length}');
      
      final tab = savedTabs.firstWhere(
        (t) => t.id == widget.tabId,
        orElse: () => throw Exception('Aba não encontrada com ID: ${widget.tabId}'),
      );
      
      debugPrint('_WindowLoader: Aba encontrada: ${tab.name}, URLs: ${tab.urlList}');
      
      // Configura o título da janela
      if (Platform.isWindows) {
        try {
          await windowManager.setTitle(tab.name);
          debugPrint('_WindowLoader: Título da janela definido: ${tab.name}');
        } catch (e) {
          debugPrint('_WindowLoader: Erro ao definir título da janela: $e');
        }
      }
      
      setState(() {
        _savedTab = tab;
        _isLoading = false;
      });
      debugPrint('_WindowLoader: Estado atualizado, _savedTab=${_savedTab?.name}');
    } catch (e, stackTrace) {
      debugPrint('_WindowLoader: Erro ao carregar aba: $e');
      debugPrint('_WindowLoader: Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('_WindowLoader: build() chamado, _isLoading=$_isLoading, _savedTab=${_savedTab?.name}, tabId=${widget.tabId}');
    
    if (_isLoading) {
      debugPrint('_WindowLoader: Mostrando tela de carregamento');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Carregando aba: ${widget.tabId}'),
            ],
          ),
        ),
      );
    }
    
    if (_savedTab == null) {
      debugPrint('_WindowLoader: ❌ _savedTab é null, mostrando erro');
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Aba não encontrada com ID: ${widget.tabId}'),
            ],
          ),
        ),
      );
    }
    
    debugPrint('_WindowLoader: ✅ Criando BrowserWindowScreen com savedTab: ${_savedTab!.name}');
    return BrowserWindowScreen(savedTab: _savedTab!);
  }
}

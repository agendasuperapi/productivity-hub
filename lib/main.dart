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
import 'models/quick_message.dart';
import 'services/global_quick_messages_service.dart';
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
        titleBarStyle: TitleBarStyle.normal,
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        // ✅ Define o título da janela principal
        await windowManager.setTitle('Gerencia Zap');
      });
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
    // Se abriu pela DesktopMultiWindow (janela secundária)
    if (windowArgs != null && windowArgs!.containsKey('tabId')) {
      // ✅ Passa os dados do SavedTab diretamente, sem depender do Supabase
      final savedTabData = windowArgs!['savedTab'] as Map<String, dynamic>?;
      final windowTitle = windowArgs!['windowTitle'] as String?;
      final quickMessagesData = windowArgs!['quickMessages'] as List<dynamic>?;
      
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
        debugPrint('   └─ URL: ${savedTab.urlList.isNotEmpty ? savedTab.urlList.first : "N/A"}');
        debugPrint('   └─ Mensagens rápidas: ${quickMessages.length}');
        if (quickMessages.isNotEmpty) {
          debugPrint('   └─ Atalhos: ${quickMessages.map((m) => m.shortcut).join(", ")}');
        } else {
          debugPrint('   └─ ⚠️ NENHUMA MENSAGEM RÁPIDA DISPONÍVEL!');
        }
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // ✅ Define o título da janela usando window_manager quando a janela abrir
        if (Platform.isWindows) {
          Future.microtask(() async {
            try {
              await windowManager.ensureInitialized();
              await windowManager.setTitle(title);
            } catch (e) {
              debugPrint('Erro ao definir título da janela: $e');
            }
          });
        }
        
        return MaterialApp(
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/browser_screen_windows.dart';
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

void main() async {
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
    
    // Inicializar Supabase
    await Supabase.initialize(
      url: 'https://ytrscprtyqlufrsusylb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0cnNjcHJ0eXFsdWZyc3VzeWxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwNjIxMzQsImV4cCI6MjA4MDYzODEzNH0.acbTkf2oSBQSDm0f-ZgonNcqCyd9r7tp4EdsaCpHbgk',
    );
    
    runApp(const GerenciaZapApp());
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
  const GerenciaZapApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    
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

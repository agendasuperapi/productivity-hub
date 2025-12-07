import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/browser_screen_windows.dart';
import 'utils/webview_platform_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o WebViewPlatform antes de rodar o app
  initializeWebViewPlatform();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://ytrscprtyqlufrsusylb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0cnNjcHJ0eXFsdWZyc3VzeWxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwNjIxMzQsImV4cCI6MjA4MDYzODEzNH0.acbTkf2oSBQSDm0f-ZgonNcqCyd9r7tp4EdsaCpHbgk',
  );
  
  runApp(const GerenciaZapApp());
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

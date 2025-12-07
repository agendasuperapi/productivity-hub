import 'package:flutter/material.dart';

/// Tela informativa quando Windows não é suportado
class WindowsNotSupportedScreen extends StatelessWidget {
  const WindowsNotSupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Suporte para Windows',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'O pacote webview_flutter ainda não tem suporte oficial para Windows.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Text(
                'Por favor, teste o aplicativo em uma das seguintes plataformas:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildPlatformOption('Android', Icons.android),
              const SizedBox(height: 12),
              _buildPlatformOption('iOS', Icons.phone_iphone),
              const SizedBox(height: 12),
              _buildPlatformOption('macOS', Icons.desktop_mac),
              const SizedBox(height: 32),
              const Text(
                'O suporte para Windows será adicionado em uma versão futura.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformOption(String platform, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          platform,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}


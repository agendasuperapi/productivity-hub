import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Tela de boas-vindas exibida quando a aba Home está ativa
class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onGetStarted;

  const WelcomeScreen({
    super.key,
    this.onGetStarted,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = packageInfo.version;
      });
    } catch (e) {
      // Se houver erro, mantém vazio
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00a4a4), // Teal sólido
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF00a4a4), // Teal sólido
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo GZ em balão de fala branco
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'GZ',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00a4a4),
                      ),
                    ),
                  ),
                ),
                // ✅ Versão abaixo do ícone
                if (_version.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'v$_version',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                
                // Título
                const Text(
                  'Bem-vindo ao GerenciaZap',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Subtítulo
                const Text(
                  'Seu navegador personalizado com suporte a múltiplas abas e janelas',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                
                // Lista de recursos (alinhados à esquerda)
                _buildFeature(
                  icon: Icons.tab,
                  title: 'Múltiplas Abas',
                  description: 'Gerencje várlas páginas simultaneamente',
                ),
                const SizedBox(height: 32),
                _buildFeature(
                  icon: Icons.open_in_new,
                  title: 'Janelas Separadas',
                  description: 'Abra páginas em janelas independentes',
                ),
                const SizedBox(height: 32),
                _buildFeature(
                  icon: Icons.bolt,
                  title: 'Mensagens Rápidas',
                  description: 'Use atalhos pará inserir mensagens rapidamente',
                ),
                const SizedBox(height: 32),
                _buildFeature(
                  icon: Icons.devices,
                  title: 'Multi Plataforma',
                  description: 'Funciona em Windows, Mac, iPhone, iPad, Celular e tablet Android',
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 24,
            color: const Color(0xFF00a4a4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

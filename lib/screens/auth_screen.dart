import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

/// Tela de autenticação (Login e Cadastro)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WindowListener {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMaximized = false; // ✅ Estado para controlar se a janela está maximizada
  Timer? _windowStateCheckTimer; // ✅ Timer para verificar estado da janela

  @override
  void initState() {
    super.initState();
    // ✅ Carrega o último email usado
    _loadLastEmail();
    // ✅ Configura listeners para controle de janela no Windows
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          windowManager.addListener(this);
          await _checkAndUpdateWindowState();
          // ✅ Verifica o estado periodicamente
          _windowStateCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
            _checkAndUpdateWindowState();
          });
        } catch (e) {
          debugPrint('Erro ao configurar listeners de janela: $e');
        }
      });
    }
  }

  /// ✅ Carrega o último email usado do armazenamento local
  Future<void> _loadLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('last_login_email');
      if (lastEmail != null && lastEmail.isNotEmpty) {
        if (mounted) {
          setState(() {
            _emailController.text = lastEmail;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar último email: $e');
    }
  }

  /// ✅ Salva o email usado no armazenamento local
  Future<void> _saveLastEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_email', email.trim());
    } catch (e) {
      debugPrint('Erro ao salvar último email: $e');
    }
  }

  @override
  void dispose() {
    _windowStateCheckTimer?.cancel();
    if (Platform.isWindows) {
      try {
        windowManager.removeListener(this);
      } catch (e) {
        debugPrint('Erro ao remover listener: $e');
      }
    }
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// ✅ Verifica o estado atual da janela e atualiza se necessário
  Future<void> _checkAndUpdateWindowState() async {
    if (!Platform.isWindows || !mounted) return;
    
    try {
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized != _isMaximized) {
        if (mounted) {
          setState(() {
            _isMaximized = isMaximized;
          });
        }
      }
    } catch (e) {
      // Ignora erros silenciosamente
    }
  }

  /// ✅ Minimiza a janela
  Future<void> _minimizeWindow() async {
    if (Platform.isWindows) {
      try {
        await windowManager.minimize();
      } catch (e) {
        debugPrint('Erro ao minimizar janela: $e');
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

  /// ✅ Fecha o aplicativo
  Future<void> _handleExitApp() async {
    final shouldClose = await showDialog<bool>(
      context: context,
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

    if (shouldClose == true) {
      // ✅ Fecha o aplicativo
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
  }

  // ✅ Listeners do WindowListener
  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = true;
      });
    }
  }

  @override
  void onWindowRestore() {
    if (mounted) {
      setState(() {
        _isMaximized = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      
      if (_isLogin) {
        // Login
        await _authService.signInWithEmail(
          email: email,
          password: _passwordController.text,
        );
        // ✅ Salva o email após login bem-sucedido
        await _saveLastEmail(email);
      } else {
        // Cadastro
        await _authService.signUp(
          name: _nameController.text.trim(),
          email: email,
          password: _passwordController.text,
        );
        // ✅ Salva o email após cadastro bem-sucedido
        await _saveLastEmail(email);
      }

      // Navegação será feita pelo listener de auth state
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;
    final formWidth = isSmallScreen ? double.infinity : 400.0; // ✅ Largura fixa de 400px em telas grandes
    
    return Scaffold(
      backgroundColor: const Color(0xFF00a4a4), // ✅ Fundo teal igual à tela de boas-vindas
      appBar: Platform.isWindows
          ? _DraggableAppBar(
              onWindowStateChanged: _checkAndUpdateWindowState,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  // ✅ Botão Minimizar (ícone nativo: linha horizontal)
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20, color: Colors.white),
                    onPressed: _minimizeWindow,
                    tooltip: 'Minimizar',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  // ✅ Botão Maximizar/Restaurar (ícones nativos: quadrado vazio / restaurar)
                  IconButton(
                    icon: Icon(
                      _isMaximized ? Icons.filter_none : Icons.crop_square,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: _toggleMaximizeWindow,
                    tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  // ✅ Botão Fechar (ícone nativo: X)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white),
                    onPressed: _handleExitApp,
                    tooltip: 'Fechar',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF00a4a4), // ✅ Fundo teal
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // ✅ Logo GZ em balão de fala branco (igual à tela de boas-vindas)
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
                const SizedBox(height: 40),
                
                // ✅ Título
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
                
                // ✅ Subtítulo
                const Text(
                  'Seu navegador personalizado com suporte a múltiplas abas e janelas',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                
                // ✅ Formulário centralizado com largura fixa (ou largura total em telas pequenas)
                Center(
                  child: SizedBox(
                    width: formWidth,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Nome',
                                labelStyle: const TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white70),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white70),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                prefixIcon: const Icon(Icons.person, color: Colors.white70),
                              ),
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                // ✅ Ao pressionar Enter no campo Nome, foca no campo Email
                                FocusScope.of(context).requestFocus(_emailFocusNode);
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Por favor, insira seu nome';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              prefixIcon: const Icon(Icons.email, color: Colors.white70),
                            ),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              // ✅ Ao pressionar Enter no campo Email, foca no campo Senha
                              FocusScope.of(context).requestFocus(_passwordFocusNode);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor, insira seu email';
                              }
                              if (!value.contains('@')) {
                                return 'Por favor, insira um email válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              labelStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                            ),
                            style: const TextStyle(color: Colors.white),
                            obscureText: true,
                            textInputAction: TextInputAction.go,
                            onFieldSubmitted: (_) {
                              // ✅ Ao pressionar Enter no campo Senha, submete o formulário
                              if (!_isLoading) {
                                _handleSubmit();
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira sua senha';
                              }
                              if (!_isLogin && value.length < 6) {
                                return 'A senha deve ter pelo menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[900]!.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[300]!),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00a4a4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00a4a4),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Entrar' : 'Criar Conta',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                      _errorMessage = null;
                                      _passwordController.clear();
                                    });
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isLogin
                                  ? 'Não tem uma conta? Cadastre-se'
                                  : 'Já tem uma conta? Faça login',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
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


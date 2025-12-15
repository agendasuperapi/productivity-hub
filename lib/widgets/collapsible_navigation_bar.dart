import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'page_navigation_bar.dart';

/// Barra de navegação colapsável com ícone flutuante
class CollapsibleNavigationBar extends StatefulWidget {
  final String currentUrl;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;
  final Function(String) onUrlSubmitted;
  final VoidCallback? onBackPressed;
  final VoidCallback? onForwardPressed;
  final VoidCallback? onRefreshPressed;
  final VoidCallback? onDownloadHistoryPressed;
  final VoidCallback? onZoomInPressed; // ✅ Callback para aumentar zoom
  final VoidCallback? onZoomOutPressed; // ✅ Callback para diminuir zoom
  final VoidCallback? onZoomResetPressed; // ✅ Callback para restaurar zoom padrão
  final double? currentZoom; // ✅ Zoom atual para exibir no tooltip
  final String? iconUrl;
  final String? pageName;
  final bool isPdfWindow;
  final bool isAlwaysOnTop;
  final bool? externalVisibility; // ✅ Permite controle externo da visibilidade
  final Function(bool)? onVisibilityChanged; // ✅ Callback quando a visibilidade mudar

  const CollapsibleNavigationBar({
    super.key,
    required this.currentUrl,
    required this.isLoading,
    required this.canGoBack,
    required this.canGoForward,
    required this.onUrlSubmitted,
    this.onBackPressed,
    this.onForwardPressed,
    this.onRefreshPressed,
    this.onDownloadHistoryPressed,
    this.onZoomInPressed,
    this.onZoomOutPressed,
    this.onZoomResetPressed,
    this.currentZoom,
    this.onVisibilityChanged,
    this.iconUrl,
    this.pageName,
    this.isPdfWindow = false,
    this.isAlwaysOnTop = false,
    this.externalVisibility, // ✅ Controle externo opcional
  });

  @override
  State<CollapsibleNavigationBar> createState() => _CollapsibleNavigationBarState();
}

class _CollapsibleNavigationBarState extends State<CollapsibleNavigationBar>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Posição do ícone flutuante (em coordenadas relativas: 0.0 a 1.0)
  Offset _iconPosition = const Offset(1.0, 1.0); // Posição padrão: canto inferior direito (100%, 100%)
  bool _isDragging = false;
  
  // ✅ Timer para ocultar automaticamente após 10 segundos de inatividade
  Timer? _autoHideTimer;
  static const Duration _autoHideDuration = Duration(seconds: 10);
  
  // ✅ Flag para indicar se a ocultação foi automática (via timer)
  bool _wasAutoHidden = false;
  
  static const String _prefsKeyPositionX = 'nav_bar_icon_position_x';
  static const String _prefsKeyPositionY = 'nav_bar_icon_position_y';

  @override
  void initState() {
    super.initState();
    _loadIconPosition();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Começa fora da tela (em cima)
      end: Offset.zero, // Termina na posição normal
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // ✅ Inicializa visibilidade com valor externo se fornecido
    if (widget.externalVisibility != null) {
      _isVisible = widget.externalVisibility!;
      // ✅ Aplica o valor inicial da animação baseado na visibilidade externa
      if (_isVisible) {
        _animationController.value = 1.0;
        // ✅ Inicia timer para ocultar automaticamente após 10 segundos
        _startAutoHideTimer();
      } else {
        _animationController.value = 0.0;
      }
    }
  }
  
  /// ✅ Inicia o timer para ocultar automaticamente após 10 segundos
  void _startAutoHideTimer() {
    _cancelAutoHideTimer();
    // ✅ Sempre inicia o timer quando a barra está visível
    if (_isVisible) {
      _wasAutoHidden = false; // ✅ Reseta flag quando inicia novo timer
      _autoHideTimer = Timer(_autoHideDuration, () {
        if (mounted && _isVisible) {
          // ✅ Ocultar automaticamente após 10 segundos, mesmo com controle externo
          // O controle externo pode mostrar novamente se necessário, mas após 10s sem interação, oculta
          setState(() {
            _isVisible = false;
            _wasAutoHidden = true; // ✅ Marca que foi ocultado automaticamente
            _animationController.reverse();
          });
          // ✅ Notifica o componente pai sobre a mudança de visibilidade
          widget.onVisibilityChanged?.call(false);
          // ✅ Cancela o timer após ocultar
          _cancelAutoHideTimer();
        }
      });
    }
  }
  
  /// ✅ Cancela o timer de ocultação automática
  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }
  
  /// ✅ Reseta o timer (chamado quando há interação)
  void _resetAutoHideTimer() {
    if (_isVisible) {
      _wasAutoHidden = false; // ✅ Reseta flag quando há interação
      _startAutoHideTimer();
    }
  }

  @override
  void didUpdateWidget(CollapsibleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Se a visibilidade externa mudou, atualiza o estado interno e a animação
    if (widget.externalVisibility != null) {
      final newVisibility = widget.externalVisibility!;
      // ✅ Se a visibilidade externa mudou explicitamente (não foi apenas uma atualização do widget)
      // ou se o estado interno não corresponde ao externo E não foi ocultado automaticamente
      if (oldWidget.externalVisibility != widget.externalVisibility || 
          (_isVisible != newVisibility && !_wasAutoHidden)) {
        if (_isVisible != newVisibility) {
      setState(() {
        _isVisible = newVisibility;
        _wasAutoHidden = false; // ✅ Reseta flag quando visibilidade é controlada externamente
        if (_isVisible) {
          _animationController.forward();
          // ✅ Inicia timer para ocultar automaticamente quando barra é mostrada
          _startAutoHideTimer();
        } else {
          _animationController.reverse();
          _cancelAutoHideTimer();
        }
      });
      // ✅ Notifica o componente pai sobre a mudança de visibilidade
      widget.onVisibilityChanged?.call(_isVisible);
        }
      }
      // ✅ Se foi ocultado automaticamente mas o controle externo ainda está como true,
      // não força a barra a aparecer novamente até que haja uma mudança explícita
    } else if (oldWidget.externalVisibility != null && widget.externalVisibility == null) {
      // Se mudou de controle externo para controle interno, reseta para false
      if (_isVisible) {
        setState(() {
          _isVisible = false;
          _wasAutoHidden = false;
          _animationController.reverse();
          _cancelAutoHideTimer();
        });
      }
    }
  }

  /// Carrega a posição salva do ícone
  Future<void> _loadIconPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_prefsKeyPositionX);
      final y = prefs.getDouble(_prefsKeyPositionY);
      if (x != null && y != null && mounted) {
        setState(() {
          // Garante que os valores estão entre 0.0 e 1.0
          _iconPosition = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        });
      }
    } catch (e) {
      // Ignora erros silenciosamente
    }
  }

  /// Salva a posição do ícone
  Future<void> _saveIconPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyPositionX, _iconPosition.dx);
      await prefs.setDouble(_prefsKeyPositionY, _iconPosition.dy);
    } catch (e) {
      // Ignora erros silenciosamente
    }
  }

  @override
  void dispose() {
    _cancelAutoHideTimer();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleVisibility() {
    // ✅ Só permite toggle se não houver controle externo
    if (widget.externalVisibility == null) {
      setState(() {
        _isVisible = !_isVisible;
        if (_isVisible) {
          _animationController.forward();
          // ✅ Inicia timer para ocultar automaticamente quando barra é mostrada
          _startAutoHideTimer();
        } else {
          _animationController.reverse();
          _cancelAutoHideTimer();
        }
      });
      // ✅ Notifica o componente pai sobre a mudança de visibilidade
      widget.onVisibilityChanged?.call(_isVisible);
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      // Calcula nova posição em coordenadas relativas (0.0 a 1.0)
      // ✅ Inverte delta.dy porque o eixo Y é invertido (0.0 = topo, 1.0 = base)
      double newX = _iconPosition.dx + (details.delta.dx / screenSize.width);
      double newY = _iconPosition.dy - (details.delta.dy / screenSize.height); // ✅ Invertido: menos delta.dy
      
      // Limita dentro dos limites (0.0 a 1.0)
      newX = newX.clamp(0.0, 1.0);
      newY = newY.clamp(0.0, 1.0);
      
      _iconPosition = Offset(newX, newY);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _saveIconPosition();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const iconSize = 28.0; // Tamanho menor e mais discreto
    const padding = 12.0; // Padding mínimo das bordas
    
    // Calcula posição absoluta a partir da posição relativa
    // Considera que _iconPosition.dx=1.0 significa canto direito, dy=1.0 significa canto inferior
    final absoluteX = screenSize.width * _iconPosition.dx - iconSize - padding;
    final absoluteY = screenSize.height * (1.0 - _iconPosition.dy) - iconSize - padding;
    
    // Ajusta quando a barra está visível (move para baixo para não sobrepor a barra)
    final topOffset = _isVisible ? 60.0 : 0.0;
    final finalY = absoluteY + topOffset;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Barra de navegação colapsável no topo
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black54,
                child: PageNavigationBar(
                  currentUrl: widget.currentUrl,
                  isLoading: widget.isLoading,
                  canGoBack: widget.canGoBack,
                  canGoForward: widget.canGoForward,
                  onUrlSubmitted: widget.onUrlSubmitted,
                  onBackPressed: widget.onBackPressed,
                  onForwardPressed: widget.onForwardPressed,
                  onRefreshPressed: widget.onRefreshPressed,
                  onDownloadHistoryPressed: widget.onDownloadHistoryPressed,
                  onZoomInPressed: widget.onZoomInPressed,
                  onZoomOutPressed: widget.onZoomOutPressed,
                  onZoomResetPressed: widget.onZoomResetPressed,
                  currentZoom: widget.currentZoom, // ✅ Passa zoom atual para exibir no tooltip
                  onUrlFieldInteraction: () {
                    // ✅ Reseta timer quando há interação no campo de endereços
                    _resetAutoHideTimer();
                  },
                  iconUrl: widget.iconUrl,
                  pageName: widget.pageName,
                  isPdfWindow: widget.isPdfWindow,
                  isAlwaysOnTop: widget.isAlwaysOnTop,
                ),
              ),
            ),
          ),
        ),
        // Ícone flutuante arrastável para mostrar/esconder (oculto quando há controle externo)
        if (widget.externalVisibility == null) // ✅ Só mostra o ícone individual se não houver controle externo
          Positioned(
            left: absoluteX.clamp(padding, screenSize.width - iconSize - padding),
            top: finalY.clamp(padding + topOffset, screenSize.height - iconSize - padding),
            child: GestureDetector(
              onPanStart: _onPanStart,
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: _onPanEnd,
            onTap: _toggleVisibility,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDragging 
                    ? Colors.black.withOpacity(0.05) 
                    : Colors.transparent,
                boxShadow: _isDragging
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(iconSize / 2),
                  onTap: _toggleVisibility,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: _isVisible ? 0.5 : 0.0,
                      child: Icon(
                        _isVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: const Color(0xFF00a4a4), // Cor do tema do app
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

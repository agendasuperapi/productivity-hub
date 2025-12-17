import 'package:flutter/material.dart';

/// Dialog que pode ser arrastado e redimensionado
/// Use este widget dentro de um Dialog com insetPadding: EdgeInsets.zero
class DraggableResizableDialog extends StatefulWidget {
  final Widget child;
  final double? initialWidth;
  final double? initialHeight;
  final double minWidth;
  final double minHeight;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Widget? titleBar; // Barra de título customizada para arrastar

  const DraggableResizableDialog({
    super.key,
    required this.child,
    this.initialWidth,
    this.initialHeight,
    this.minWidth = 300,
    this.minHeight = 200,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.titleBar,
  });

  @override
  State<DraggableResizableDialog> createState() => _DraggableResizableDialogState();
}

class _DraggableResizableDialogState extends State<DraggableResizableDialog> {
  late double _width;
  late double _height;
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _isResizing = false;
  Offset _dragStart = Offset.zero;
  Offset _resizeStart = Offset.zero;
  Size _resizeStartSize = Size.zero;
  String _resizeDirection = '';
  final GlobalKey _dialogKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSize();
    });
  }

  void _initializeSize() {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _width = widget.initialWidth ?? (screenSize.width * 0.5).clamp(widget.minWidth, screenSize.width * 0.9);
      _height = widget.initialHeight ?? (screenSize.height * 0.5).clamp(widget.minHeight, screenSize.height * 0.9);
      
      // Centraliza o dialog inicialmente
      _position = Offset(
        (screenSize.width - _width) / 2,
        (screenSize.height - _height) / 2,
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? renderBox = _dialogKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Verifica se está clicando na área de redimensionamento (bordas e cantos)
    const resizeArea = 8.0;
    final isNearLeft = localPosition.dx < resizeArea;
    final isNearRight = localPosition.dx > _width - resizeArea;
    final isNearTop = localPosition.dy < resizeArea;
    final isNearBottom = localPosition.dy > _height - resizeArea;
    
    if (isNearLeft || isNearRight || isNearTop || isNearBottom) {
      _isResizing = true;
      _resizeStart = details.globalPosition;
      _resizeStartSize = Size(_width, _height);
      
      // Determina a direção do redimensionamento
      if (isNearTop && isNearLeft) {
        _resizeDirection = 'top-left';
      } else if (isNearTop && isNearRight) {
        _resizeDirection = 'top-right';
      } else if (isNearBottom && isNearLeft) {
        _resizeDirection = 'bottom-left';
      } else if (isNearBottom && isNearRight) {
        _resizeDirection = 'bottom-right';
      } else if (isNearLeft) {
        _resizeDirection = 'left';
      } else if (isNearRight) {
        _resizeDirection = 'right';
      } else if (isNearTop) {
        _resizeDirection = 'top';
      } else if (isNearBottom) {
        _resizeDirection = 'bottom';
      }
    } else {
      // Verifica se está clicando na área de arrastar (topo do dialog - primeiros 50px)
      if (localPosition.dy < 50) {
        _isDragging = true;
        _dragStart = details.globalPosition - _position;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isResizing) {
      final delta = details.globalPosition - _resizeStart;
      final screenSize = MediaQuery.of(context).size;
      
      setState(() {
        switch (_resizeDirection) {
          case 'top-left':
            _width = (_resizeStartSize.width - delta.dx).clamp(widget.minWidth, screenSize.width);
            _height = (_resizeStartSize.height - delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              (_position.dx + delta.dx).clamp(0.0, screenSize.width - _width),
              (_position.dy + delta.dy).clamp(0.0, screenSize.height - _height),
            );
            break;
          case 'top-right':
            _width = (_resizeStartSize.width + delta.dx).clamp(widget.minWidth, screenSize.width);
            _height = (_resizeStartSize.height - delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              _position.dx.clamp(0.0, screenSize.width - _width),
              (_position.dy + delta.dy).clamp(0.0, screenSize.height - _height),
            );
            break;
          case 'bottom-left':
            _width = (_resizeStartSize.width - delta.dx).clamp(widget.minWidth, screenSize.width);
            _height = (_resizeStartSize.height + delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              (_position.dx + delta.dx).clamp(0.0, screenSize.width - _width),
              _position.dy.clamp(0.0, screenSize.height - _height),
            );
            break;
          case 'bottom-right':
            _width = (_resizeStartSize.width + delta.dx).clamp(widget.minWidth, screenSize.width);
            _height = (_resizeStartSize.height + delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              _position.dx.clamp(0.0, screenSize.width - _width),
              _position.dy.clamp(0.0, screenSize.height - _height),
            );
            break;
          case 'left':
            _width = (_resizeStartSize.width - delta.dx).clamp(widget.minWidth, screenSize.width);
            _position = Offset(
              (_position.dx + delta.dx).clamp(0.0, screenSize.width - _width),
              _position.dy,
            );
            break;
          case 'right':
            _width = (_resizeStartSize.width + delta.dx).clamp(widget.minWidth, screenSize.width);
            _position = Offset(
              _position.dx.clamp(0.0, screenSize.width - _width),
              _position.dy,
            );
            break;
          case 'top':
            _height = (_resizeStartSize.height - delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              _position.dx,
              (_position.dy + delta.dy).clamp(0.0, screenSize.height - _height),
            );
            break;
          case 'bottom':
            _height = (_resizeStartSize.height + delta.dy).clamp(widget.minHeight, screenSize.height);
            _position = Offset(
              _position.dx,
              _position.dy.clamp(0.0, screenSize.height - _height),
            );
            break;
        }
      });
    } else if (_isDragging) {
      final screenSize = MediaQuery.of(context).size;
      final newPosition = details.globalPosition - _dragStart;
      
      setState(() {
        _position = Offset(
          newPosition.dx.clamp(0.0, screenSize.width - _width),
          newPosition.dy.clamp(0.0, screenSize.height - _height),
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _isResizing = false;
    _resizeDirection = '';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Inicializa se ainda não foi inicializado
    if (_width == 0 || _height == 0) {
      _width = widget.initialWidth ?? (screenSize.width * 0.5).clamp(widget.minWidth, screenSize.width * 0.9);
      _height = widget.initialHeight ?? (screenSize.height * 0.5).clamp(widget.minHeight, screenSize.height * 0.9);
      _position = Offset(
        (screenSize.width - _width) / 2,
        (screenSize.height - _height) / 2,
      );
    }

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dialog posicionado
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              behavior: HitTestBehavior.translucent,
              child: Material(
                key: _dialogKey,
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                elevation: 8,
                child: Container(
                  width: _width,
                  height: _height,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.white,
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Conteúdo do dialog
                      Padding(
                        padding: widget.padding ?? const EdgeInsets.all(16),
                        child: widget.child,
                      ),
                      // Barra de título para arrastar (se fornecida)
                      if (widget.titleBar != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: widget.titleBar!,
                        ),
                      // Áreas de redimensionamento
                      // Canto superior esquerdo
                      Positioned(
                        top: 0,
                        left: 0,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'top-left';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpLeft,
                          child: Container(
                            width: 8,
                            height: 8,
                            color: Colors.transparent,
                          ),
                          ),
                        ),
                      ),
                      // Canto superior direito
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'top-right';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpRight,
                          child: Container(
                            width: 8,
                            height: 8,
                            color: Colors.transparent,
                          ),
                          ),
                        ),
                      ),
                      // Canto inferior esquerdo
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'bottom-left';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeDownLeft,
                          child: Container(
                            width: 8,
                            height: 8,
                            color: Colors.transparent,
                          ),
                          ),
                        ),
                      ),
                      // Canto inferior direito
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'bottom-right';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeDownRight,
                          child: Container(
                            width: 8,
                            height: 8,
                            color: Colors.transparent,
                          ),
                          ),
                        ),
                      ),
                      // Borda esquerda
                      Positioned(
                        left: 0,
                        top: 8,
                        bottom: 8,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'left';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Container(width: 4, color: Colors.transparent),
                          ),
                        ),
                      ),
                      // Borda direita
                      Positioned(
                        right: 0,
                        top: 8,
                        bottom: 8,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'right';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Container(width: 4, color: Colors.transparent),
                          ),
                        ),
                      ),
                      // Borda superior
                      Positioned(
                        top: 0,
                        left: 8,
                        right: 8,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'top';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: Container(height: 4, color: Colors.transparent),
                          ),
                        ),
                      ),
                      // Borda inferior
                      Positioned(
                        bottom: 0,
                        left: 8,
                        right: 8,
                        child: GestureDetector(
                        onPanStart: (details) {
                          _isResizing = true;
                          _resizeStart = details.globalPosition;
                          _resizeStartSize = Size(_width, _height);
                          _resizeDirection = 'bottom';
                        },
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: Container(height: 4, color: Colors.transparent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget que renderiza ícones de forma inteligente
/// Detecta automaticamente se é SVG ou imagem normal e renderiza adequadamente
class IconImageWidget extends StatelessWidget {
  final String? iconUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Color? color;

  const IconImageWidget({
    super.key,
    required this.iconUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.color,
  });

  /// Verifica se a URL é um SVG
  bool _isSvg(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      return path.endsWith('.svg') || path.contains('.svg?');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (iconUrl == null || iconUrl!.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    // ✅ Detecta se é SVG e renderiza adequadamente
    if (_isSvg(iconUrl!)) {
      return SvgPicture.network(
        iconUrl!,
        width: width,
        height: height,
        fit: fit,
        colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
        placeholderBuilder: (context) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    } else {
      // ✅ Para PNG, JPG, etc., usa Image.network
      return Image.network(
        iconUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              SizedBox(
                width: width,
                height: height,
                child: const Icon(Icons.broken_image, size: 16),
              );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
      );
    }
  }
}


import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable glass container adhering to subtle glassmorphic styling
/// without sharp contrasts, thick outlines, or neobrutalist borders.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity = 0.08,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: effectiveBorderRadius,
              border: Border.all(
                color: AppTheme.glassBorder,
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: opacity + 0.05),
                  Colors.white.withValues(alpha: opacity),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

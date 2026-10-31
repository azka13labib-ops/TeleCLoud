import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Glassmorphic button adhering strictly to modern translucent styles (No Neobrutalism)
class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final Color? accentColor;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.accentColor,
    this.height = 52.0,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16.0);
    final primaryColor = accentColor ?? AppTheme.accentCyan;

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius: effectiveRadius,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.22),
                primaryColor.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: effectiveRadius,
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


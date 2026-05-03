import 'package:flutter/material.dart';

/// Horizontal Grabbit wordmark + basket icon (asset).
/// SVG-style monochrome artwork is tinted with [color] so it works on any background.
class GrabbitLogo extends StatelessWidget {
  const GrabbitLogo({
    super.key,
    this.height = 36,
    this.color,
  });

  final double height;
  final Color? color;

  static const assetPath = 'assets/images/grabbit_logo.png';

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

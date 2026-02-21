import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final double padding;

  const AppLogo({
    super.key,
    this.size = 40,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.padding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.25);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/claw_logo.png',
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.appleGray,
          ),
        ),
      ),
      ),
    );
  }
}

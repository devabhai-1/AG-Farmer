import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool framed;
  final double radius;

  const BrandLogo({
    super.key,
    this.size = 44,
    this.framed = true,
    this.radius = 14,
  });

  static const assetPath = 'assets/brand/ag_farmer_logo.png';

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(framed ? radius - 2 : radius),
      child: Image.asset(
        assetPath,
        width: framed ? size - 4 : size,
        height: framed ? size - 4 : size,
        cacheWidth: ((framed ? size - 4 : size) * 3).toInt().clamp(32, 512),
        cacheHeight: ((framed ? size - 4 : size) * 3).toInt().clamp(32, 512),
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => Icon(
          Icons.eco_rounded,
          size: size * 0.48,
          color: AgroColors.deepGreen,
        ),
      ),
    );

    if (!framed) return image;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AgroColors.champagne.withValues(alpha: 0.85), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AgroColors.deepGreen.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: image,
    );
  }
}

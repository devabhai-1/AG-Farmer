import 'package:flutter/material.dart';

import '../models/crop_item.dart';
import '../theme/app_theme.dart';

/// Crop mark: Afim uses the brand asset; others show emoji.
class CropGlyph extends StatelessWidget {
  const CropGlyph({
    super.key,
    this.cropId,
    this.emoji = '🌾',
    this.size = 28,
  });

  final String? cropId;
  final String emoji;
  final double size;

  String get _id => cropId ?? '';

  factory CropGlyph.item(CropItem crop, {Key? key, double size = 28}) {
    return CropGlyph(
      key: key,
      cropId: crop.id,
      emoji: crop.emoji,
      size: size,
    );
  }

  bool get _isAfim =>
      _id == 'afim' || _id.startsWith('afim');

  @override
  Widget build(BuildContext context) {
    if (_isAfim) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/crops/afim_doda.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            emoji.isNotEmpty ? emoji : '🌸',
            style: TextStyle(fontSize: size * 0.82, height: 1),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji.isNotEmpty ? emoji : '🌾',
          style: TextStyle(
            fontSize: size * 0.82,
            height: 1,
            color: context.agroText,
          ),
        ),
      ),
    );
  }
}

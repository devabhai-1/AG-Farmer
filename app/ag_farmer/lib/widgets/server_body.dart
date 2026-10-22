import 'package:flutter/material.dart';

import '../services/screen_pack.dart';

/// Lays out named slots in server `order` / `blocks`, else [fallback].
class ServerBody extends StatelessWidget {
  const ServerBody({
    super.key,
    required this.screen,
    required this.fallback,
    required this.slots,
  });

  final String screen;
  final List<String> fallback;
  final Map<String, Widget> slots;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: screenPack,
      builder: (context, _) {
        final order = screenPack.order(screen) ?? fallback;
        final children = <Widget>[];
        for (final key in order) {
          final w = slots[key];
          if (w != null) children.add(w);
        }
        // Include any declared slots missing from order (safety).
        for (final entry in slots.entries) {
          if (!order.contains(entry.key)) children.add(entry.value);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

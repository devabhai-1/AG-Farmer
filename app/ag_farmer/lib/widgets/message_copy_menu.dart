import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Long-press copy menu for chat bubbles.
Future<void> showMessageCopyMenu(
  BuildContext context, {
  required String text,
  required bool hindi,
  required String copiedLabel,
}) async {
  final clean = text.trim();
  if (clean.isEmpty) return;

  final box = context.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  RelativeRect position;
  if (box != null && overlay != null) {
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy,
      overlay.size.width - origin.dx - box.size.width,
      overlay.size.height - origin.dy - box.size.height,
    );
  } else {
    position = const RelativeRect.fromLTRB(40, 120, 40, 120);
  }

  final label = hindi ? 'कॉपी' : 'Copy';
  final chosen = await showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem<String>(
        value: 'copy',
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
  if (chosen != 'copy') return;
  await Clipboard.setData(ClipboardData(text: clean));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(copiedLabel),
      duration: const Duration(seconds: 2),
    ),
  );
}

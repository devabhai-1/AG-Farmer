import 'dart:io';

import 'package:flutter/material.dart';

bool localFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<int> localFileLength(String path) => File(path).length();

Widget localFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (!localFileExists(path)) return const Icon(Icons.image_rounded);
  return Image.file(File(path), width: width, height: height, fit: fit);
}

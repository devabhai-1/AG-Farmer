import 'package:flutter/material.dart';

bool localFileExists(String path) =>
    path.startsWith('blob:') || path.startsWith('http');

Future<int> localFileLength(String path) async => 0;

Widget localFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (path.startsWith('blob:') || path.startsWith('http')) {
    return Image.network(path, width: width, height: height, fit: fit);
  }
  return const Icon(Icons.image_rounded);
}

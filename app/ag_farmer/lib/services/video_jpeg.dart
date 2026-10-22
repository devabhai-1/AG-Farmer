import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Snapshot of one camera frame (YUV420), ready for background JPEG encode.
class CameraFrame {
  CameraFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.turns,
    required this.maxSide,
    required this.quality,
  });

  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int turns;
  final int maxSide;
  final int quality;

  /// Copy plane bytes off the camera buffer before the next frame arrives.
  static CameraFrame copy(
    CameraImage image, {
    int turns = 90,
    int maxSide = 512,
    int quality = 55,
  }) {
    final planes = image.planes;
    if (planes.length < 3) {
      throw StateError('camera_planes');
    }
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];
    return CameraFrame(
      width: image.width,
      height: image.height,
      y: Uint8List.fromList(yPlane.bytes),
      u: Uint8List.fromList(uPlane.bytes),
      v: Uint8List.fromList(vPlane.bytes),
      yRowStride: yPlane.bytesPerRow,
      uvRowStride: uPlane.bytesPerRow,
      uvPixelStride: uPlane.bytesPerPixel ?? 1,
      turns: turns,
      maxSide: maxSide,
      quality: quality,
    );
  }
}

/// Encode [frame] to JPEG on a background isolate when possible.
Future<Uint8List?> encodeFrameJpeg(CameraFrame frame) async {
  final payload = <String, Object>{
    'width': frame.width,
    'height': frame.height,
    'y': frame.y,
    'u': frame.u,
    'v': frame.v,
    'yRowStride': frame.yRowStride,
    'uvRowStride': frame.uvRowStride,
    'uvPixelStride': frame.uvPixelStride,
    'turns': frame.turns,
    'maxSide': frame.maxSide,
    'quality': frame.quality,
  };
  try {
    return await compute(_encodeIsolate, payload);
  } catch (e) {
    if (kDebugMode) debugPrint('encodeFrameJpeg: $e');
    try {
      return _encodeIsolate(payload);
    } catch (_) {
      return null;
    }
  }
}

Uint8List? _encodeIsolate(Map<String, Object> payload) {
  final frame = CameraFrame(
    width: payload['width'] as int,
    height: payload['height'] as int,
    y: payload['y'] as Uint8List,
    u: payload['u'] as Uint8List,
    v: payload['v'] as Uint8List,
    yRowStride: payload['yRowStride'] as int,
    uvRowStride: payload['uvRowStride'] as int,
    uvPixelStride: payload['uvPixelStride'] as int,
    turns: payload['turns'] as int,
    maxSide: payload['maxSide'] as int,
    quality: payload['quality'] as int,
  );
  final rgb = _yuv420ToImage(frame);
  if (rgb == null) return null;
  var out = rgb;
  final longest = out.width > out.height ? out.width : out.height;
  if (frame.maxSide > 0 && longest > frame.maxSide) {
    final scale = frame.maxSide / longest;
    out = img.copyResize(
      out,
      width: (out.width * scale).round().clamp(1, frame.maxSide),
      height: (out.height * scale).round().clamp(1, frame.maxSide),
      interpolation: img.Interpolation.linear,
    );
  }
  final rotated = _rotate(out, frame.turns);
  final q = frame.quality.clamp(20, 95);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: q));
}

img.Image _rotate(img.Image src, int turns) {
  final deg = ((turns % 360) + 360) % 360;
  if (deg == 90) return img.copyRotate(src, angle: 90);
  if (deg == 180) return img.copyRotate(src, angle: 180);
  if (deg == 270) return img.copyRotate(src, angle: 270);
  return src;
}

img.Image? _yuv420ToImage(CameraFrame frame) {
  final w = frame.width;
  final h = frame.height;
  if (w <= 0 || h <= 0) return null;
  final out = img.Image(width: w, height: h);
  final y = frame.y;
  final u = frame.u;
  final v = frame.v;
  final yStride = frame.yRowStride;
  final uvStride = frame.uvRowStride;
  final uvPix = frame.uvPixelStride <= 0 ? 1 : frame.uvPixelStride;

  for (var row = 0; row < h; row++) {
    final yRow = row * yStride;
    final uvRow = (row >> 1) * uvStride;
    for (var col = 0; col < w; col++) {
      final yp = yRow + col;
      if (yp >= y.length) continue;
      final uvIndex = uvRow + (col >> 1) * uvPix;
      final yVal = y[yp];
      final uVal = uvIndex < u.length ? u[uvIndex] : 128;
      final vVal = uvIndex < v.length ? v[uvIndex] : 128;
      final c = yVal - 16;
      final d = uVal - 128;
      final e = vVal - 128;
      final r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
      final g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
      final b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
      out.setPixelRgb(col, row, r, g, b);
    }
  }
  return out;
}

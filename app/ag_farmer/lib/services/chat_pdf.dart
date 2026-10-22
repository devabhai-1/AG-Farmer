import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/chat_message.dart';
import '../widgets/brand_logo.dart';
import '../widgets/chat_answer_body.dart';

const _brand = PdfColor(0.008, 0.518, 0.780);
const _maxPdfPages = 100;
const _pageBody = 620.0;
const _installUrl =
    'https://play.google.com/store/apps/details?id=com.agfarmer.app';

/// The user question that produced this answer, plus the answer itself.
List<ChatMessage> turnForPdf(List<ChatMessage> all, ChatMessage output) {
  var at = all.lastIndexWhere((m) => identical(m, output));
  if (at < 0 && output.id.isNotEmpty && output.id != 'null') {
    at = all.lastIndexWhere((m) => m.id == output.id);
  }
  if (at < 0) return [output];
  ChatMessage? input;
  for (var i = at - 1; i >= 0; i--) {
    final m = all[i];
    if (m.id.startsWith('welcome_') || m.id.startsWith('summary_')) continue;
    if (m.role == MessageRole.assistant) break;
    if (m.role == MessageRole.user) {
      input = m;
      break;
    }
  }
  return [?input, all[at]];
}

String turnPdfTitle(List<ChatMessage> turn, {required bool hi}) {
  var title = '';
  for (final m in turn) {
    if (m.role != MessageRole.user) continue;
    title = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isNotEmpty) break;
  }
  if (title.isEmpty) title = hi ? 'चैट' : 'Chat';
  if (title.length > 40) title = title.substring(0, 40).trim();
  return title;
}

/// Builds one chat as a PDF and opens the phone share sheet.
Future<void> shareChatPdf({
  required String title,
  required List<ChatMessage> messages,
  required bool hi,
}) async {
  final rows = messages.where((m) {
    if (m.id.startsWith('welcome_') || m.id.startsWith('summary_')) {
      return false;
    }
    return m.text.trim().isNotEmpty || m.hasMedia || _photoPath(m) != null;
  }).toList();
  final fontData = await rootBundle.load('assets/fonts/Hind-Regular.ttf');
  final logoData = await rootBundle.load(BrandLogo.assetPath);
  final font = pw.Font.ttf(fontData);
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());
  final photos = await _photosFor(rows);
  final doc = pw.Document();
  final heading = title.trim().isEmpty
      ? (hi ? 'चैट' : 'Chat')
      : title.trim();

  final bits = <_Bit>[
    _Bit(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 2),
          pw.Text(
            hi ? 'खेती सलाह' : 'Farm advice',
            style: pw.TextStyle(font: font, fontSize: 10, color: _brand),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            heading,
            style: pw.TextStyle(font: font, fontSize: 18),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: 72,
            height: 2.2,
            decoration: const pw.BoxDecoration(color: _brand),
          ),
          pw.SizedBox(height: 14),
        ],
      ),
      70,
    ),
    if (rows.isEmpty)
      _Bit(
        pw.Text(
          hi ? 'इस चैट में अभी कोई बात नहीं है।' : 'This chat has no messages yet.',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        24,
      )
    else
      ...rows.expand((m) => _talkPieces(m, font, hi, photos[m.id])),
  ];

  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPdfPages,
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 22, 32, 40),
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  size: PdfPoint(PdfPageFormat.a4.width, PdfPageFormat.a4.height),
                  painter: _pageStripes,
                ),
              ),
              pw.Positioned(
                left: 0,
                right: 0,
                top: PdfPageFormat.a4.height / 2 - 28,
                child: _blurMark(font),
              ),
            ],
          ),
        ),
      ),
      header: (context) => _stamp(logo, font, hi),
      footer: (context) => pw.Container(
        color: PdfColors.white,
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          'AG Farmer  -  ${context.pageNumber}/${context.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => _fitPdfPages(bits, font, hi),
    ),
  );

  final bytes = await doc.save();
  final dir = await getTemporaryDirectory();
  final fileName = _pdfFileName(heading);
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  const caption =
      'AG Farmer — कृषि AI, अफीम और लहसुन के लिए स्पेशल।\nऐप लगाएँ: $_installUrl';
  try {
    await const MethodChannel('ag_farmer/share_pdf').invokeMethod<void>('share', {
      'path': file.path,
      'caption': caption,
    });
  } catch (_) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: fileName),
        ],
        text: caption,
      ),
    );
  }
}

String _pdfFileName(String heading) {
  var title = heading
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty) title = 'Chat';
  if (title.length > 60) title = title.substring(0, 60).trim();
  return 'AG-Farmer-Chat-$title.pdf';
}

/// Horizontal bands across the whole page. Each stripe is 60% of its band.
void _pageStripes(PdfGraphics canvas, PdfPoint size) {
  const band = 16.0;
  final stripe = band * 0.60;
  canvas.setFillColor(PdfColor(_brand.red, _brand.green, _brand.blue, 0.60));
  for (var y = 0.0; y < size.y; y += band) {
    canvas
      ..drawRect(0, y, size.x, stripe)
      ..fillPath();
  }
}

pw.Widget _blurMark(pw.Font font) {
  pw.Widget ghost(double dx, double dy, double opacity) {
    return pw.Transform.translate(
      offset: PdfPoint(dx, dy),
      child: pw.Opacity(
        opacity: opacity,
        child: pw.Text(
          'AG Farmer',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            fontSize: 34,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  return pw.Center(
    child: pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        ghost(-1.6, 0.4, 0.22),
        ghost(1.5, -0.3, 0.22),
        ghost(0.2, 1.6, 0.18),
        ghost(-0.4, -1.4, 0.18),
        ghost(0, 0, 0.55),
      ],
    ),
  );
}

class _PdfPhoto {
  const _PdfPhoto(this.image, this.width, this.height);
  final pw.MemoryImage image;
  final double width;
  final double height;
}

String? _photoPath(ChatMessage message) {
  if (message.mediaType == ChatMediaType.video ||
      message.mediaType == ChatMediaType.audio ||
      message.mediaType == ChatMediaType.file) {
    return null;
  }
  final path = message.displayMediaPath ?? message.exampleImageUrl;
  if (path == null || path.trim().isEmpty) return null;
  return path.trim();
}

Future<Map<String, _PdfPhoto>> _photosFor(List<ChatMessage> rows) async {
  final out = <String, _PdfPhoto>{};
  final cache = <String, _PdfPhoto?>{};
  for (final message in rows) {
    final path = _photoPath(message);
    if (path == null) continue;
    if (!cache.containsKey(path)) {
      cache[path] = await _loadPhoto(path);
    }
    final photo = cache[path];
    if (photo != null) out[message.id] = photo;
  }
  return out;
}

Future<_PdfPhoto?> _loadPhoto(String path) async {
  try {
    final raw = await _readPhoto(path);
    if (raw == null || raw.isEmpty) return null;
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    final baked = img.bakeOrientation(decoded);
    var sized = baked;
    if (sized.width > 1100) sized = img.copyResize(sized, width: 1100);
    if (sized.height > 1400) sized = img.copyResize(sized, height: 1400);
    final jpg = Uint8List.fromList(img.encodeJpg(sized, quality: 74));
    const maxW = 450.0;
    const maxH = 340.0;
    var w = maxW;
    var h = maxW * sized.height / sized.width;
    if (h > maxH) {
      h = maxH;
      w = maxH * sized.width / sized.height;
    }
    return _PdfPhoto(pw.MemoryImage(jpg), w, h);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _readPhoto(String path) async {
  if (path.startsWith('data:image')) {
    final comma = path.indexOf(',');
    if (comma < 0) return null;
    return base64Decode(path.substring(comma + 1));
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    final res = await http.get(Uri.parse(path)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  }
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

class _Bit {
  const _Bit(this.widget, this.height);
  final pw.Widget widget;
  final double height;
}

/// Release builds ignore the PDF library page cap, so stop the body here.
List<pw.Widget> _fitPdfPages(List<_Bit> bits, pw.Font font, bool hi) {
  final out = <pw.Widget>[];
  var page = 1;
  var used = 0.0;
  var cut = false;
  for (final bit in bits) {
    final height = bit.height <= 0 ? 24.0 : bit.height;
    if (used > 0 && used + height > _pageBody) {
      if (page >= _maxPdfPages) {
        cut = true;
        break;
      }
      page += 1;
      used = 0;
    }
    used += height;
    out.add(bit.widget);
  }
  if (cut) {
    out.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          hi
              ? 'यहीं तक। PDF 100 पेज पर रुक गई।'
              : 'Stopped here. The PDF stops at 100 pages.',
          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
        ),
      ),
    );
  }
  return out;
}

/// One piece per page-child. A single tall column never finishes in a
/// release build and the app is killed while the PDF is still growing.
List<_Bit> _talkPieces(
  ChatMessage message,
  pw.Font font,
  bool hi,
  _PdfPhoto? photo,
) {
  final mine = message.role == MessageRole.user;
  var body = message.text.trim();
  if (body.isEmpty && photo == null && message.hasMedia) {
    body = hi ? 'फोटो' : 'Photo';
  }
  final accent = mine ? _brand : const PdfColor(0.04, 0.42, 0.28);
  final label = mine ? (hi ? 'सवाल' : 'Question') : (hi ? 'जवाब' : 'Answer');
  final pieces = <_Bit>[
    _Bit(
      _piece(
        mine,
        pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: mine
              ? const PdfColor(0.90, 0.96, 1)
              : const PdfColor(0.90, 0.97, 0.93),
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 10, color: accent),
        ),
        ),
      ),
      36,
    ),
  ];
  if (photo != null) {
    var photoW = photo.width;
    var photoH = photo.height;
    final cap = mine ? 300.0 : 460.0;
    if (photoW > cap) {
      photoH = photoH * cap / photoW;
      photoW = cap;
    }
    pieces.add(
      _Bit(
        _piece(
          mine,
          pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.96, 0.98, 1),
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: _brand, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(
                  photo.image,
                  width: photoW,
                  height: photoH,
                  fit: pw.BoxFit.cover,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                hi ? 'फसल की फोटो' : 'Crop photo',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          ),
        ),
        photoH + 48,
      ),
    );
  }
  if (body.isNotEmpty) {
    pieces.addAll(_pdfBlocks(body, font, mine));
  }
  pieces.add(_Bit(pw.SizedBox(height: 8), 8));
  return pieces;
}

pw.Widget _piece(bool mine, pw.Widget child) {
  final boxed = pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: child,
  );
  if (!mine) return boxed;
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(width: 380, child: boxed),
  );
}

List<_Bit> _pdfBlocks(String raw, pw.Font font, bool mine) {
  final split = splitUseCaption(raw);
  final blocks = parseChatAnswer(split.body);
  final out = <_Bit>[];
  void addText(String text, pw.TextStyle style, {String prefix = ''}) {
    final size = style.fontSize ?? 12;
    for (final part in _pageChunks(text)) {
      final shown = prefix.isEmpty ? part : '$prefix$part';
      out.add(
        _Bit(
          _piece(
            mine,
            pw.Text(shown, style: style),
          ),
          _textHeight(shown, size),
        ),
      );
    }
  }

  if (blocks.isEmpty) {
    addText(
      _plain(split.body.isEmpty ? raw : split.body),
      pw.TextStyle(font: font, fontSize: 12, lineSpacing: 2),
    );
  }
  for (final block in blocks) {
    switch (block.kind) {
      case ChatAnswerBlockKind.heading:
        addText(
          _plain(block.text),
          pw.TextStyle(font: font, fontSize: 14, color: _brand),
        );
      case ChatAnswerBlockKind.bullet:
      case ChatAnswerBlockKind.numbered:
        addText(
          _plain(block.text),
          pw.TextStyle(font: font, fontSize: 15, lineSpacing: 2),
          prefix: '• ',
        );
      case ChatAnswerBlockKind.paragraph:
        addText(
          _plain(block.text),
          pw.TextStyle(font: font, fontSize: 12, lineSpacing: 2),
        );
    }
  }
  if (split.caption != null) {
    addText(
      split.caption!,
      pw.TextStyle(
        font: font,
        fontSize: 11,
        color: const PdfColor(0.35, 0.24, 0),
      ),
    );
  }
  return out;
}

double _textHeight(String text, double fontSize) {
  const charsPerLine = 42;
  final lines = (text.length / charsPerLine).ceil().clamp(1, 30);
  return lines * (fontSize + 4) + 16;
}

/// Short enough to fit one page. A block taller than the page never
/// finishes in a release build, and the app is killed.
List<String> _pageChunks(String text) {
  const size = 420;
  final clean = text.trim();
  if (clean.isEmpty) return const [];
  if (clean.length <= size) return [clean];
  final out = <String>[];
  var i = 0;
  while (i < clean.length) {
    var end = i + size;
    if (end >= clean.length) {
      end = clean.length;
    } else {
      final space = clean.lastIndexOf(' ', end);
      if (space > i + 40) end = space;
    }
    final part = clean.substring(i, end).trim();
    if (part.isNotEmpty) out.add(part);
    if (end <= i) end = i + 1;
    i = end;
  }
  return out;
}

String _plain(String raw) {
  return raw
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

pw.Widget _stamp(pw.MemoryImage logo, pw.Font font, bool hi) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.fromLTRB(8, 7, 14, 7),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(18),
      border: pw.Border.all(color: _brand, width: 1.8),
    ),
    child: pw.Row(
      children: [
        pw.Container(
          width: 54,
          height: 54,
          padding: const pw.EdgeInsets.all(3),
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColors.white,
            border: pw.Border.all(color: _brand, width: 1.6),
          ),
          child: pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.cover)),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'AG FARMER',
              style: pw.TextStyle(font: font, fontSize: 16, color: _brand),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              hi ? 'खेती सहायक' : 'Farming assistant',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.90, 0.96, 1),
            borderRadius: pw.BorderRadius.circular(20),
            border: pw.Border.all(color: _brand, width: 0.7),
          ),
          child: pw.Text(
            hi ? 'कृषि AI' : 'Agri AI',
            style: pw.TextStyle(font: font, fontSize: 9, color: _brand),
          ),
        ),
      ],
    ),
  );
}

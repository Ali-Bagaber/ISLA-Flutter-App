import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../screens/documents/annotation/annotation_models.dart';
import '../screens/documents/annotation/annotation_painter.dart';

/// Renders hand-drawn annotations on top of the original PDF and writes a new,
/// flattened PDF file. The original bytes are never modified — the output is a
/// separate `<name>_annotated.pdf` in the app's documents directory.
class PdfExportService {
  /// Exports [strokes] burned onto [originalBytes]. Returns the saved file.
  static Future<File> exportAnnotatedPdf({
    required Uint8List originalBytes,
    required String originalFileName,
    required List<AnnotationStroke> strokes,
  }) async {
    final document = sf.PdfDocument(inputBytes: originalBytes);
    try {
      // Group strokes by page so each page is touched once.
      final byPage = <int, List<AnnotationStroke>>{};
      for (final s in strokes) {
        (byPage[s.page] ??= []).add(s);
      }

      final pageCount = document.pages.count;
      for (final entry in byPage.entries) {
        final pageIndex = entry.key - 1; // strokes use 1-based page numbers
        if (pageIndex < 0 || pageIndex >= pageCount) continue;

        final page = document.pages[pageIndex];
        final size = page.getClientSize();
        final graphics = page.graphics;

        for (final stroke in entry.value) {
          _drawStroke(graphics, stroke, size.width, size.height);
        }
      }

      final outBytes = Uint8List.fromList(await document.save());
      final file = await _outputFile(originalFileName);
      await file.writeAsBytes(outBytes, flush: true);
      return file;
    } finally {
      document.dispose();
    }
  }

  static void _drawStroke(
    sf.PdfGraphics graphics,
    AnnotationStroke stroke,
    double pageWidth,
    double pageHeight,
  ) {
    if (stroke.points.isEmpty) return;

    final color = stroke.color;
    final width = stroke.isHighlighter
        ? stroke.width * kHighlighterWidthFactor
        : stroke.width;

    final pen = sf.PdfPen(
      sf.PdfColor(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
      ),
      width: width,
      lineCap: sf.PdfLineCap.round,
      lineJoin: sf.PdfLineJoin.round,
    );

    // De-normalize points into PDF page coordinates (top-left origin, points).
    final pts = stroke.points
        .map((n) => Offset(n.dx * pageWidth, n.dy * pageHeight))
        .toList();

    // Highlighter draws transparently so underlying text stays readable.
    final state = graphics.save();
    if (stroke.isHighlighter) {
      graphics.setTransparency(kHighlighterAlpha);
    }

    if (pts.length == 1) {
      final r = width / 2;
      graphics.drawEllipse(
        Rect.fromCircle(center: pts.first, radius: r),
        pen: pen,
      );
    } else {
      for (var i = 0; i < pts.length - 1; i++) {
        graphics.drawLine(pen, pts[i], pts[i + 1]);
      }
    }

    graphics.restore(state);
  }

  static Future<File> _outputFile(String originalFileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final base = originalFileName
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '_')
        .trim();
    final safeBase = base.isEmpty ? 'document' : base;
    return File('${dir.path}/${safeBase}_annotated.pdf');
  }
}

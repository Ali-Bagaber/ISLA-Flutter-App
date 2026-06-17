import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'annotation_models.dart';

/// Highlighter ink is drawn semi-transparent and a bit wider than its nominal
/// width so it reads like a marker laid over the text.
const double kHighlighterAlpha = 0.32;
const double kHighlighterWidthFactor = 4.0;

/// Builds a smooth (quadratic-bezier) path through [pts].
Path buildSmoothPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length < 3) {
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset(
      (pts[i].dx + pts[i + 1].dx) / 2,
      (pts[i].dy + pts[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

Paint strokePaint(Color color, double width, {required bool highlighter}) {
  final paint = Paint()
    ..color = highlighter ? color.withValues(alpha: kHighlighterAlpha) : color
    ..strokeWidth = highlighter ? width * kHighlighterWidthFactor : width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true; // anti-aliasing for crisp ink
  return paint;
}

/// Paints one committed [stroke] onto [canvas] within [pageRect].
///
/// [pageWidthPts] is the page width in PDF points; the stroke width (also in
/// points) is scaled to pixels by the current page rectangle. This is called
/// from pdfrx's `pagePaintCallbacks`, so it automatically follows scroll/zoom.
void paintStrokeOnPage(
  Canvas canvas,
  AnnotationStroke stroke,
  Rect pageRect,
  double pageWidthPts,
) {
  if (stroke.points.isEmpty) return;

  final scale = pageWidthPts > 0 ? pageRect.width / pageWidthPts : 1.0;
  final pixelWidth = (stroke.width * scale).clamp(0.5, 200.0);

  // Map normalized (0–1, top-left) points into the page rectangle.
  final pts = stroke.points
      .map((n) => Offset(
            pageRect.left + n.dx * pageRect.width,
            pageRect.top + n.dy * pageRect.height,
          ))
      .toList();

  final paint =
      strokePaint(stroke.color, pixelWidth, highlighter: stroke.isHighlighter);

  if (pts.length == 1) {
    canvas.drawCircle(
      pts.first,
      paint.strokeWidth / 2,
      Paint()
        ..color = paint.color
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );
    return;
  }
  canvas.drawPath(buildSmoothPath(pts), paint);
}

/// Lightweight overlay that paints ONLY the in-progress stroke using raw screen
/// points. Repaints cheaply on every move (driven by a [ValueListenable]) so
/// drawing stays smooth without rebuilding the heavy PDF viewer underneath.
class LiveStrokePainter extends CustomPainter {
  final ValueListenable<List<Offset>> points;
  final Color color;
  final double pixelWidth;
  final bool highlighter;

  LiveStrokePainter({
    required this.points,
    required this.color,
    required this.pixelWidth,
    required this.highlighter,
  }) : super(repaint: points);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = points.value;
    if (pts.isEmpty) return;
    final paint = strokePaint(color, pixelWidth, highlighter: highlighter);
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.first,
        paint.strokeWidth / 2,
        Paint()
          ..color = paint.color
          ..isAntiAlias = true
          ..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(buildSmoothPath(pts), paint);
  }

  @override
  bool shouldRepaint(LiveStrokePainter old) =>
      old.color != color ||
      old.pixelWidth != pixelWidth ||
      old.highlighter != highlighter;
}

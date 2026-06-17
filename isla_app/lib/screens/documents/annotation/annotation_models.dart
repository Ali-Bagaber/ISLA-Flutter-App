import 'dart:ui';

/// Drawing tools available in the PDF annotation board.
enum AnnotationTool { pen, highlighter, eraser }

/// A single hand-drawn stroke on one PDF page.
///
/// Points are stored **normalized** (0.0–1.0) relative to the page rectangle,
/// with a top-left origin. Because they are page-relative, the stroke stays
/// perfectly aligned with the PDF after scrolling, zooming, resizing or
/// rotating — only the page rectangle changes, never the stored data.
///
/// [width] is expressed in **PDF points** (the page's own coordinate units at
/// 72 dpi). On screen it is scaled by `pageRect.width / page.width`; on export
/// it is used directly. This keeps ink thickness consistent everywhere.
class AnnotationStroke {
  /// 1-based PDF page number this stroke belongs to.
  final int page;

  /// ARGB color value (highlighter alpha is applied at paint time).
  final int colorValue;

  /// Stroke width in PDF points.
  final double width;

  final AnnotationTool tool;

  /// Normalized points (0–1, top-left origin), in draw order.
  final List<Offset> points;

  const AnnotationStroke({
    required this.page,
    required this.colorValue,
    required this.width,
    required this.tool,
    required this.points,
  });

  Color get color => Color(colorValue);

  bool get isHighlighter => tool == AnnotationTool.highlighter;

  AnnotationStroke copyWith({List<Offset>? points}) => AnnotationStroke(
        page: page,
        colorValue: colorValue,
        width: width,
        tool: tool,
        points: points ?? this.points,
      );

  Map<String, dynamic> toJson() {
    final flat = <double>[];
    for (final p in points) {
      flat
        ..add(p.dx)
        ..add(p.dy);
    }
    return {
      'v': 2, // schema version — normalized coordinates
      'page': page,
      'color': colorValue,
      'width': width,
      'tool': tool.index,
      'points': flat,
    };
  }

  factory AnnotationStroke.fromJson(Map<String, dynamic> j) {
    final flat = (j['points'] as List? ?? []).cast<num>();
    final pts = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    final toolIdx = (j['tool'] as num?)?.toInt() ?? 0;
    return AnnotationStroke(
      page: (j['page'] as num?)?.toInt() ?? 1,
      colorValue: (j['color'] as num?)?.toInt() ?? 0xFF000000,
      width: (j['width'] as num?)?.toDouble() ?? 3.0,
      tool: toolIdx >= 0 && toolIdx < AnnotationTool.values.length
          ? AnnotationTool.values[toolIdx]
          : AnnotationTool.pen,
      points: pts,
    );
  }
}

/// One undoable change on a page: either strokes added, or strokes erased.
/// Inverting an op restores the previous state, which powers undo/redo.
class PageOp {
  final bool isErase;
  final List<AnnotationStroke> strokes;

  const PageOp({required this.isErase, required this.strokes});

  PageOp get inverted => PageOp(isErase: !isErase, strokes: strokes);
}

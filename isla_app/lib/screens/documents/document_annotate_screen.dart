// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class DocumentAnnotateScreen extends StatefulWidget {
  final String documentTitle;
  final String? downloadUrl;
  final String? fileType;

  const DocumentAnnotateScreen({
    super.key,
    required this.documentTitle,
    this.downloadUrl,
    this.fileType,
  });

  @override
  State<DocumentAnnotateScreen> createState() => _DocumentAnnotateScreenState();
}

class _DocumentAnnotateScreenState extends State<DocumentAnnotateScreen> {
  final List<_Stroke> _strokes = [];
  List<Offset> _currentPoints = [];

  Color _penColor = Colors.black;
  double _penWidth = 3.0;
  bool _eraserMode = false;

  late final String _viewType;
  bool _viewRegistered = false;

  static const _drawColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];
  static const _widths = [2.0, 4.0, 8.0];

  @override
  void initState() {
    super.initState();
    final url = widget.downloadUrl;
    final src = (url != null && url.isNotEmpty)
        ? _iframeSrc(url, widget.fileType ?? 'PDF')
        : '';
    if (src.isNotEmpty) {
      _viewType =
          'doc-viewer-${identityHashCode(this)}-${DateTime.now().millisecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int id) => html.IFrameElement()
          ..src = src
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true,
      );
      _viewRegistered = true;
    } else {
      _viewType = '';
    }
  }

  String _iframeSrc(String url, String type) {
    final t = type.toUpperCase();
    if (t == 'PDF') return url;
    // PPTX / DOCX — use Google Docs viewer (supports iframe embedding from
    // external origins, works with Firebase Storage download URLs)
    if (t == 'PPTX' || t == 'DOCX') {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    }
    return '';
  }

  void _onPointerDown(PointerDownEvent e) {
    setState(() => _currentPoints = [e.localPosition]);
  }

  void _onPointerMove(PointerMoveEvent e) {
    setState(() => _currentPoints = [..._currentPoints, e.localPosition]);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_currentPoints.isNotEmpty) {
      setState(() {
        _strokes.add(_Stroke(
          points: List.from(_currentPoints),
          color: _eraserMode ? Colors.white : _penColor,
          width: _eraserMode ? 20.0 : _penWidth,
        ));
        _currentPoints = [];
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentPoints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.documentTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _strokes.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear all',
            onPressed: (_strokes.isNotEmpty || _currentPoints.isNotEmpty)
                ? _clear
                : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Toolbar ──
          Container(
            height: 58,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // Color dots
                ..._drawColors.map((c) => GestureDetector(
                      onTap: () => setState(() {
                        _penColor = c;
                        _eraserMode = false;
                      }),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (!_eraserMode && _penColor == c)
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300,
                            width: (!_eraserMode && _penColor == c) ? 3 : 1,
                          ),
                        ),
                      ),
                    )),
                // Divider
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey.shade300,
                ),
                // Stroke sizes
                ..._widths.map((w) {
                  final sel = !_eraserMode && _penWidth == w;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _penWidth = w;
                      _eraserMode = false;
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: sel
                            ? AppTheme.primaryColor.withOpacity(0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: sel
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: w * 2.5,
                          height: w * 2.5,
                          decoration: BoxDecoration(
                            color: _penColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Eraser toggle
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey.shade300,
                ),
                GestureDetector(
                  onTap: () => setState(() => _eraserMode = !_eraserMode),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: _eraserMode
                          ? AppTheme.primaryColor.withOpacity(0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: _eraserMode
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_fix_normal_rounded,
                      size: 18,
                      color: _eraserMode
                          ? AppTheme.primaryColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_strokes.length} stroke${_strokes.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Canvas ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background: document iframe or plain white
                    if (_viewRegistered)
                      HtmlElementView(viewType: _viewType)
                    else
                      const ColoredBox(color: Colors.white),

                    // Drawing layer — Listener for reliable web pointer events
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      child: CustomPaint(
                        foregroundPainter: _AnnotationPainter(
                          strokes: _strokes,
                          currentPoints: _currentPoints,
                          currentColor: _eraserMode ? Colors.white : _penColor,
                          currentWidth: _eraserMode ? 20.0 : _penWidth,
                        ),
                        child: SizedBox.expand(
                          child: !_viewRegistered &&
                                  _strokes.isEmpty &&
                                  _currentPoints.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.draw_rounded,
                                          size: 56,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Draw freely with your pen',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  const _AnnotationPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth);
    }
  }

  void _drawStroke(
      Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) =>
      old.strokes != strokes ||
      old.currentPoints != currentPoints ||
      old.currentColor != currentColor ||
      old.currentWidth != currentWidth;
}

import 'package:flutter/material.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';

// Platform-conditional iframe viewer: stub on mobile/desktop, real iframe on web.
import '_document_iframe_stub.dart'
    if (dart.library.html) '_document_iframe_web.dart';

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final int page;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
    required this.page,
  });

  /// Firestore-safe shape. Points are flattened into a single list of doubles
  /// `[x1, y1, x2, y2, ...]` because Firestore does not allow nested arrays.
  Map<String, dynamic> toJson() {
    final flat = <double>[];
    for (final p in points) {
      flat
        ..add(p.dx)
        ..add(p.dy);
    }
    return {
      'color': color.toARGB32(),
      'width': width,
      'page': page,
      'points': flat,
    };
  }

  factory _Stroke.fromJson(Map<String, dynamic> j) {
    final flat = (j['points'] as List? ?? []).cast<num>();
    final pts = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    return _Stroke(
      points: pts,
      color: Color((j['color'] as num?)?.toInt() ?? 0xFF000000),
      width: (j['width'] as num?)?.toDouble() ?? 3.0,
      page: (j['page'] as num?)?.toInt() ?? 1,
    );
  }
}

class DocumentAnnotateScreen extends StatefulWidget {
  final String documentTitle;
  final String? documentId;
  final String? downloadUrl;
  final String? fileType;

  const DocumentAnnotateScreen({
    super.key,
    required this.documentTitle,
    this.documentId,
    this.downloadUrl,
    this.fileType,
  });

  @override
  State<DocumentAnnotateScreen> createState() => _DocumentAnnotateScreenState();
}

class _DocumentAnnotateScreenState extends State<DocumentAnnotateScreen> {
  List<_Stroke> _strokes = [];
  List<Offset> _currentPoints = [];
  bool _loadingAnnotations = false;
  bool _saving = false;
  bool _dirty = false;

  Color _penColor = Colors.black;
  double _penWidth = 3.0;
  bool _eraserMode = false;
  bool _drawMode = true;

  /// 1-indexed page of the document the user is currently annotating.
  /// Strokes are tagged with this and filtered for display, so strokes
  /// drawn on page 3 don't show up when you scroll to page 5.
  int _currentPage = 1;
  late final TextEditingController _pageCtrl;

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
    _pageCtrl = TextEditingController(text: '$_currentPage');
    _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    final docId = widget.documentId;
    if (docId == null || docId.isEmpty) return;
    setState(() => _loadingAnnotations = true);
    try {
      final raw = await DocumentService.loadAnnotations(docId);
      if (!mounted) return;
      setState(() {
        _strokes = raw.map(_Stroke.fromJson).toList();
        _loadingAnnotations = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAnnotations = false);
    }
  }

  Future<void> _saveAnnotations() async {
    final docId = widget.documentId;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save — no document id.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await DocumentService.saveAnnotations(
        documentId: docId,
        strokes: _strokes.map((s) => s.toJson()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Saved ${_strokes.length} stroke${_strokes.length == 1 ? '' : 's'}.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _toggleDrawMode() {
    setState(() => _drawMode = !_drawMode);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!_drawMode) return;
    setState(() => _currentPoints = [e.localPosition]);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_drawMode) return;
    setState(() => _currentPoints = [..._currentPoints, e.localPosition]);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_drawMode) return;
    if (_currentPoints.isNotEmpty) {
      setState(() {
        _strokes.add(_Stroke(
          points: List.from(_currentPoints),
          color: _eraserMode ? Colors.white : _penColor,
          width: _eraserMode ? 20.0 : _penWidth,
          page: _currentPage,
        ));
        _currentPoints = [];
        _dirty = true;
      });
    }
  }

  /// Strokes that belong to the page currently being viewed.
  List<_Stroke> get _strokesOnCurrentPage =>
      _strokes.where((s) => s.page == _currentPage).toList();

  void _undo() {
    final lastIdx = _strokes.lastIndexWhere((s) => s.page == _currentPage);
    if (lastIdx >= 0) {
      setState(() {
        _strokes.removeAt(lastIdx);
        _dirty = true;
      });
    }
  }

  void _clear() {
    setState(() {
      _strokes.removeWhere((s) => s.page == _currentPage);
      _currentPoints = [];
      _dirty = true;
    });
  }

  void _setPage(int page) {
    if (page < 1) page = 1;
    if (page == _currentPage) return;
    setState(() {
      _currentPage = page;
      _currentPoints = [];
      _pageCtrl.text = '$page';
    });
  }

  Future<bool> _confirmExitIfDirty() async {
    if (!_dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved annotations'),
        content: const Text('You have unsaved changes. Save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _saveAnnotations();
      return !_dirty;
    }
    return result == 'discard';
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.downloadUrl;
    final hasViewer = url != null && url.isNotEmpty;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExitIfDirty();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(
                child: Text(widget.documentTitle,
                    overflow: TextOverflow.ellipsis),
              ),
              if (_dirty) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // Draw / View toggle — switches whether the iframe swallows pointer events.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: ToggleButtons(
                isSelected: [_drawMode, !_drawMode],
                onPressed: (i) {
                  final shouldDraw = i == 0;
                  if (shouldDraw != _drawMode) _toggleDrawMode();
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 56),
                selectedColor: Colors.white,
                fillColor: AppTheme.primaryColor,
                color: Colors.white70,
                children: const [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Draw', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pan_tool_alt_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('View', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: _strokesOnCurrentPage.isNotEmpty ? _undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear all',
              onPressed: (_strokesOnCurrentPage.isNotEmpty ||
                      _currentPoints.isNotEmpty)
                  ? _clear
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveAnnotations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving' : 'Save'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildToolbar(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasViewer)
                        DocumentIframeView(
                          url: url,
                          type: widget.fileType ?? 'PDF',
                          drawMode: _drawMode,
                        )
                      else
                        const ColoredBox(color: Colors.white),
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        child: CustomPaint(
                          foregroundPainter: _AnnotationPainter(
                            strokes: _strokesOnCurrentPage,
                            currentPoints: _currentPoints,
                            currentColor:
                                _eraserMode ? Colors.white : _penColor,
                            currentWidth: _eraserMode ? 20.0 : _penWidth,
                          ),
                          child: SizedBox.expand(
                            child: !hasViewer &&
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
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 58,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
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
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade300,
          ),
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
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: sel ? AppTheme.primaryColor : Colors.grey.shade300,
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
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
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
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade300,
          ),
          Row(
            children: [
              Text('Page',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              const SizedBox(width: 4),
              _PageStepperButton(
                icon: Icons.remove_rounded,
                onTap: () => _setPage(_currentPage - 1),
              ),
              SizedBox(
                width: 38,
                height: 30,
                child: TextField(
                  controller: _pageCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (v) {
                    final n = int.tryParse(v.trim());
                    if (n != null) _setPage(n);
                  },
                ),
              ),
              _PageStepperButton(
                icon: Icons.add_rounded,
                onTap: () => _setPage(_currentPage + 1),
              ),
            ],
          ),
          const Spacer(),
          if (_loadingAnnotations)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Text(
            'Page $_currentPage · ${_strokesOnCurrentPage.length} stroke${_strokesOnCurrentPage.length == 1 ? '' : 's'} (total ${_strokes.length})',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
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

class _PageStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PageStepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 14, color: Colors.grey.shade700),
      ),
    );
  }
}

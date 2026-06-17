import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/document_service.dart';
import '../../services/pdf_export_service.dart';
import 'annotation/annotation_models.dart';
import 'annotation/annotation_painter.dart';
import 'annotation/annotation_toolbar.dart';

/// Professional, Drawboard-style PDF annotation board.
///
/// Architecture (per-page overlay):
/// - Each PDF page gets its own annotation canvas via pdfrx's
///   [PdfViewerParams.pageOverlaysBuilder]. Widgets live in a Stack that is
///   sized exactly to each page and scrolls naturally with it — no global
///   coordinate mapping required.
/// - Committed strokes are stored as [Map<int, List<AnnotationStroke>>] (page →
///   strokes). The per-page [_PageAnnotationPainter] reads only its own page's
///   list and repaints when [_strokesTick] is bumped.
/// - In-progress ink is driven by [_liveNotifier] ([ValueNotifier<_LiveStrokeData?>]).
///   Each [_PageLivePainter] filters to its own page so only the active page
///   repaints on every pointer move.
/// - Touch coordinates from the per-page [GestureDetector] are already
///   page-local (0,0 … pageRect.width × pageRect.height), so normalising is a
///   simple division — no hit-testing or global rect lookup needed.
class PdfAnnotationScreen extends StatefulWidget {
  final String documentTitle;
  final String? documentId;
  final String? downloadUrl;
  final String? storagePath;
  final String? localPath;
  final String? fileName;
  final String? fileType;

  const PdfAnnotationScreen({
    super.key,
    required this.documentTitle,
    this.documentId,
    this.downloadUrl,
    this.storagePath,
    this.localPath,
    this.fileName,
    this.fileType,
  });

  @override
  State<PdfAnnotationScreen> createState() => _PdfAnnotationScreenState();
}

class _PdfAnnotationScreenState extends State<PdfAnnotationScreen> {
  final PdfViewerController _controller = PdfViewerController();

  // ── PDF load state ──────────────────────────────────────────────────────
  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _loadError;

  // ── Annotation state ────────────────────────────────────────────────────
  /// Strokes keyed by 1-based page number.
  final Map<int, List<AnnotationStroke>> _strokesByPage = {};
  final Map<int, List<PageOp>> _undo = {};
  final Map<int, List<PageOp>> _redo = {};

  // ── Tool state ──────────────────────────────────────────────────────────
  AnnotationTool _tool = AnnotationTool.pen;
  int _colorValue = AnnotationStyle.penColors.first.toARGB32();
  double _penWidth = AnnotationStyle.penWidths[1];
  bool _drawMode = true;

  int _activePage = 1;
  int? _totalPages;
  bool _saving = false;
  bool _dirty = false;

  bool _pdfReady = false;
  bool _pdfRenderError = false;
  int _reloadToken = 0;

  // ── In-progress (live) stroke ────────────────────────────────────────────
  /// Notifies per-page live painters. Holds the active page number and its
  /// current in-progress points in page-local pixel coordinates.
  final ValueNotifier<_LiveStrokeData?> _liveNotifier = ValueNotifier(null);

  /// Raw page-local pixel points accumulated during an active pan gesture.
  List<Offset> _liveScreenPts = [];

  /// Page number of the currently active draw gesture.
  int? _activeDrawPage;

  /// Last tap position, for committing single-tap dots.
  ({int pageNo, Offset pos})? _lastTapDown;

  /// Bumped whenever committed strokes change; triggers per-page painter repaint.
  final ValueNotifier<int> _strokesTick = ValueNotifier(0);

  void _bumpStrokes() => _strokesTick.value++;

  bool get _isPdf => (widget.fileType ?? 'PDF').toUpperCase() == 'PDF';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _loadAnnotations();
    if (_isPdf) {
      _loadPdf();
    } else {
      _loading = false;
      _loadError = 'Annotation is available for PDF files only.';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _liveNotifier.dispose();
    _strokesTick.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_controller.isReady) return;
    final p = _controller.pageNumber;
    if (p != null && p != _activePage) {
      setState(() => _activePage = p);
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final bytes = await _fetchBytes();
      if (kDebugMode) {
        final header = (bytes != null && bytes.length >= 5)
            ? String.fromCharCodes(bytes.take(5))
            : '<none>';
        debugPrint('PDF DIAG ── doc="${widget.documentTitle}" '
            'id=${widget.documentId} type=${widget.fileType}');
        debugPrint('PDF DIAG ── storagePath=${widget.storagePath}');
        debugPrint('PDF DIAG ── localPath=${widget.localPath}');
        debugPrint('PDF DIAG ── downloadUrl=${widget.downloadUrl}');
        debugPrint('PDF DIAG ── bytes=${bytes?.length ?? 0} '
            'header="$header" looksLikePdf=${bytes != null && _looksLikePdf(bytes)}');
      }
      if (bytes == null || bytes.isEmpty) {
        throw 'The PDF file is empty or could not be read.';
      }
      if (!_looksLikePdf(bytes)) {
        throw 'This file does not appear to be a valid PDF.';
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('PDF DIAG ── byte fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  bool _looksLikePdf(Uint8List b) {
    if (b.length < 5) return false;
    return b[0] == 0x25 &&
        b[1] == 0x50 &&
        b[2] == 0x44 &&
        b[3] == 0x46 &&
        b[4] == 0x2D;
  }

  Future<Uint8List?> _fetchBytes() async {
    final local = widget.localPath;
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      if (kDebugMode) {
        debugPrint('PDF DIAG ── local file "$local" exists=$exists size=$size');
      }
      if (exists && size > 0) return f.readAsBytes();
    }

    final path = widget.storagePath;
    if (path != null && path.isNotEmpty && Firebase.apps.isNotEmpty) {
      try {
        final data =
            await FirebaseStorage.instance.ref(path).getData(64 * 1024 * 1024);
        if (kDebugMode) {
          debugPrint('PDF DIAG ── source=Storage bytes=${data?.length ?? 0}');
        }
        if (data != null && data.isNotEmpty) return data;
      } catch (e) {
        if (kDebugMode) debugPrint('PDF DIAG ── Storage fetch failed: $e');
      }
    }

    final url = widget.downloadUrl;
    if (url != null && url.startsWith('http')) {
      try {
        final res = await Dio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = res.data;
        if (kDebugMode) {
          debugPrint('PDF DIAG ── source=HTTP bytes=${data?.length ?? 0}');
        }
        if (data != null) return Uint8List.fromList(data);
      } catch (e) {
        if (kDebugMode) debugPrint('PDF DIAG ── HTTP fetch failed: $e');
      }
    }
    return null;
  }

  Future<void> _loadAnnotations() async {
    final docId = widget.documentId;
    if (docId == null || docId.isEmpty) return;
    try {
      final raw = await DocumentService.loadAnnotations(docId);
      if (!mounted) return;
      setState(() {
        _strokesByPage.clear();
        for (final s in raw.map(AnnotationStroke.fromJson)) {
          (_strokesByPage[s.page] ??= []).add(s);
        }
      });
      _bumpStrokes();
    } catch (_) {
      // Non-fatal — start with a clean canvas.
    }
  }

  // ── Per-page drawing gestures ─────────────────────────────────────────────
  // localPosition is already in page-local pixel coordinates (0,0 at page
  // top-left), so normalising is just a division by pageRect dimensions.

  void _onPagePanStart(DragStartDetails d, int pageNo, Rect pageRect) {
    _activeDrawPage = pageNo;
    if (kDebugMode) debugPrint('DRAW ── panStart page=$pageNo tool=$_tool');
    if (_tool == AnnotationTool.eraser) {
      _eraseAtLocal(d.localPosition, pageNo, pageRect);
      return;
    }
    _liveScreenPts = [d.localPosition];
    _liveNotifier.value = _LiveStrokeData(pageNo, List.of(_liveScreenPts));
  }

  void _onPagePanUpdate(DragUpdateDetails d, int pageNo, Rect pageRect) {
    if (_activeDrawPage != pageNo) return;
    if (_tool == AnnotationTool.eraser) {
      _eraseAtLocal(d.localPosition, pageNo, pageRect);
      return;
    }
    _liveScreenPts.add(d.localPosition);
    _liveNotifier.value = _LiveStrokeData(pageNo, List.of(_liveScreenPts));
    if (kDebugMode && _liveScreenPts.length % 8 == 0) {
      debugPrint('DRAW ── drawing… points=${_liveScreenPts.length}');
    }
  }

  void _onPagePanEnd(DragEndDetails _, int pageNo, Rect pageRect) {
    if (_activeDrawPage == pageNo &&
        _tool != AnnotationTool.eraser &&
        _liveScreenPts.isNotEmpty) {
      final norm = _liveScreenPts
          .map((s) => Offset(
                (s.dx / pageRect.width).clamp(0.0, 1.0),
                (s.dy / pageRect.height).clamp(0.0, 1.0),
              ))
          .toList();
      _commitStroke(pageNo, norm);
    }
    _liveScreenPts = [];
    _liveNotifier.value = null;
    _activeDrawPage = null;
  }

  void _commitStroke(int page, List<Offset> normPoints) {
    if (normPoints.isEmpty) return;
    final stroke = AnnotationStroke(
      page: page,
      colorValue: _colorValue,
      width: _penWidth,
      tool: _tool,
      points: normPoints,
    );
    setState(() {
      (_strokesByPage[page] ??= []).add(stroke);
      _pushUndo(page, PageOp(isErase: false, strokes: [stroke]));
      _redo[page]?.clear();
      _dirty = true;
    });
    _bumpStrokes();
    if (kDebugMode) {
      debugPrint('DRAW ── SAVED stroke: page=$page '
          'pointsInStroke=${normPoints.length} '
          'strokesOnPage=${_strokesByPage[page]?.length ?? 0}');
    }
  }

  void _eraseAtLocal(Offset local, int pageNo, Rect pageRect) {
    final list = _strokesByPage[pageNo];
    if (list == null || list.isEmpty) return;
    final thresholdPx = 16.0 + _penWidth * 2;
    final removed = <AnnotationStroke>[];
    list.removeWhere((s) {
      final near = s.points.any((p) {
        final px = p.dx * pageRect.width;
        final py = p.dy * pageRect.height;
        return (Offset(px, py) - local).distance <= thresholdPx;
      });
      if (near) removed.add(s);
      return near;
    });
    if (removed.isNotEmpty) {
      setState(() {
        _pushUndo(pageNo, PageOp(isErase: true, strokes: removed));
        _redo[pageNo]?.clear();
        _dirty = true;
      });
      _bumpStrokes();
    }
  }

  // ── Undo / redo (per page) ──────────────────────────────────────────────────

  void _pushUndo(int page, PageOp op) => (_undo[page] ??= []).add(op);

  bool get _canUndo => (_undo[_activePage]?.isNotEmpty ?? false);
  bool get _canRedo => (_redo[_activePage]?.isNotEmpty ?? false);
  bool get _canClear => (_strokesByPage[_activePage]?.isNotEmpty ?? false);

  void _applyForward(int page, PageOp op) {
    if (op.isErase) {
      _strokesByPage[page]?.removeWhere((s) => op.strokes.contains(s));
    } else {
      (_strokesByPage[page] ??= []).addAll(op.strokes);
    }
  }

  void _applyInverse(int page, PageOp op) {
    if (op.isErase) {
      (_strokesByPage[page] ??= []).addAll(op.strokes);
    } else {
      _strokesByPage[page]?.removeWhere((s) => op.strokes.contains(s));
    }
  }

  void _undoAction() {
    final page = _activePage;
    final stack = _undo[page];
    if (stack == null || stack.isEmpty) return;
    final op = stack.removeLast();
    setState(() {
      _applyInverse(page, op);
      (_redo[page] ??= []).add(op);
      _dirty = true;
    });
    _bumpStrokes();
  }

  void _redoAction() {
    final page = _activePage;
    final stack = _redo[page];
    if (stack == null || stack.isEmpty) return;
    final op = stack.removeLast();
    setState(() {
      _applyForward(page, op);
      (_undo[page] ??= []).add(op);
      _dirty = true;
    });
    _bumpStrokes();
  }

  void _clearPage() {
    final page = _activePage;
    final onPage = List<AnnotationStroke>.from(_strokesByPage[page] ?? []);
    if (onPage.isEmpty) return;
    setState(() {
      _strokesByPage[page] = [];
      _pushUndo(page, PageOp(isErase: true, strokes: onPage));
      _redo[page]?.clear();
      _dirty = true;
    });
    _bumpStrokes();
  }

  Future<void> _clearAll() async {
    final hasAny =
        _strokesByPage.values.any((l) => l.isNotEmpty);
    if (!hasAny) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AnnotationStyle.bar,
        title: const Text('Clear all annotations?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This removes every drawing on all pages. You can still undo it per page.',
          style: TextStyle(color: AnnotationStyle.icon),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4D)),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _strokesByPage.forEach((page, list) {
        if (list.isNotEmpty) {
          _pushUndo(page, PageOp(isErase: true, strokes: List.of(list)));
          _redo[page]?.clear();
        }
      });
      _strokesByPage.clear();
      _dirty = true;
    });
    _bumpStrokes();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final docId = widget.documentId;
    setState(() => _saving = true);
    try {
      final allStrokes =
          _strokesByPage.values.expand((l) => l).toList();

      if (docId != null && docId.isNotEmpty) {
        await DocumentService.saveAnnotations(
          documentId: docId,
          strokes: allStrokes.map((s) => s.toJson()).toList(),
        );
      }

      String? exportedPath;
      if (_pdfBytes != null && allStrokes.isNotEmpty) {
        final file = await PdfExportService.exportAnnotatedPdf(
          originalBytes: _pdfBytes!,
          originalFileName: widget.fileName ?? '${widget.documentTitle}.pdf',
          strokes: allStrokes,
        );
        exportedPath = file.path;

        if (docId != null && docId.isNotEmpty && Firebase.apps.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('documents')
                .doc(docId)
                .set({
              'annotatedFilePath': exportedPath,
              'annotatedUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B4332),
          content: Text(
            exportedPath != null
                ? 'Saved. Annotated PDF exported.'
                : 'Annotations saved.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF5B1A1A),
          content: Text('Save failed: $e',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<bool> _confirmExitIfDirty() async {
    if (!_dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AnnotationStyle.bar,
        title: const Text('Unsaved annotations',
            style: TextStyle(color: Colors.white)),
        content: const Text('You have unsaved changes. Save before leaving?',
            style: TextStyle(color: AnnotationStyle.icon)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9F0A)),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: TextButton.styleFrom(foregroundColor: AnnotationStyle.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return !_dirty;
    }
    return result == 'discard';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExitIfDirty()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AnnotationStyle.bg,
        body: Column(
          children: [
            AnnotationTopToolbar(
              title: widget.documentTitle,
              drawMode: _drawMode,
              dirty: _dirty,
              saving: _saving,
              canUndo: _canUndo,
              canRedo: _canRedo,
              canClear: _canClear,
              enabled: _pdfReady,
              onRetry:
                  (_loadError != null || _pdfRenderError) ? _retry : null,
              onBack: () => Navigator.of(context).maybePop(),
              onModeChanged: (draw) => setState(() => _drawMode = draw),
              onUndo: _undoAction,
              onRedo: _redoAction,
              onClearPage: _clearPage,
              onSave: _save,
            ),
            Expanded(child: _buildViewport()),
            if (_isPdf && _pdfBytes != null && _pdfReady)
              AnnotationToolBar(
                tool: _tool,
                colorValue: _colorValue,
                penWidth: _penWidth,
                onToolChanged: (t) => setState(() => _tool = t),
                onColorChanged: (c) => setState(() {
                  _colorValue = c.toARGB32();
                  if (_tool == AnnotationTool.eraser) {
                    _tool = AnnotationTool.pen;
                  }
                }),
                onWidthChanged: (w) => setState(() => _penWidth = w),
                onClearAll: _clearAll,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewport() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AnnotationStyle.accent),
            SizedBox(height: 16),
            Text('Loading PDF…',
                style: TextStyle(color: AnnotationStyle.icon, fontSize: 13)),
          ],
        ),
      );
    }
    if (_loadError != null || _pdfBytes == null) {
      return _buildErrorState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PdfViewer.data(
          _pdfBytes!,
          key: ValueKey('pdf-$_reloadToken'),
          sourceName: widget.documentTitle,
          controller: _controller,
          params: PdfViewerParams(
            backgroundColor: AnnotationStyle.bg,
            margin: 10,
            minScale: 1.0,
            maxScale: 6.0,
            // Lock pan/zoom while drawing so strokes don't fight scrolling.
            panEnabled: !_drawMode,
            scaleEnabled: !_drawMode,
            onViewerReady: (document, controller) {
              if (!mounted) return;
              setState(() {
                _totalPages = document.pages.length;
                _pdfReady = true;
                _pdfRenderError = false;
              });
            },
            onDocumentChanged: (document) {
              if (mounted && document == null) {
                setState(() => _pdfReady = false);
              }
            },
            onPageChanged: (p) {
              if (p != null && p != _activePage) {
                setState(() => _activePage = p);
              }
            },
            loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
                _buildLoadingBanner(),
            errorBannerBuilder: (context, error, stackTrace, documentRef) {
              if (kDebugMode) {
                debugPrint('pdfrx render error: $error\n$stackTrace');
              }
              if (!_pdfRenderError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _pdfRenderError = true;
                      _pdfReady = false;
                    });
                  }
                });
              }
              return _buildRenderErrorCard();
            },
            // Each page gets its own annotation canvas + gesture detector.
            // Widgets placed here live in a Stack sized to that page and scroll
            // naturally with it — no global coordinate mapping needed.
            pageOverlaysBuilder: (context, pageRect, page) {
              final pageNo = page.pageNumber;
              return [
                // ── Committed strokes ──────────────────────────────────────
                SizedBox.expand(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PageAnnotationPainter(
                        pageNumber: pageNo,
                        strokesByPage: _strokesByPage,
                        pageWidthPts: page.width,
                        repaint: _strokesTick,
                      ),
                    ),
                  ),
                ),
                // ── Live stroke + gesture (draw mode only) ─────────────────
                if (_drawMode)
                  SizedBox.expand(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _lastTapDown = (pageNo: pageNo, pos: d.localPosition),
                      onTap: () {
                        final tap = _lastTapDown;
                        if (tap == null || tap.pageNo != pageNo) return;
                        if (_tool == AnnotationTool.eraser) {
                          _eraseAtLocal(tap.pos, pageNo, pageRect);
                          return;
                        }
                        final nx = (tap.pos.dx / pageRect.width).clamp(0.0, 1.0);
                        final ny = (tap.pos.dy / pageRect.height).clamp(0.0, 1.0);
                        _commitStroke(pageNo, [Offset(nx, ny)]);
                      },
                      onPanStart: (d) => _onPagePanStart(d, pageNo, pageRect),
                      onPanUpdate: (d) => _onPagePanUpdate(d, pageNo, pageRect),
                      onPanEnd: (d) => _onPagePanEnd(d, pageNo, pageRect),
                      child: CustomPaint(
                        painter: _PageLivePainter(
                          pageNumber: pageNo,
                          live: _liveNotifier,
                          color: Color(_colorValue),
                          pixelWidth: _livePixelWidth(pageRect, page),
                          highlighter: _tool == AnnotationTool.highlighter,
                        ),
                      ),
                    ),
                  ),
              ];
            },
          ),
        ),

        // ── Page indicator ─────────────────────────────────────────────────
        if (_pdfReady)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(child: _pageBadge()),
          ),
      ],
    );
  }

  void _retry() {
    setState(() {
      _pdfReady = false;
      _pdfRenderError = false;
      _loadError = null;
      _reloadToken++;
    });
    _loadPdf();
  }

  Widget _buildLoadingBanner() {
    return const ColoredBox(
      color: AnnotationStyle.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AnnotationStyle.accent),
            SizedBox(height: 16),
            Text('Rendering PDF…',
                style: TextStyle(color: AnnotationStyle.icon, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderErrorCard() {
    return ColoredBox(
      color: AnnotationStyle.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded,
                  size: 54, color: AnnotationStyle.iconDim),
              const SizedBox(height: 14),
              const Text(
                'PDF failed to load',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please try again or choose another file.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AnnotationStyle.icon, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnnotationStyle.accent,
                  side: const BorderSide(color: AnnotationStyle.accent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pen width in pixels for the live stroke on a specific page.
  double _livePixelWidth(Rect pageRect, PdfPage page) {
    if (page.width <= 0) return _penWidth * 2;
    final scale = pageRect.width / page.width;
    return (_penWidth * scale).clamp(0.5, 60.0);
  }

  Widget _pageBadge() {
    final total = _totalPages;
    return AnimatedOpacity(
      opacity: _pdfBytes != null ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AnnotationStyle.barBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _drawMode ? Icons.edit_rounded : Icons.pan_tool_alt_rounded,
              size: 13,
              color: AnnotationStyle.accent,
            ),
            const SizedBox(width: 6),
            Text(
              total != null ? 'Page $_activePage of $total' : 'Page $_activePage',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 56, color: AnnotationStyle.iconDim),
            const SizedBox(height: 14),
            Text(
              _isPdf ? "Couldn't load the PDF" : 'Not a PDF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'The file could not be opened.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AnnotationStyle.icon, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_isPdf)
              OutlinedButton.icon(
                onPressed: _loadPdf,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnnotationStyle.accent,
                  side: const BorderSide(color: AnnotationStyle.accent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

/// Carries the in-progress stroke for the live painters.
/// [points] are in page-local pixel coordinates (not normalised).
class _LiveStrokeData {
  final int page;
  final List<Offset> points;
  const _LiveStrokeData(this.page, this.points);
}

// ── Per-page painters ─────────────────────────────────────────────────────────

/// Paints committed strokes for one PDF page.
///
/// The canvas is already sized to the page (0,0 … size.width × size.height),
/// so [paintStrokeOnPage] receives a page-local rect with zero origin.
class _PageAnnotationPainter extends CustomPainter {
  final int pageNumber;
  final Map<int, List<AnnotationStroke>> strokesByPage;
  final double pageWidthPts;

  _PageAnnotationPainter({
    required this.pageNumber,
    required this.strokesByPage,
    required this.pageWidthPts,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final strokes = strokesByPage[pageNumber];
    if (strokes == null || strokes.isEmpty) return;
    final pageRect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (final s in strokes) {
      paintStrokeOnPage(canvas, s, pageRect, pageWidthPts);
    }
  }

  @override
  bool shouldRepaint(_PageAnnotationPainter old) => true;
}

/// Paints the in-progress stroke for one page.
///
/// [live] fires on every pointer move; only the page whose number matches
/// [pageNumber] renders anything — all other pages' painters skip immediately.
class _PageLivePainter extends CustomPainter {
  final int pageNumber;
  final ValueNotifier<_LiveStrokeData?> live;
  final Color color;
  final double pixelWidth;
  final bool highlighter;

  _PageLivePainter({
    required this.pageNumber,
    required this.live,
    required this.color,
    required this.pixelWidth,
    required this.highlighter,
  }) : super(repaint: live);

  @override
  void paint(Canvas canvas, Size size) {
    final data = live.value;
    if (data == null || data.page != pageNumber || data.points.isEmpty) return;
    final paint = strokePaint(color, pixelWidth, highlighter: highlighter);
    final pts = data.points;
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
  bool shouldRepaint(_PageLivePainter old) =>
      pageNumber != old.pageNumber ||
      color != old.color ||
      pixelWidth != old.pixelWidth ||
      highlighter != old.highlighter;
}

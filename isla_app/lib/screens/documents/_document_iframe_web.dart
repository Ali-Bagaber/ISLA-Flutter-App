// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web implementation of the document viewer iframe.
/// Renders a PDF via Chrome's PDF viewer or PPTX/DOCX via Google Docs viewer.
///
/// When [drawMode] is true the iframe's CSS pointer-events is set to none,
/// so the parent annotate screen's drawing layer can capture strokes.
class DocumentIframeView extends StatefulWidget {
  final String url;
  final String type;
  final bool drawMode;

  const DocumentIframeView({
    super.key,
    required this.url,
    required this.type,
    required this.drawMode,
  });

  @override
  State<DocumentIframeView> createState() => _DocumentIframeViewState();
}

class _DocumentIframeViewState extends State<DocumentIframeView> {
  late final String _viewType;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewType =
        'doc-viewer-${identityHashCode(this)}-${DateTime.now().millisecondsSinceEpoch}';
    final src = _iframeSrc(widget.url, widget.type);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = widget.drawMode ? 'none' : 'auto'
        ..allowFullscreen = true;
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(covariant DocumentIframeView old) {
    super.didUpdateWidget(old);
    if (old.drawMode != widget.drawMode) {
      _iframe?.style.pointerEvents = widget.drawMode ? 'none' : 'auto';
    }
  }

  String _iframeSrc(String url, String type) {
    final t = type.toUpperCase();
    if (t == 'PDF') return url;
    if (t == 'PPTX' || t == 'DOCX') {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

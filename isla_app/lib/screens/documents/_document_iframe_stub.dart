import 'package:flutter/material.dart';

/// Non-web placeholder for the document viewer. Lets the rest of the
/// annotate screen compile on Android/iOS/Windows builds.
class DocumentIframeView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const Text(
        'Document viewer is only available on the web build.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Extract plain text from uploaded study documents (PDF / PPTX / DOCX / TXT).
///
/// Used at upload time so the AI services (Summary, Flashcards, Quiz, Checklist)
/// can read the actual file content instead of just the title / notes.
class DocumentTextExtractor {
  /// Returns extracted text, or empty string if extraction is not supported
  /// or fails. Never throws — extraction failure should not block upload.
  static String extract({
    required String fileName,
    required Uint8List bytes,
  }) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    try {
      switch (ext) {
        case 'pdf':
          return _extractPdf(bytes);
        case 'pptx':
          return _extractPptx(bytes);
        case 'docx':
          return _extractDocx(bytes);
        case 'txt':
        case 'md':
          return utf8.decode(bytes, allowMalformed: true).trim();
        default:
          return '';
      }
    } catch (_) {
      // Any extractor error → return empty rather than failing the upload
      return '';
    }
  }

  // ── PDF ────────────────────────────────────────────────────────────────────
  static String _extractPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return _normalize(text);
  }

  // ── PPTX ───────────────────────────────────────────────────────────────────
  // PPTX is a zip with slide XMLs at ppt/slides/slide*.xml.
  // We pull every <a:t> text node from each slide in order.
  static String _extractPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = archive.files
        .where((f) =>
            f.isFile &&
            f.name.startsWith('ppt/slides/slide') &&
            f.name.endsWith('.xml'))
        .toList();

    // Sort so slide2.xml comes after slide1.xml (lexical sort is wrong: slide10 < slide2)
    slideFiles.sort((a, b) {
      final ai = _slideIndex(a.name);
      final bi = _slideIndex(b.name);
      return ai.compareTo(bi);
    });

    final buffer = StringBuffer();
    for (var i = 0; i < slideFiles.length; i++) {
      final xmlString = utf8.decode(
        slideFiles[i].content as List<int>,
        allowMalformed: true,
      );
      final slideText = _textFromXml(xmlString);
      if (slideText.isNotEmpty) {
        buffer.writeln('Slide ${i + 1}:');
        buffer.writeln(slideText);
        buffer.writeln();
      }
    }
    return _normalize(buffer.toString());
  }

  // ── DOCX ───────────────────────────────────────────────────────────────────
  // DOCX is a zip with body XML at word/document.xml.
  // We pull every <w:t> text node.
  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.files.firstWhere(
      (f) => f.isFile && f.name == 'word/document.xml',
      orElse: () => ArchiveFile('', 0, <int>[]),
    );
    if (doc.size == 0) return '';
    final xmlString = utf8.decode(
      doc.content as List<int>,
      allowMalformed: true,
    );
    return _normalize(_textFromXml(xmlString));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parse XML and return concatenated text from all elements whose local name
  /// is "t" (matches both <a:t> in PPTX and <w:t> in DOCX without namespace headaches).
  static String _textFromXml(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final buffer = StringBuffer();
    for (final node in doc.descendants.whereType<XmlElement>()) {
      if (node.name.local == 't') {
        final text = node.innerText;
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write(' ');
        }
      } else if (node.name.local == 'br' || node.name.local == 'p') {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  static int _slideIndex(String fileName) {
    final match = RegExp(r'slide(\d+)\.xml$').firstMatch(fileName);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }

  static String _normalize(String text) {
    // Collapse 3+ newlines, trim trailing spaces per line, trim overall.
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .toList();
    final compact = StringBuffer();
    var blankRun = 0;
    for (final line in lines) {
      if (line.isEmpty) {
        blankRun++;
        if (blankRun <= 1) compact.writeln();
      } else {
        blankRun = 0;
        compact.writeln(line);
      }
    }
    return compact.toString().trim();
  }
}

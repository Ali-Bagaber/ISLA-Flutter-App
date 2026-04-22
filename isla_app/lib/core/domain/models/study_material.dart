enum StudyMaterialType { note, pdf, pptx }

class StudyMaterial {
  final String id;
  final String sessionId;
  final StudyMaterialType type;
  final String fileName;
  final String localPath;
  final String extractedText;

  const StudyMaterial({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.fileName,
    required this.localPath,
    required this.extractedText,
  });
}

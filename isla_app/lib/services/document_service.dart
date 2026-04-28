import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth_service.dart';

class DocumentService {
  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static FirebaseStorage? get _storage {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseStorage.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  static CollectionReference? get _col => _db?.collection('documents');

  static DateTime _safeCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  static int _parseSizeBytes(String rawSize) {
    final match =
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB)', caseSensitive: false)
            .firstMatch(rawSize.trim());
    if (match == null) return int.tryParse(rawSize.trim()) ?? 0;

    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? 'B').toUpperCase();
    final multiplier = switch (unit) {
      'GB' => 1024 * 1024 * 1024,
      'MB' => 1024 * 1024,
      'KB' => 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  /// Realtime stream of all documents for current user
  static Stream<List<Map<String, dynamic>>> watchDocuments() {
    final col = _col;
    final userId = _userId;
    if (col == null || userId == null) return Stream.value([]);
    return col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final docs = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      docs.sort((a, b) => _safeCreatedAt(b['createdAt'])
          .compareTo(_safeCreatedAt(a['createdAt'])));
      return docs;
    });
  }

  /// Upload a file to Firebase Storage and save metadata to Firestore.
  /// [fileBytes] — raw bytes from file_picker.
  /// [fileName] — original file name (e.g. "notes.pdf").
  /// [onProgress] — optional callback with 0.0–1.0 progress.
  static Future<String?> uploadAndSaveDocument({
    required String title,
    required String subject,
    required String fileName,
    required Uint8List fileBytes,
    String description = '',
    void Function(double progress)? onProgress,
  }) async {
    final storage = _storage;
    final db = _db;
    final userId = _userId;
    if (storage == null || db == null || userId == null) return null;

    final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final type = switch (ext.toLowerCase()) {
      'pdf' => 'PDF',
      'pptx' || 'ppt' => 'PPTX',
      'docx' || 'doc' => 'DOCX',
      _ => ext.toUpperCase(),
    };

    final docRef = db.collection('documents').doc();
    final storagePath = 'documents/$userId/${docRef.id}/$fileName';
    final storageRef = storage.ref(storagePath);

    // Upload bytes with progress tracking
    final uploadTask = storageRef.putData(
      fileBytes,
      SettableMetadata(
        contentType: _mimeFromExt(ext),
        customMetadata: {'userId': userId, 'docId': docRef.id},
      ),
    );

    uploadTask.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0 && onProgress != null) {
        onProgress(snap.bytesTransferred / snap.totalBytes);
      }
    });

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final sizeBytes = fileBytes.length;
    final sizeLabel = _formatSize(sizeBytes);

    await docRef.set({
      'documentId': docRef.id,
      'title': title,
      'subject': subject,
      'type': type,
      'fileType': type,
      'fileName': fileName,
      'size': sizeLabel,
      'fileSizeBytes': sizeBytes,
      'fileUrl': downloadUrl,
      'storagePath': storagePath,
      'processingStatus': 'ready',
      'isArchived': false,
      'notes': description,
      'userId': userId,
      'uploadDate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Save document metadata only (no file bytes — used for manual entry).
  static Future<String?> addDocument({
    required String title,
    required String subject,
    required String type,
    required String size,
    String description = '',
  }) async {
    final col = _col;
    final userId = _userId;
    if (col == null || userId == null) return null;
    final ref = col.doc();
    await ref.set({
      'documentId': ref.id,
      'title': title,
      'subject': subject,
      'type': type,
      'fileType': type,
      'size': size,
      'fileSizeBytes': _parseSizeBytes(size),
      'fileUrl': '',
      'storagePath': '',
      'processingStatus': 'ready',
      'isArchived': false,
      'notes': description,
      'userId': userId,
      'uploadDate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Delete a document + its Storage file
  static Future<void> deleteDocument(String id) async {
    final userId = _userId;
    if (userId == null) return;

    final col = _col;
    final db = _db;
    final storage = _storage;

    if (db != null && storage != null) {
      final snap = await db.collection('documents').doc(id).get();
      final path = snap.data()?['storagePath'] as String? ?? '';
      if (path.isNotEmpty) {
        try {
          await storage.ref(path).delete();
        } catch (_) {
          // File may already be gone; ignore.
        }
      }
    }

    await col?.doc(id).delete();
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  static String _mimeFromExt(String ext) {
    return switch (ext.toLowerCase()) {
      'pdf' => 'application/pdf',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'ppt' => 'application/vnd.ms-powerpoint',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc' => 'application/msword',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }

  // ─── Courses ───────────────────────────────────────────────────────────────

  static CollectionReference? get _coursesCol => _db?.collection('courses');

  /// Realtime stream of courses for the current user.
  static Stream<List<Map<String, dynamic>>> watchCourses() {
    final col = _coursesCol;
    final userId = _userId;
    if (col == null || userId == null) return Stream.value([]);
    return col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final courses = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      courses.sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      return courses;
    });
  }

  /// Create a new course. Returns the new course id.
  static Future<String?> createCourse(String name,
      {int credits = 3, String grade = ''}) async {
    final col = _coursesCol;
    final userId = _userId;
    if (col == null || userId == null) return null;
    final ref = col.doc();
    await ref.set({
      'courseId': ref.id,
      'userId': userId,
      'name': name.trim(),
      'credits': credits,
      'grade': grade.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Update grade/credits for a course.
  static Future<void> updateCourse(String courseId,
      {String? grade, int? credits}) async {
    final data = <String, dynamic>{};
    if (grade != null) data['grade'] = grade.trim();
    if (credits != null) data['credits'] = credits;
    if (data.isEmpty) return;
    await _coursesCol?.doc(courseId).update(data);
  }

  /// Delete a course (does NOT delete its documents).
  static Future<void> deleteCourse(String courseId) async {
    await _coursesCol?.doc(courseId).delete();
  }

  /// Stream of documents filtered to a specific subject/course name.
  static Stream<List<Map<String, dynamic>>> watchDocumentsBySubject(
      String subject) {
    final col = _col;
    final userId = _userId;
    if (col == null || userId == null) return Stream.value([]);
    return col
        .where('userId', isEqualTo: userId)
        .where('subject', isEqualTo: subject)
        .snapshots()
        .map((snap) {
      final docs = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      docs.sort((a, b) => _safeCreatedAt(b['createdAt'])
          .compareTo(_safeCreatedAt(a['createdAt'])));
      return docs;
    });
  }

  // ─── Marks ─────────────────────────────────────────────────────────────────

  static CollectionReference? get _marksCol => _db?.collection('marks');

  /// Realtime stream of marks for the current user.
  static Stream<List<Map<String, dynamic>>> watchMarks() {
    final col = _marksCol;
    final userId = _userId;
    if (col == null || userId == null) return Stream.value([]);
    return col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final marks = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      marks.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        final aDate = aTime is Timestamp ? aTime.toDate() : DateTime(1970);
        final bDate = bTime is Timestamp ? bTime.toDate() : DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return marks;
    });
  }

  /// Add a mark entry.
  static Future<void> addMark({
    required String subject,
    required String name,
    required String type,
    required double score,
    required double maxScore,
    double weight = 0,
  }) async {
    final col = _marksCol;
    final userId = _userId;
    if (col == null || userId == null) return;
    final ref = col.doc();
    final contribution = (weight > 0 && maxScore > 0)
        ? (score / maxScore) * weight
        : (maxScore > 0 ? (score / maxScore * 100) : 0);
    await ref.set({
      'markId': ref.id,
      'userId': userId,
      'subject': subject,
      'name': name.trim(),
      'type': type,
      'score': score,
      'maxScore': maxScore,
      'weight': weight,
      'contribution': double.parse(contribution.toStringAsFixed(2)),
      'percentage': maxScore > 0 ? (score / maxScore * 100).roundToDouble() : 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a mark.
  static Future<void> deleteMark(String markId) async {
    await _marksCol?.doc(markId).delete();
  }
}

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';

class FirebaseProfileService {
  FirebaseProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'users';

  String? get _docId => FirebaseAuth.instance.currentUser?.uid;

  Stream<UserProfile> watchProfile() {
    final docId = _docId;
    if (Firebase.apps.isEmpty || docId == null) {
      return Stream<UserProfile>.value(UserProfile.initial());
    }

    return _firestore
        .collection(_collection)
        .doc(docId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return UserProfile.initial();
      }
      return UserProfile.fromMap(snapshot.data() ?? {});
    });
  }

  Future<void> saveProfile(UserProfile profile) async {
    final docId = _docId;
    if (Firebase.apps.isEmpty || docId == null) return;

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final data = <String, dynamic>{
      'userId': docId,
      'email': email,
      'name': profile.name,
      'studentId': profile.studentId,
      'faculty': profile.faculty,
      'year': profile.year,
      'semester': profile.semester,
      'accountStatus': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profile.photoUrl.isNotEmpty) data['photoUrl'] = profile.photoUrl;

    await _firestore
        .collection('users')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  /// Upload a profile photo to Firebase Storage and return the download URL.
  Future<String?> uploadProfilePhoto(Uint8List bytes) async {
    final docId = _docId;
    if (Firebase.apps.isEmpty || docId == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child(docId)
        .child('photo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<Map<String, int>> loadStats() async {
    final userId = _docId;
    if (Firebase.apps.isEmpty || userId == null) {
      return {
        'minutes': 0,
        'sessions': 0,
        'documents': 0,
        'quizzes': 0,
      };
    }

    final sessionsSnapshot = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .get();
    final docsSnapshot = await _firestore
        .collection('documents')
        .where('userId', isEqualTo: userId)
        .get();
    final quizzesSnapshot = await _firestore
        .collection('quizzes')
        .where('userId', isEqualTo: userId)
        .get();

    var totalMinutes = 0;
    for (final doc in sessionsSnapshot.docs) {
      final value = doc.data()['focusMinutes'];
      if (value is int) {
        totalMinutes += value;
      }
    }

    return {
      'minutes': totalMinutes,
      'sessions': sessionsSnapshot.size,
      'documents': docsSnapshot.size,
      'quizzes': quizzesSnapshot.size,
    };
  }
}

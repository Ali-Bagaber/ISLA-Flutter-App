import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/secrets.dart';

class AuthService {
  /// Upsert user profile in Firestore `users` collection.
  /// Also initialises the `analytics` doc so the userId field is always present.
  static Future<void> _syncUserProfile(User user) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final db = FirebaseFirestore.instance;
      final uid = user.uid;

      // users collection
      await db.collection('users').doc(uid).set({
        'userId': uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // analytics collection — ensure userId is always written
      await db.collection('analytics').doc(uid).set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical — do not block sign-in.
    }
  }

  static FirebaseAuth? get _auth {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  /// Stream of auth state changes — null means logged out
  static Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges();
  }

  static User? get currentUser => _auth?.currentUser;

  /// Sign in with Google
  static Future<String?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) return 'Firebase not configured.';

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final result = await auth.signInWithPopup(provider);
        if (result.user != null) _syncUserProfile(result.user!);
        return null;
      }

      final googleUser = await GoogleSignIn(
        serverClientId: Secrets.firebaseGoogleWebClientId,
      ).signIn();

      if (googleUser == null) {
        return 'Google sign-in canceled.';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
      if (auth.currentUser != null) _syncUserProfile(auth.currentUser!);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyMessage(e.code);
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Sign in with email + password
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not configured.';
    try {
      final cred = await auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (cred.user != null) _syncUserProfile(cred.user!);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _friendlyMessage(e.code);
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Register with email + password
  static Future<String?> register({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not configured.';
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(email.split('@').first);
        _syncUserProfile(cred.user!);
      }
      // Keep registration flow on sign-in screen instead of auto-login.
      await auth.signOut();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _friendlyMessage(e.code);
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Ignore if GoogleSignIn state is unavailable.
      }
    }
    await _auth?.signOut();
  }

  static String _friendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

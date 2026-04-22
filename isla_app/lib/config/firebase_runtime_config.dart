import 'package:firebase_core/firebase_core.dart';
import 'secrets.dart';

class FirebaseRuntimeConfig {
  static String get apiKey => Secrets.firebaseApiKey;
  static String get appId => Secrets.firebaseAppId;
  static String get messagingSenderId => Secrets.firebaseMessagingSenderId;
  static String get projectId => Secrets.firebaseProjectId;
  static String get storageBucket => Secrets.firebaseStorageBucket;
  static String get authDomain => Secrets.firebaseAuthDomain;

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        apiKey != 'YOUR_FIREBASE_API_KEY' &&
        appId.isNotEmpty &&
        appId != 'YOUR_FIREBASE_APP_ID' &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty &&
        projectId != 'YOUR_PROJECT_ID';
  }

  static FirebaseOptions get options {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      authDomain: authDomain.isEmpty ? null : authDomain,
    );
  }
}

import 'package:flutter/foundation.dart';

/// Holds the currently-selected bottom-nav tab index so any screen can
/// programmatically switch tabs (e.g. Home's "View all" jumping to Tasks,
/// or a Quick Action opening the Analytics tab) without losing the
/// bottom navigation bar.
///
/// Tab indices (kept in sync with MainNavigation):
///   0 = Home
///   1 = Focus
///   2 = Tasks
///   3 = Analytics
///   4 = Library
///   5 = Docs
///   6 = Profile
class NavController extends ChangeNotifier {
  static const int home = 0;
  static const int focus = 1;
  static const int tasks = 2;
  static const int analytics = 3;
  static const int library = 4;
  static const int docs = 5;
  static const int profile = 6;

  int _index = home;
  int get index => _index;

  void goTo(int next) {
    if (next == _index) return;
    _index = next;
    notifyListeners();
  }

  // Convenience accessors for clearer call sites.
  void goHome() => goTo(home);
  void goFocus() => goTo(focus);
  void goTasks() => goTo(tasks);
  void goAnalytics() => goTo(analytics);
  void goLibrary() => goTo(library);
  void goDocs() => goTo(docs);
  void goProfile() => goTo(profile);
}

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny persistence wrapper for the "has the user seen the 6-second
/// intro?" flag. Kept separate from the rest of the app so it's easy
/// to swap to a real preferences-store later.
class IntroService {
  static const _key = 'peeled.has_seen_intro_v1';

  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> resetIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

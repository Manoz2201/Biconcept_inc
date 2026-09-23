import 'package:shared_preferences/shared_preferences.dart';

class EnquiryCooldown {
  EnquiryCooldown({this.duration = const Duration(seconds: 60)});

  static const storageKey = 'enquiry.lastSubmitAt';

  final Duration duration;

  Future<Duration?> remaining() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(storageKey);
    if (raw == null) return null;
    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(raw));
    if (elapsed >= duration) return null;
    return duration - elapsed;
  }

  Future<void> markSubmitted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(storageKey, DateTime.now().millisecondsSinceEpoch);
  }
}

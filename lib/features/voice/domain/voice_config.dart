class VoiceConfig {
  const VoiceConfig({this.localeId = 'en_IN', this.listenFor = const Duration(minutes: 5)});

  final String localeId;
  final Duration listenFor;
}

class VoiceState {
  const VoiceState({this.isListening = false, this.transcript = ''});

  final bool isListening;
  final String transcript;
}

class RateLimiter {
  RateLimiter();

  final Map<String, List<DateTime>> _calls = {};

  bool canProceed(String key, {required int maxCalls, required Duration window}) {
    final now = DateTime.now();
    final recent = (_calls[key] ?? []).where((time) => now.difference(time) < window).toList();
    if (recent.length >= maxCalls) return false;
    recent.add(now);
    _calls[key] = recent;
    return true;
  }
}

int dailyAiLimit(String plan) => switch (plan) {
      'enterprise' => 100000,
      'pro' => 1000,
      _ => 100,
    };

int monthlyOcrLimit(String plan) => switch (plan) {
      'enterprise' => 100000,
      'pro' => 500,
      _ => 50,
    };

int monthlyWhatsappLimit(String plan) => switch (plan) {
      'enterprise' => 100000,
      'pro' => 1000,
      _ => 100,
    };

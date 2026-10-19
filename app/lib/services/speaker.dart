import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud for people who read slowly or not at all. It is given only the reasons for a result (generic sentences from the
/// rule pack), never the person's message, so nothing private is spoken even if a phone's speech engine uses an online voice.
abstract class Speaker {
  Future<void> speak(String text, String lang);
  Future<void> stop();
}

class FlutterTtsSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text, String lang) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(lang == 'hi' ? 'hi-IN' : 'en-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } on Object {
      // no speech engine or no voice for this language: silence is better than a crash
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // nothing to stop
    }
  }
}

/// Text normalisation. A line-by-line port of engine/scamsaathi/normalize.py: the two must stay identical,
/// and test/corpus_test.dart checks that against the shared golden corpus.
const _zeroWidth = '​‌‍⁠﻿';
const _whitespace = ' \t\n\r\v\f    　';

String normalize(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    var ch = String.fromCharCode(r);
    if (_zeroWidth.contains(ch)) continue;
    if (r >= 0xFF01 && r <= 0xFF5E) {
      ch = String.fromCharCode(r - 0xFEE0); // full-width ASCII
    } else if (r >= 0x0966 && r <= 0x096F) {
      ch = String.fromCharCode(r - 0x0966 + 48); // Devanagari digits
    } else if (_whitespace.contains(ch)) {
      ch = ' ';
    }
    out.write(ch);
  }
  return out.toString().toLowerCase().split(' ').where((p) => p.isNotEmpty).join(' ');
}

bool _isAsciiAlnum(String ch) {
  if (ch.isEmpty) return false;
  final c = ch.codeUnitAt(0);
  return (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39);
}

/// `substring`: plain containment. `word`: the phrase must not touch another ASCII letter or digit.
bool containsPhrase(String text, String phrase, String mode) {
  var start = 0;
  while (true) {
    final i = text.indexOf(phrase, start);
    if (i < 0) return false;
    if (mode == 'substring') return true;
    final before = i > 0 ? text[i - 1] : ' ';
    final end = i + phrase.length;
    final after = end < text.length ? text[end] : ' ';
    final leftOk = !(_isAsciiAlnum(phrase[0]) && _isAsciiAlnum(before));
    final rightOk = !(_isAsciiAlnum(phrase[phrase.length - 1]) && _isAsciiAlnum(after));
    if (leftOk && rightOk) return true;
    start = i + 1;
  }
}

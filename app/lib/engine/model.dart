// The wording model: a character n-gram Naive Bayes with integer weights. A port of engine/scamsaathi/model.py, so both engines
// give exactly the same answer. It can add a warning but can never, on its own, make a message "dangerous".
import 'extract.dart';

const modelId = 'model.wording';
final _digit = RegExp(r'[0-9]');

/// Normalised text -> words: links become `urltok`, every digit becomes 0.
List<String> prepare(String norm, Map<String, dynamic> lists) {
  final text = norm.replaceAll(urlPattern(lists), ' urltok ').replaceAll(_digit, '0');
  return text.split(' ').where((w) => w.isNotEmpty).toList();
}

/// (sum of integer weights over all n-grams, number of n-grams)
(int, int) scoreParts(String norm, Map<String, dynamic> model, Map<String, dynamic> lists) {
  final weights = model['weights'] as Map<String, dynamic>;
  final ngrams = (model['ngrams'] as List).cast<int>();
  var total = 0, count = 0;
  for (final word in prepare(norm, lists)) {
    final runes = ' $word '.runes.toList(); // code points, like Python, so non-BMP characters count the same
    for (final n in ngrams) {
      for (var i = 0; i + n <= runes.length; i++) {
        total += (weights[String.fromCharCodes(runes.sublist(i, i + n))] as int?) ?? 0;
        count++;
      }
    }
  }
  return (total, count);
}

bool modelFires(String norm, Map<String, dynamic> model, Map<String, dynamic> lists) {
  final (total, count) = scoreParts(norm, model, lists);
  return count > 0 && total > (model['threshold'] as int) * count; // length-normalised, integers only
}

/// Links, app files and UPI IDs in already-normalised text. A port of engine/scamsaathi/extract.py.
/// Nothing is ever fetched, opened or executed.
class Extracted {
  final Set<String> features = {};
  final Set<String> domains = {};
  final Set<String> apkFiles = {};
  final Set<String> upiIds = {};
}

const _trail = '.,;:!?';
const _tokenStrip = '.,;:!?()[]<>"\'';
const _urlChars = r'''[^\s<>"')\]\u0080-￿]''';

int _byLenThenName(String a, String b) => a.length != b.length ? b.length.compareTo(a.length) : a.compareTo(b);

RegExp _urlRegex(List<String> bareTlds, List<String> shorteners) {
  final tlds = ([...bareTlds]..sort(_byLenThenName)).join('|');
  final shorts = ([...shorteners]..sort(_byLenThenName)).map(RegExp.escape).join('|');
  const tail = '(?![a-z0-9-])(?:[/?#]$_urlChars*)?';
  return RegExp(
    '(?:https?://|www\\.)$_urlChars+'
    '|(?<![a-z0-9@./-])(?:$shorts)$tail'
    '|(?<![a-z0-9@./-])[a-z0-9][a-z0-9-]*(?:\\.[a-z0-9-]+)*\\.(?:$tlds)$tail',
  );
}

RegExp _upiRegex(List<String> handles) {
  final hs = ([...handles]..sort(_byLenThenName)).join('|');
  return RegExp('(?<![a-z0-9._@-])[a-z0-9][a-z0-9._-]+@(?:$hs)(?![a-z0-9._-])');
}

String _stripTrailing(String url) {
  var u = url;
  while (u.isNotEmpty && _trail.contains(u[u.length - 1])) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// (host, path). Manual parsing on purpose: URL parsers differ between languages.
(String, String) splitUrl(String url) {
  var rest = url;
  for (final scheme in ['https://', 'http://']) {
    if (rest.startsWith(scheme)) {
      rest = rest.substring(scheme.length);
      break;
    }
  }
  var cut = rest.length;
  for (final sep in ['/', '?', '#']) {
    final i = rest.indexOf(sep);
    if (i >= 0 && i < cut) cut = i;
  }
  var host = rest.substring(0, cut);
  final path = rest.substring(cut);
  if (host.contains('@')) host = host.substring(host.lastIndexOf('@') + 1);
  if (host.contains(':')) host = host.substring(0, host.indexOf(':'));
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  return (host, path);
}

bool _isIp(String host) {
  final parts = host.split('.');
  final digits = RegExp(r'^[0-9]{1,3}$');
  return parts.length == 4 && parts.every(digits.hasMatch);
}

bool _onDomain(String host, String domain) => host == domain || host.endsWith('.$domain');

Set<String> urlFeatures(String host, String path, Map<String, dynamic> lists) {
  final feats = <String>{};
  if (host.isEmpty) return feats;
  List<String> list(String k) => (lists[k] as List).cast<String>();
  if (list('shorteners').any((s) => _onDomain(host, s))) feats.add('url.shortener');
  if (_isIp(host)) feats.add('url.ip_host');
  if (host.split('.').any((l) => l.startsWith('xn--'))) feats.add('url.punycode');
  if (list('risky_tlds').contains(host.split('.').last)) feats.add('url.risky_tld');
  if (path.split('?')[0].split('#')[0].endsWith('.apk')) feats.add('url.apk');
  if (list('gov_words').any(host.contains) && !list('official_gov_domains').any((d) => _onDomain(host, d))) {
    feats.add('url.lookalike_gov');
  }
  (lists['brands'] as Map<String, dynamic>).forEach((brand, official) {
    if (host.contains(brand) && !(official as List).cast<String>().any((d) => _onDomain(host, d))) {
      feats.add('url.lookalike_brand');
    }
  });
  return feats;
}

String _stripChars(String token, String chars) {
  var s = 0, e = token.length;
  while (s < e && chars.contains(token[s])) {
    s++;
  }
  while (e > s && chars.contains(token[e - 1])) {
    e--;
  }
  return token.substring(s, e);
}

Extracted extract(String norm, Map<String, dynamic> lists) {
  final out = Extracted();
  List<String> list(String k) => (lists[k] as List).cast<String>();
  for (final m in _urlRegex(list('bare_tlds'), list('shorteners')).allMatches(norm)) {
    var url = _stripTrailing(m.group(0)!);
    if (url.startsWith('www.')) url = 'http://$url';
    final (host, path) = splitUrl(url);
    if (host.isEmpty) continue;
    out.domains.add(host);
    out.features.addAll(urlFeatures(host, path, lists));
  }
  for (final raw in norm.split(' ')) {
    final token = _stripChars(raw, _tokenStrip);
    if (token.endsWith('.apk') && !token.contains('/')) {
      out.apkFiles.add(token);
      out.features.add('file.apk');
    }
  }
  for (final m in _upiRegex(list('upi_handles')).allMatches(norm)) {
    out.upiIds.add(m.group(0)!);
  }
  return out;
}

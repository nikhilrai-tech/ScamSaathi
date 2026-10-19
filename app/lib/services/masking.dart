// Hide personal details in a message before it can leave the phone. A port of api/intel/masking.py (the server repeats it); both
// are tested against packs/core/masking_cases.json. It hides phone numbers, long digit runs (OTPs, Aadhaar, account and card numbers),
// PAN, email addresses, UPI IDs and the path of links. It cannot hide names: the person sending must read what is sent.
final _address = RegExp(r'([A-Za-z0-9._%+\-]{2,})@([A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*)');
final _url = RegExp(r'''(https?://[^\s/<>"']+|www\.[^\s/<>"']+)([^\s<>"']*)''');
final _phone = RegExp(r'(?<![0-9०-९])(?:\+?91[\-\s]?)?[6-9][0-9]{4}[\-\s]?[0-9]{5}(?![0-9०-९])');
final _grouped = RegExp(r'(?<![0-9])[0-9]{4}[\-\s][0-9]{4}[\-\s][0-9]{4}(?:[\-\s][0-9]{4})?(?![0-9])');
final _pan = RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]');
final _long = RegExp(r'[0-9०-९]{6,}');
final _digit = RegExp(r'[0-9]');

String maskText(String text) {
  var t = text.replaceAllMapped(_address, (m) => m.group(2)!.contains('.') ? 'user@example.com' : 'user@upi');
  t = t.replaceAllMapped(_url, (m) => m.group(1)! + (m.group(2)!.isNotEmpty ? '/…' : ''));
  t = t.replaceAll(_phone, '9XXXXXXXXX');
  t = t.replaceAllMapped(_grouped, (m) => m.group(0)!.replaceAll(_digit, 'X'));
  t = t.replaceAll(_pan, 'AAAAA0000A');
  return t.replaceAllMapped(_long, (m) => 'X' * m.group(0)!.length);
}

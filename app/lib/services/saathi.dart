import '../engine/engine.dart';

class Saathi {
  final String name;
  final String phone; // digits with optional leading +, kept only on this phone
  const Saathi(this.name, this.phone);
}

const familyLabels = <String, Map<String, String>>{
  'fake_apk': {'en': 'a fake app file', 'hi': 'नकली ऐप फ़ाइल'},
  'kyc_bank': {'en': 'a fake bank KYC or OTP message', 'hi': 'नकली बैंक केवाईसी या ओटीपी संदेश'},
  'upi_collect': {'en': 'a UPI money-request trick', 'hi': 'UPI से पैसे निकालने की चाल'},
  'job_scholarship': {'en': 'a fake job or scholarship offer', 'hi': 'नकली नौकरी या स्कॉलरशिप का ऑफर'},
  'loan_app': {'en': 'a fake loan or blackmail message', 'hi': 'नकली लोन या ब्लैकमेल संदेश'},
  'govt_scheme': {'en': 'a fake government scheme message', 'hi': 'नकली सरकारी योजना का संदेश'},
  'prize_lottery': {'en': 'a fake prize or lottery', 'hi': 'नकली इनाम या लॉटरी'},
  'advance_fee': {'en': 'a message asking for money first', 'hi': 'पहले पैसे मांगने वाला संदेश'},
  'impersonation': {'en': 'someone pretending to be police or an officer', 'hi': 'पुलिस या अधिकारी बनकर डराने वाला संदेश'},
  'remote_access': {'en': 'a request to install a remote-control app', 'hi': 'रिमोट कंट्रोल ऐप डलवाने की कोशिश'},
};

/// The text sent to the user's Saathi. It names the kind of scam only: never the message, a link, a number or a UPI ID,
/// so the Saathi's chat cannot be turned into a way to spread the scam.
String buildSaathiMessage(Analysis a, String lang, {String? fromName}) {
  final kind = familyLabels[a.family]?[lang] ?? (lang == 'hi' ? 'एक संदिग्ध संदेश' : 'a suspicious message');
  final strong = a.verdict == 'dangerous';
  if (lang == 'hi') {
    final who = (fromName == null || fromName.isEmpty) ? '' : ' ($fromName)';
    return 'ScamSaathi$who: मुझे अभी $kind मिला है। ScamSaathi ने इसे ${strong ? "ख़तरनाक" : "संदिग्ध"} बताया है। '
        'मैंने कुछ क्लिक, इंस्टॉल या पेमेंट नहीं किया है। कृपया मुझे फोन करें।';
  }
  final who = (fromName == null || fromName.isEmpty) ? '' : ' ($fromName)';
  return 'ScamSaathi$who: I just received $kind. ScamSaathi marked it as ${strong ? "DANGEROUS" : "suspicious"}. '
      'I have not clicked, installed or paid anything. Please call me.';
}

/// `sms:` link for the user's own messaging app. The user sends it themselves; the app sends nothing.
Uri saathiSmsUri(Saathi s, String message) => Uri(scheme: 'sms', path: s.phone, queryParameters: {'body': message});

Uri saathiWhatsAppUri(Saathi s, String message) {
  final digits = s.phone.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri.https('wa.me', '/$digits', {'text': message});
}

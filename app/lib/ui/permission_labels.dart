/// Plain-language names for the Android permissions that matter most. [risky] ones are what fake bank, government and loan apps abuse.
class PermissionLabel {
  final String en, hi;
  final bool risky;
  const PermissionLabel(this.en, this.hi, {this.risky = false});
}

const _p = 'android.permission.';

const permissionLabels = <String, PermissionLabel>{
  '${_p}READ_SMS': PermissionLabel('Read your text messages (including OTPs)', 'आपके टेक्स्ट मैसेज पढ़ना (ओटीपी भी)', risky: true),
  '${_p}RECEIVE_SMS': PermissionLabel('See every new text message', 'हर नया टेक्स्ट मैसेज देखना', risky: true),
  '${_p}SEND_SMS': PermissionLabel('Send messages for you (can cost money)', 'आपकी तरफ से मैसेज भेजना (पैसे कट सकते हैं)', risky: true),
  '${_p}READ_CONTACTS': PermissionLabel('See your contacts', 'आपके कॉन्टैक्ट्स देखना', risky: true),
  '${_p}READ_CALL_LOG': PermissionLabel('See your call history', 'आपकी कॉल हिस्ट्री देखना', risky: true),
  '${_p}WRITE_CALL_LOG': PermissionLabel('Change your call history', 'कॉल हिस्ट्री बदलना', risky: true),
  '${_p}CALL_PHONE': PermissionLabel('Make calls for you', 'आपकी तरफ से कॉल करना', risky: true),
  '${_p}PROCESS_OUTGOING_CALLS': PermissionLabel('Watch or redirect your outgoing calls', 'आपके आउटगोइंग कॉल देखना या मोड़ना', risky: true),
  '${_p}ANSWER_PHONE_CALLS': PermissionLabel('Answer calls for you', 'आपकी तरफ से कॉल उठाना', risky: true),
  '${_p}RECORD_AUDIO': PermissionLabel('Record with the microphone', 'माइक्रोफ़ोन से रिकॉर्ड करना', risky: true),
  '${_p}CAMERA': PermissionLabel('Use the camera', 'कैमरा इस्तेमाल करना'),
  '${_p}ACCESS_FINE_LOCATION': PermissionLabel('Know your exact location', 'आपकी सटीक लोकेशन जानना', risky: true),
  '${_p}READ_PHONE_STATE': PermissionLabel('Read your phone number and device details', 'आपका फोन नंबर और डिवाइस की जानकारी पढ़ना'),
  '${_p}READ_EXTERNAL_STORAGE': PermissionLabel('Read your photos and files', 'आपकी फ़ोटो और फ़ाइलें पढ़ना', risky: true),
  '${_p}SYSTEM_ALERT_WINDOW': PermissionLabel('Draw over other apps', 'दूसरे ऐप के ऊपर स्क्रीन दिखाना', risky: true),
  '${_p}REQUEST_INSTALL_PACKAGES': PermissionLabel('Install other apps', 'दूसरे ऐप इंस्टॉल करना', risky: true),
  '${_p}BIND_ACCESSIBILITY_SERVICE': PermissionLabel('Read your screen and tap for you', 'आपकी स्क्रीन पढ़ना और आपकी तरह टैप करना', risky: true),
  '${_p}BIND_DEVICE_ADMIN': PermissionLabel('Become a device administrator (can lock your phone)', 'डिवाइस एडमिन बनना (फोन लॉक कर सकता है)', risky: true),
  '${_p}INTERNET': PermissionLabel('Use the internet', 'इंटरनेट इस्तेमाल करना'),
  '${_p}VIBRATE': PermissionLabel('Vibrate the phone', 'फोन वाइब्रेट करना'),
  '${_p}FLASHLIGHT': PermissionLabel('Use the flashlight', 'टॉर्च इस्तेमाल करना'),
};

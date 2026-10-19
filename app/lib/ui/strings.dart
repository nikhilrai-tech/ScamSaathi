/// All user-visible text, Hindi first. Add a language by adding a map here and its code to [languages].
const languages = {'hi': 'हिन्दी', 'en': 'English'};

const _s = <String, Map<String, String>>{
  'appName': {'hi': 'ScamSaathi', 'en': 'ScamSaathi'},
  'tagline': {
    'hi': 'कोई मैसेज, लिंक या ऐप ठगी तो नहीं? यहाँ चेक करें।',
    'en': 'Is a message, link or app a scam? Check it here.',
  },
  'privacy': {
    'hi': 'आपका मैसेज इसी फोन पर जाँचा जाता है। कहीं भेजा नहीं जाता।',
    'en': 'Your message is checked on this phone. It is never sent anywhere.',
  },
  'hint': {
    'hi': 'यहाँ मैसेज या लिंक डालें',
    'en': 'Paste the message or link here',
  },
  'paste': {'hi': 'पेस्ट करें', 'en': 'Paste'},
  'check': {'hi': 'जाँचें', 'en': 'Check'},
  'clear': {'hi': 'मिटाएं', 'en': 'Clear'},
  'dangerousTitle': {
    'hi': 'ख़तरनाक — ठगी लगती है',
    'en': 'DANGEROUS — this looks like a scam',
  },
  'dangerousAdvice': {
    'hi': 'पैसे न भेजें। कोई लिंक न खोलें। कोई ऐप इंस्टॉल न करें। ओटीपी या पिन किसी को न बताएं।',
    'en': 'Do not send money. Do not open links. Do not install apps. Never share an OTP or PIN.',
  },
  'suspiciousTitle': {
    'hi': 'संदिग्ध — सावधान रहें',
    'en': 'SUSPICIOUS — be careful',
  },
  'suspiciousAdvice': {
    'hi': 'कुछ भी करने से पहले किसी भरोसेमंद व्यक्ति से पूछ लें।',
    'en': 'Ask someone you trust before you do anything.',
  },
  'safeTitle': {
    'hi': 'ख़तरे का कोई निशान नहीं मिला',
    'en': 'No warning signs found',
  },
  'safeAdvice': {
    'hi': 'इसका मतलब पक्का सुरक्षित होना नहीं है। ओटीपी, पिन या पैसे कभी किसी अनजान को न दें।',
    'en': 'This does not guarantee it is safe. Never give an OTP, PIN or money to a stranger.',
  },
  'why': {'hi': 'ऐसा क्यों कहा?', 'en': 'Why?'},
  'tellSaathi': {'hi': 'अपने साथी को बताएं', 'en': 'Tell my Saathi'},
  'tellSaathiWhatsApp': {'hi': 'WhatsApp पर बताएं', 'en': 'Tell on WhatsApp'},
  'setSaathiFirst': {'hi': 'पहले साथी चुनें', 'en': 'Choose a Saathi first'},
  'call1930': {
    'hi': 'पैसे कट गए? 1930 पर कॉल करें',
    'en': 'Lost money? Call 1930',
  },
  'report': {
    'hi': 'इस ठगी की गुमनाम रिपोर्ट करें',
    'en': 'Report this scam anonymously',
  },
  'reported': {
    'hi': 'रिपोर्ट भेज दी गई। धन्यवाद!',
    'en': 'Report sent. Thank you!',
  },
  'reportFailed': {
    'hi': 'रिपोर्ट नहीं जा सकी।',
    'en': 'Could not send the report.',
  },
  'settings': {'hi': 'सेटिंग', 'en': 'Settings'},
  'language': {'hi': 'भाषा', 'en': 'Language'},
  'yourName': {
    'hi': 'आपका नाम (साथी को संदेश में दिखेगा)',
    'en': 'Your name (shown in the message to your Saathi)',
  },
  'saathiSection': {'hi': 'मेरा साथी', 'en': 'My Saathi'},
  'saathiHelp': {
    'hi': 'कोई भरोसेमंद व्यक्ति: बेटा, शिक्षक, पड़ोसी। ख़तरा दिखने पर आप उन्हें एक छोटा संदेश भेज सकते हैं। उसमें आपका मैसेज, लिंक या नंबर नहीं होता।',
    'en': 'Someone you trust: a son, a teacher, a neighbour. When something looks dangerous you can send them a short note. It never contains your message, links or numbers.',
  },
  'saathiName': {'hi': 'साथी का नाम', 'en': 'Saathi name'},
  'saathiPhone': {'hi': 'साथी का फोन नंबर', 'en': 'Saathi phone number'},
  'save': {'hi': 'सेव करें', 'en': 'Save'},
  'remove': {'hi': 'हटाएं', 'en': 'Remove'},
  'reportingSwitch': {
    'hi': 'गुमनाम रिपोर्ट की अनुमति',
    'en': 'Allow anonymous reports',
  },
  'reportingHelp': {
    'hi': 'बंद है। चालू करने पर, आपके टैप करने के बाद ही ठगी वाले लिंक और UPI आईडी का एक कोड (हैश), ठगी का प्रकार और ज़िला भेजा जाएगा। आपका मैसेज, नाम या फोन नंबर कभी नहीं।',
    'en': 'Off by default. If you turn it on, only after you tap "report" it sends a code (hash) of the scam link or UPI ID, the kind of scam and your district. Never your message, name or phone number.',
  },
  'district': {
    'hi': 'ज़िला (जैसे nashik)',
    'en': 'District (for example nashik)',
  },
  'rules': {'hi': 'नियम संस्करण', 'en': 'Rules version'},
  'unsure': {
    'hi': 'ScamSaathi गलत भी हो सकता है। शक हो तो पैसे न दें और किसी भरोसेमंद से पूछें।',
    'en': 'ScamSaathi can be wrong. If you are unsure, do not pay and ask someone you trust.',
  },
  'trySample': {
    'hi': 'हाथ में मैसेज नहीं है? एक नमूना आज़माएं',
    'en': 'No message at hand? Try an example',
  },
  'sampleKyc': {'hi': 'नकली बैंक केवाईसी', 'en': 'Fake bank KYC'},
  'sampleApk': {'hi': 'नकली PM-Kisan ऐप', 'en': 'Fake PM-Kisan app'},
  'sampleUpi': {'hi': 'UPI रिफंड की चाल', 'en': 'UPI refund trick'},
  'sampleOk': {'hi': 'सामान्य मैसेज', 'en': 'Normal message'},
  'rulesTitle': {'hi': '3 सुनहरे नियम', 'en': '3 golden rules'},
  'rule1': {
    'hi': 'ओटीपी और पिन किसी को न बताएं। बैंक भी नहीं मांगता।',
    'en': 'Never share your OTP or PIN. Not even a bank asks for it.',
  },
  'rule2': {
    'hi': 'पैसे पाने के लिए पिन नहीं डालना पड़ता। पिन डाला तो पैसे कटेंगे।',
    'en': 'You never enter a PIN to receive money. If you enter it, money leaves your account.',
  },
  'rule3': {
    'hi': 'WhatsApp या SMS से आई .apk फ़ाइल कभी इंस्टॉल न करें। ऐप सिर्फ़ प्ले स्टोर से।',
    'en': 'Never install an .apk that came on WhatsApp or SMS. Get apps only from the Play Store.',
  },
  'level': {'hi': 'चेतावनी स्तर', 'en': 'Warning level'},
  'levelLow': {'hi': 'कम', 'en': 'Low'},
  'levelMid': {'hi': 'मध्यम', 'en': 'Medium'},
  'levelHigh': {'hi': 'ऊँचा', 'en': 'High'},
  'kindOfScam': {'hi': 'ठगी का प्रकार', 'en': 'Kind of scam'},
  'webDemo': {
    'hi': 'वेब डेमो: आपका मैसेज इसी ब्राउज़र टैब में जाँचा जाता है। कोई सर्वर या बाहरी साइट इसे नहीं देखती।',
    'en': 'Web demo: your message is checked inside this browser tab. No server or third-party site ever sees it.',
  },
  'wrongResult': {'hi': 'यह नतीजा गलत है?', 'en': 'Is this result wrong?'},
  'fbTitle': {'hi': 'हमें सुधारने में मदद करें', 'en': 'Help us get better'},
  'fbIntro': {
    'hi': 'अगर ऐप ने गलत बताया, तो यह मैसेज हमें भेज सकते हैं। नीचे जो लिखा है वही भेजा जाएगा। नंबर, ओटीपी, ईमेल, UPI आईडी और लिंक का रास्ता पहले ही छुपा दिया गया है। आप इसे बदल सकते हैं।',
    'en': 'If the app got it wrong, you can send us this message. Only what is written below is sent. Numbers, OTPs, emails, UPI IDs and link paths are already hidden, and you can change the text.',
  },
  'fbLabelScam': {'hi': 'यह ठगी का मैसेज है', 'en': 'This is a scam message'},
  'fbLabelNormal': {'hi': 'यह सामान्य मैसेज है', 'en': 'This is a normal message'},
  'fbEdit': {'hi': 'भेजा जाने वाला मैसेज', 'en': 'Message that will be sent'},
  'fbNames': {'hi': 'नाम या कोई और निजी बात हो तो हटा दें।', 'en': 'Remove any names or anything else private.'},
  'fbStored': {
    'hi': 'हम सिर्फ यह मैसेज और आपका चुनाव रखते हैं। कोई खाता, फोन नंबर या डिवाइस आईडी नहीं। आपकी पहचान नहीं हो सकती, इसलिए बाद में इसे हटवाया भी नहीं जा सकता।',
    'en': 'We keep only this text and your choice. No account, phone number or device id. Because nothing identifies you, it cannot be removed later.',
  },
  'fbSend': {'hi': 'भेजें', 'en': 'Send'},
  'fbCancel': {'hi': 'रद्द करें', 'en': 'Cancel'},
  'fbThanks': {'hi': 'धन्यवाद! आपका मैसेज मिल गया।', 'en': 'Thank you! We received your message.'},
  'fbFailed': {'hi': 'भेजा नहीं जा सका। बाद में कोशिश करें।', 'en': 'Could not send. Please try again later.'},
  'checkApk': {'hi': 'APK फ़ाइल जाँचें', 'en': 'Check an APK file'},
  'apkNotApp': {'hi': 'यह एंड्रॉयड ऐप फ़ाइल नहीं लगती, या खराब है।', 'en': 'This does not look like an Android app, or it is damaged.'},
  'apkTooBig': {'hi': 'फ़ाइल बहुत बड़ी है (150 MB से ज़्यादा)।', 'en': 'The file is too big (over 150 MB).'},
  'apkAsks': {'hi': 'यह ऐप क्या-क्या माँगता है', 'en': 'What this app asks for'},
  'apkPackage': {'hi': 'ऐप का पैकेज नाम', 'en': 'App package name'},
  'apkMore': {'hi': 'और इजाज़तें', 'en': 'more permissions'},
  'apkNote': {
    'hi': 'हम सिर्फ इजाज़तों की सूची पढ़ते हैं। कम इजाज़त माँगने वाली फ़ाइल भी जाल हो सकती है। ऐप सिर्फ प्ले स्टोर से इंस्टॉल करें।',
    'en': 'We only read the list of permissions. A file that asks for few can still be a trap. Install apps only from the Play Store.',
  },
  'apkPrivate': {
    'hi': 'आपकी फ़ाइल कभी इंस्टॉल या चलाई नहीं जाती और इस डिवाइस से बाहर नहीं जाती।',
    'en': 'Your file is never installed or run, and it never leaves this device.',
  },
  'sampleApkFake': {'hi': 'नकली PM-Kisan ऐप फ़ाइल', 'en': 'Fake PM-Kisan app file'},
  'sampleApkOk': {'hi': 'सामान्य टॉर्च ऐप फ़ाइल', 'en': 'Harmless torch app file'},
  'listen': {'hi': 'सुनें', 'en': 'Listen'},
  'stopListening': {'hi': 'रोकें', 'en': 'Stop'},
  'obNext': {'hi': 'आगे', 'en': 'Next'},
  'obSkip': {'hi': 'छोड़ें', 'en': 'Skip'},
  'obStart': {'hi': 'शुरू करें', 'en': 'Get started'},
  'ob1Title': {'hi': 'भरोसा करने से पहले जाँचें', 'en': 'Check before you trust'},
  'ob1Body': {
    'hi': 'कोई मैसेज, लिंक या ऐप फ़ाइल ठगी तो नहीं? WhatsApp या SMS से शेयर करें, या यहाँ पेस्ट करें। जवाब आसान भाषा में, कारण के साथ मिलेगा।',
    'en': 'Is a message, link or app file a scam? Share it from WhatsApp or SMS, or paste it here. You get a plain answer with the reasons.',
  },
  'ob2Title': {'hi': 'आपका मैसेज फोन से बाहर नहीं जाता', 'en': 'Your message stays on your phone'},
  'ob2Body': {
    'hi': 'जाँच इसी फोन पर होती है। ऐप आपके SMS, कॉन्टैक्ट्स या फाइलें नहीं पढ़ता। कुछ भी तभी भेजा जाता है जब आप खुद चालू करें या "भेजें" दबाएँ।',
    'en': 'The check runs on this phone. The app does not read your SMS, contacts or files. Anything is sent only if you turn it on or tap Send.',
  },
  'ob3Title': {'hi': 'एक भरोसेमंद व्यक्ति चुनें (वैकल्पिक)', 'en': 'Choose someone you trust (optional)'},
  'ob3Body': {
    'hi': 'बेटा, शिक्षक या पड़ोसी। ख़तरा दिखे तो आप उन्हें एक छोटा संदेश भेज सकते हैं, जिसमें आपका मैसेज नहीं होता।',
    'en': 'A son, a teacher, a neighbour. When something looks dangerous you can send them a short note that never contains your message.',
  },
  'aboutSection': {'hi': 'जानकारी', 'en': 'About'},
  'aboutPrivacy': {'hi': 'निजता', 'en': 'Privacy'},
  'aboutHow': {'hi': 'यह कैसे काम करता है', 'en': 'How it works'},
  'readMore': {'hi': 'पूरी जानकारी GitHub पर खोलें', 'en': 'Read the full details on GitHub'},
  'p1': {
    'hi': 'फोन पर रहता है: आपकी भाषा, आपके चुने "साथी" का नाम और नंबर, और ठगी की सार्वजनिक सूची (सिर्फ हैश)।',
    'en': 'Stays on your phone: your language, the name and number of the Saathi you chose, and the community scam list (hashes only).',
  },
  'p2': {
    'hi': 'कभी नहीं: खाता, विज्ञापन, ट्रैकिंग, या आपके SMS, कॉन्टैक्ट्स और लोकेशन तक पहुँच।',
    'en': 'Never: accounts, ads, tracking, or access to your SMS, contacts or location.',
  },
  'p3': {
    'hi': 'सिर्फ आपकी अनुमति से: (1) गुमनाम रिपोर्ट, जिसमें लिंक या UPI आईडी का सिर्फ कोड (हैश) जाता है। (2) "यह नतीजा गलत है", जहाँ आप मैसेज देखकर "भेजें" दबाते हैं, नंबर जैसी निजी बातें छुपाकर।',
    'en': 'Only with your permission: (1) anonymous reports, which send only a code (hash) of a link or UPI ID. (2) "This result is wrong", where you read the message and tap Send, with numbers and similar details hidden.',
  },
  'p4': {
    'hi': 'सुनने का बटन सिर्फ नतीजे के कारण पढ़ता है, आपका मैसेज नहीं। आपके फोन का आवाज़ इंजन उन्हें बोलता है।',
    'en': 'The Listen button reads out only the reasons, never your message. Your phone\'s speech engine says them.',
  },
  'h1': {
    'hi': 'दो चीज़ें मिलकर तय करती हैं: (1) साफ़ नियम (जैसे "ओटीपी माँगना", "पहले पैसे माँगना") जो हर चेतावनी का कारण बताते हैं, और (2) एक छोटा मॉडल जो पहले देखे ठगी वाले मैसेजों से मिलते शब्द पहचानता है।',
    'en': 'Two things decide together: (1) clear rules (like "asks for an OTP" or "asks for money first") that explain every warning, and (2) a small model that notices wording similar to scam messages seen before.',
  },
  'h2': {
    'hi': 'सिर्फ एक संकेत से "ख़तरनाक" नहीं कहा जाता। कम से कम दो नियम मिलने चाहिए।',
    'en': 'One sign alone never says "dangerous". At least two rules must agree.',
  },
  'h3': {
    'hi': 'यह गलत भी हो सकता है। ठगी छूट सकती है और ठीक मैसेज पर भी चेतावनी आ सकती है। शक हो तो पैसे न दें और किसी भरोसेमंद से पूछें।',
    'en': 'It can be wrong. It can miss a scam and can warn about a normal message. If unsure, do not pay and ask someone you trust.',
  },
  'h4': {
    'hi': 'ऐप फ़ाइल की जाँच सिर्फ उसकी इजाज़तों की सूची पढ़ती है। फ़ाइल कभी चलाई नहीं जाती।',
    'en': 'The app-file check only reads its list of permissions. The file is never run.',
  },
  'h5': {
    'hi': 'यह कितना सही है, इसका हिसाब GitHub पर खुला है, गलतियों समेत।',
    'en': 'How well it works is published openly on GitHub, mistakes included.',
  },
  'howTitle': {
    'hi': 'आपका मैसेज कहीं नहीं जाता',
    'en': 'Your message never leaves this phone',
  },
};

String tr(String key, String lang) => _s[key]?[lang] ?? _s[key]?['en'] ?? key;

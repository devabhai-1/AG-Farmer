import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/agro_scope.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';

Future<void> showPolicyDialog(BuildContext context, {required bool terms}) async {
  final s = AgroScope.of(context).s;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: ctx.agroCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ctx.agroSoftFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        terms ? Icons.gavel_rounded : Icons.privacy_tip_rounded,
                        color: ctx.isDark ? AgroColors.mint : AgroColors.deepGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        terms ? s.termsTitle : s.privacyTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ctx.agroText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: terms ? _buildTermsContent(ctx, s) : _buildPrivacyContent(ctx, s),
                  ),
                ),
                const Divider(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ctx.isDark ? AgroColors.nightGold : AgroColors.deepGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(s.ok, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildPrivacyContent(BuildContext ctx, dynamic s) {
  final isHi = s.isHi;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isHi ? 'AG Farmer प्राइवेसी पॉलिसी (Privacy Policy)' : 'AG Farmer Privacy Policy',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ctx.agroText),
      ),
      const SizedBox(height: 8),
      Text(
        isHi
            ? 'अंतिम अपडेट: सितंबर 2026\nAG Farmer ("हम", "हमारा") किसानों और कृषि उत्पादकों के डेटा की सुरक्षा और गोपनीयता के प्रति पूरी तरह समर्पित है।'
            : 'Last Updated: September 2026\nAG Farmer ("we", "our") is deeply committed to protecting the privacy and security of our farmers and users.',
        style: TextStyle(fontSize: 13, color: ctx.agroMuted, height: 1.4),
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '1. एकत्र की जाने वाली जानकारी (Data We Collect)' : '1. Information We Collect'),
      _policyBody(
        ctx,
        isHi
            ? '• व्यक्तिगत जानकारी: आपका नाम, मोबाइल नंबर, ईमेल आईडी, उम्र (18+) और राज्य/पता जो प्रोफाइल बनाते समय दिया जाता है।\n'
              '• कृषि डेटा: आपके द्वारा चुनी गई फसलें, खेत के दैनिक नोट्स (Daily Logs), और AI चैट परामर्श।\n'
              '• तकनीकी व एनालिटिक्स डेटा: ऐप प्रदर्शन और सुरक्षा विश्लेषण (सुरक्षित क्लाउड सेवाओं के माध्यम से)।'
            : '• Personal Data: Name, mobile number, email, age (18+), and state/address provided during profile setup.\n'
              '• Agricultural Data: Selected crops, field logs, and AI consultation queries.\n'
              '• Technical & Usage Data: App performance and security analytics via secure cloud services.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '2. डेटा का उपयोग (How We Use Your Data)' : '2. How We Use Data'),
      _policyBody(
        ctx,
        isHi
            ? '• आपकी फसल के अनुसार सटीक AI सलाह और दैनिक कोर्स उपलब्ध कराने के लिए।\n'
              '• लाइव सपोर्ट और तकनीकी सहायता प्रदान करने के लिए।\n'
              '• हम आपका व्यक्तिगत डेटा कभी भी किसी तीसरे पक्ष को विज्ञापनों के लिए नहीं बेचते हैं।'
            : '• To provide personalized AI farming advice and tailored crop courses.\n'
              '• To deliver customer support and live assistance.\n'
              '• We NEVER sell your personal data to third parties for marketing.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '3. थर्ड पार्टी सेवाएं (Third-Party Services)' : '3. Third-Party Services'),
      _policyBody(
        ctx,
        isHi
            ? 'ऐप सुरक्षित क्लाउड सेवाओं का उपयोग करता है:\n'
              '• सुरक्षित लॉगिन व खाता सुरक्षा\n'
              '• एन्क्रिप्टेड क्लाउड स्टोरेज\n'
              '• ऐप प्रदर्शन विश्लेषण\n'
              '• (जहाँ लागू हो) Google Play Services'
            : 'The app uses secure cloud infrastructure for:\n'
              '• Secure sign-in and account protection\n'
              '• Encrypted cloud storage\n'
              '• App performance analytics\n'
              '• Google Play Services where applicable',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '4. खाता व डेटा हटाना (Account & Data Deletion)' : '4. Account & Data Deletion'),
      _policyBody(
        ctx,
        isHi
            ? 'Google Play नीति के अनुसार, उपयोगकर्ता किसी भी समय अपना खाता और संपूर्ण डेटा हटा सकते हैं:\n'
              '1. ऐप के अंदर: "Profile" स्क्रीन पर जाएं और "Delete Account & Data" (खाता हटाएं) पर टैप करें।\n'
              '2. इसके अलावा, आप हमारी वेबसाइट या ईमेल support@agfarmer.app पर अनुरोध भेजकर भी डेटा हटवा सकते हैं।'
            : 'In compliance with Google Play User Data policies, users have the right to request deletion of their account and all associated data:\n'
              '1. In-App: Go to the "Profile" screen and tap "Delete Account & Data".\n'
              '2. Web/Email: You may submit a deletion request to support@agfarmer.app or via our web deletion portal.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '5. बच्चों की गोपनीयता (Children Privacy)' : '5. Children Privacy'),
      _policyBody(
        ctx,
        isHi
            ? 'AG Farmer केवल 18 वर्ष और उससे अधिक आयु के वयस्क किसानों एवं कृषि पेशेवरों के लिए बनाया गया है।'
            : 'AG Farmer is designed for adult farmers and agricultural operators aged 18 and older. We do not knowingly collect data from children under 13.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '6. संपर्क सूत्र (Contact Us)' : '6. Contact & Grievance'),
      _policyBody(
        ctx,
        'Email: support@agfarmer.app\nAG Farmer Operations Team, India',
      ),
    ],
  );
}

Widget _buildTermsContent(BuildContext ctx, dynamic s) {
  final isHi = s.isHi;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isHi ? 'AG Farmer नियम व शर्तें (Terms of Service)' : 'AG Farmer Terms of Service',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ctx.agroText),
      ),
      const SizedBox(height: 8),
      Text(
        isHi
            ? 'AG Farmer का उपयोग करके आप इन शर्तों से सहमत होते हैं:'
            : 'By using AG Farmer, you agree to these Terms of Service:',
        style: TextStyle(fontSize: 13, color: ctx.agroMuted, height: 1.4),
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '1. AI सलाह व अस्वीकरण (AI Advisory Disclaimer)' : '1. AI Advisory Disclaimer'),
      _policyBody(
        ctx,
        isHi
            ? '• AG Farmer एक कृत्रिम बुद्धिमत्ता (AI) आधारित कृषि मार्गदर्शक है।\n'
              '• रासायनिक उर्वरक, कीटनाशक या फफूंदनाशक का छिड़काव करने से पहले हमेशा स्थानीय कृषि विज्ञान केंद्र (KVK), कृषि अधिकारी या निर्माता के लेबल से खुराक की पुष्टि अवश्य करें।\n'
              '• मौसम व मिट्टी की भिन्नता के कारण AI सुझाव संदर्भ के लिए हैं।'
            : '• AG Farmer is an Artificial Intelligence-powered agricultural advisory tool.\n'
              '• Before applying any chemical fertilizer, pesticide, or fungicide, always verify dosages with local agricultural extension officers or the manufacturer bottle label.\n'
              '• AI responses are advisory in nature.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '2. उपयोगकर्ता का आचरण (Acceptable Use)' : '2. Acceptable Use'),
      _policyBody(
        ctx,
        isHi
            ? '• ऐप में किसी भी प्रकार की अभद्र भाषा, अवैध गतिविधि या प्रणाली का दुरुपयोग निषिद्ध है।\n'
              '• गलत या हानिकारक AI प्रतिक्रिया मिलने पर आप सीधे चैट में दिए गए "Report" बटन से रिपोर्ट कर सकते हैं।'
            : '• Unlawful activities, abusive language, or hacking attempts are strictly prohibited.\n'
              '• If you encounter inaccurate or inappropriate AI output, please use the in-app "Report" button on the message card.',
      ),
      const SizedBox(height: 14),
      _policyHeading(ctx, isHi ? '3. सदस्यता और शुल्क (Subscriptions)' : '3. Subscriptions & Access'),
      _policyBody(
        ctx,
        isHi
            ? 'निःशुल्क और प्रीमियम योजनाओं की विशेषताएं ऐप में स्पष्ट रूप से दर्शाई गई हैं। योजनाएं नियमों के अधीन हैं।'
            : 'Features for free and premium plans are clearly described within the app.',
      ),
    ],
  );
}

Widget _policyHeading(BuildContext ctx, String title) {
  return Text(
    title,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: ctx.isDark ? AgroColors.softGold : AgroColors.deepGreen,
    ),
  );
}

Widget _policyBody(BuildContext ctx, String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, color: ctx.agroMuted, height: 1.45),
    ),
  );
}

class PolicyCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const PolicyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          activeColor: AgroColors.leaf,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: context.agroText,
                  fontSize: 13,
                  height: 1.35,
                ),
                children: [
                  TextSpan(text: '${s.agreePrefix} '),
                  TextSpan(
                    text: s.termsTitle,
                    style: const TextStyle(
                      color: AgroColors.leaf,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => showPolicyDialog(context, terms: true),
                  ),
                  TextSpan(text: ' ${s.andWord} '),
                  TextSpan(
                    text: s.privacyTitle,
                    style: const TextStyle(
                      color: AgroColors.leaf,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => showPolicyDialog(context, terms: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: context.isDark
                    ? const [Color(0xFF031626), Color(0xFF082F49), Color(0xFF0369A1)]
                    : const [AgroColors.forest, AgroColors.deepGreen, AgroColors.mint],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandLogo(size: 48, radius: 14),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [child],
            ),
          ),
        ],
      ),
    );
  }
}

class AgeDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const AgeDropdown({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final ages = List<int>.generate(63, (i) => 18 + i); // 18..80

    return DropdownButtonFormField<int>(
      key: ValueKey('age_$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: s.ageLabel),
      dropdownColor: context.agroCard,
      items: ages
          .map(
            (age) => DropdownMenuItem<int>(
              value: age,
              child: Text('$age'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

 import '../services/agro_ai_service.dart';

enum AppLang {
  english,
  hindi;

  String get code => this == AppLang.hindi ? 'hi' : 'en';
  String get labelEn => this == AppLang.hindi ? 'Hindi' : 'English';
  String get labelHi => this == AppLang.hindi ? 'हिन्दी' : 'अंग्रेज़ी';
  String get nativeLabel => this == AppLang.hindi ? 'हिन्दी' : 'English';

  static AppLang fromCode(String? code) {
    if (code == 'hi') return AppLang.hindi;
    return AppLang.english;
  }
}

class S {
  final AppLang lang;
  const S(this.lang);

  bool get isHi => lang == AppLang.hindi;

  String get appName => 'AG Farmer';
  String get chooseLanguage => isHi ? 'भाषा चुनें' : 'Choose Language';
  String get languageTitle => isHi ? 'अपनी भाषा चुनें' : 'Select your language';
  String get languageSubtitle => isHi
      ? 'पूरा ऐप, चैट और फसल कोर्स इसी भाषा में चलेगा'
      : 'The full app, chat and crop courses will use this language';
  String get continueBtn => isHi ? 'आगे बढ़ें' : 'Continue';
  String get changeLanguageLater => isHi
      ? 'बाद में होम से भाषा बदल सकते हैं'
      : 'You can change language later from Home';

  String get navHome => isHi ? 'होम' : 'Home';
  String get navChat => isHi ? 'चैट' : 'Chat';
  String get navCourse => isHi ? 'कोर्स' : 'Course';
  String get navJankari => isHi ? 'जानकारी' : 'Info';
  String get navProfile => isHi ? 'प्रोफाइल' : 'Profile';

  String get profileTitle => isHi ? 'प्रोफाइल' : 'Profile';
  String get profileSubtitle => isHi
      ? 'अकाउंट, फसल चयन और सब्सक्रिप्शन'
      : 'Account, crop picks & subscription';
  String get myProfile => isHi ? 'मेरी प्रोफाइल' : 'My Profile';
  String get farmerName => isHi ? 'किसान का नाम' : 'Farmer name';
  String get phoneNumber =>
      isHi ? 'मोबाइल नंबर (ज़रूरी)' : 'Mobile number (required)';
  String get saveProfile => isHi ? 'प्रोफाइल सेव करें' : 'Save Profile';
  String get profileSaved => isHi ? 'प्रोफाइल सेव हो गई' : 'Profile saved';
  String get manageSubscription =>
      isHi ? 'सब्सक्रिप्शन मैनेज करें' : 'Manage Subscription';
  String get currentPlan => isHi ? 'वर्तमान प्लान' : 'Current Plan';
  String get freePlan => isHi ? 'फ्री' : 'Free';
  String get selectCrops => isHi ? 'फसलें चुनें' : 'Select Crops';
  String get selectedCrops => isHi ? 'चयनित फसलें' : 'Selected Crops';
  String get noCropsSelected =>
      isHi ? 'अभी कोई फसल नहीं चुनी' : 'No crops selected yet';
  String get subscriptionTitle =>
      isHi ? 'सब्सक्रिप्शन प्लान' : 'Subscription Plans';
  String get subscriptionSubtitle => isHi
      ? '₹299 लहसुन स्पेशल · ₹599 अफीम स्पेशल · ₹2650 सुपर'
      : '₹299 Lasun Special · ₹599 Afim Special · ₹2650 Super';
  String get perMonth => isHi ? '/30 दिन ऑटोपे' : '/30 day autopay';
  String get subscribeNow => isHi ? 'पेमेंट करें' : 'Pay now';
  String get cycleMonthly => isHi ? 'महीना' : 'Monthly';
  String get cycleFour => isHi ? '4 महीने' : '4 months';
  String get cycleYear => isHi ? '1 साल' : '1 year';
  String get off10 => isHi ? '10% छूट' : '10% off';
  String get off25 => isHi ? '25% छूट' : '25% off';
  String get payOnce => isHi ? 'एक बार' : 'One time';
  String get monthlyAutopay => isHi ? 'ऑटोपे' : 'Autopay';
  String get paymentCancelled =>
      isHi ? 'पेमेंट रद्द हो गई' : 'Payment cancelled';
  String get paymentFailed => isHi
      ? 'पेमेंट पूरा नहीं हुआ। फिर कोशिश करें।'
      : 'Payment did not finish. Please try again.';
  String get activePlan => isHi ? 'सक्रिय प्लान' : 'Active Plan';
  String get unlockWith => isHi ? 'अनलॉक:' : 'Unlock with:';
  String get lockedCrop => isHi ? 'लॉक' : 'Locked';
  String get targetBadge => isHi ? 'टॉप टारगेट' : 'TOP TARGET';
  String get premiumBadge => isHi ? 'प्रीमियम' : 'PREMIUM';
  String get lasunSpecialBadge => isHi ? 'लहसुन स्पेशल' : 'Lasun Special';
  String get afimSpecialBadge => isHi ? 'अफीम स्पेशल' : 'Afim Special';
  String get chatOnlyBadge => isHi ? 'सिर्फ चैट' : 'Chat only';
  String get liveAnalysis => isHi ? 'लाइव एनालिसिस' : 'Live Analysis';
  String get searchCrops => isHi ? 'फसल खोजें...' : 'Search crops...';
  String get cropCatalogTitle => isHi ? '100+ फसल कैटलॉग' : '100+ Crop Catalog';
  String get saveCropSelection => isHi ? 'चयन सेव करें' : 'Save Selection';
  String get cropsSaved => isHi ? 'फसल चयन सेव हो गया' : 'Crop selection saved';
  String get needHigherPlan =>
      isHi ? 'यह फसल ऊँचे प्लान में मिलेगी' : 'This crop needs a higher plan';
  String get afimFocusNote => isHi
      ? '₹299 = सब कोर्स (अफीम छोड़कर) · ₹599 = अफीम सहित सब'
      : '₹299 = all courses except Afim · ₹599 = includes Afim';
  String get coursePlanGateTitle =>
      isHi ? 'फसल कोर्स प्लान में मिलेगा' : 'Crop courses need a plan';
  String get coursePlanGateSub => isHi
      ? 'कोर्स के लिए लहसुन स्पेशल (₹299) या अफीम स्पेशल (₹599) लें।'
      : 'For courses take Lasun Special (₹299) or Afim Special (₹599).';
  String get coursePlanGateCta => isHi ? 'प्लान देखें' : 'View plans';
  String get cancelPlan => isHi ? 'प्लान हटाएँ' : 'Remove Plan';
  String get editProfile => isHi ? 'प्रोफाइल संपादित करें' : 'Edit Profile';
  String get nameHint => isHi ? 'जैसे: रामलाल पटेल' : 'e.g. Ramlal Patel';
  String get phoneHint => isHi ? '10 अंकों का मोबाइल' : '10-digit mobile';

  String planName(String id) {
    switch (id) {
      case 'local':
        return isHi ? 'चैट प्लान' : 'Chat Plan';
      case 'advanced':
        return isHi ? 'लहसुन स्पेशल' : 'Lasun Special';
      case 'all':
        return isHi ? 'अफीम स्पेशल' : 'Afim Special';
      case 'super':
        return isHi ? 'अफीम सुपर प्रो' : 'Afim Super Pro';
      case 'distributor':
        return isHi ? 'डिस्ट्रीब्यूटर प्रो' : 'Distributor Pro';
      default:
        return freePlan;
    }
  }

  String planDesc(String id) {
    switch (id) {
      case 'local':
        return isHi
            ? 'सिर्फ AI चैट — फसल कोर्स सिस्टम नहीं'
            : 'AI chat only — no crop course system';
      case 'advanced':
        return isHi
            ? 'सभी फसलों के कोर्स + चैट (अफीम छोड़कर)'
            : 'All crop courses + chat (except Afim)';
      case 'all':
        return isHi
            ? 'सभी फसलें अफीम सहित + चैट'
            : 'All crops including Afim + chat';
      case 'super':
        return isHi
            ? 'अफीम सहित सब + 2× ज़्यादा AI, लाइव आवाज़ और वीडियो कॉल'
            : 'Everything incl. Afim + 2× more AI, live voice and video call';
      case 'distributor':
        return isHi
            ? 'सभी फसलें + अनलिमिटेड टॉप AI मॉडल'
            : 'All crops + unlimited top AI models';
      default:
        return '';
    }
  }

  String priceLabel(int inr) => isHi ? '₹$inr' : '₹$inr';

  String cropsCount(int n) => isHi ? '$n फसल चयनित' : '$n crops selected';

  String get homeSubtitle => isHi
      ? 'स्मार्ट खेती, बेहतर मार्गदर्शन'
      : 'Smart farming, better guidance';
  String get welcomeFarmer => isHi ? 'नमस्ते किसान भाई' : 'Welcome Farmer';
  String get homeHero => isHi
      ? 'यह किसानों के लिए बेहतर उपज और बेहतर मार्गदर्शन के लिए डिज़ाइन किया गया है'
      : 'Designed for farmers for better yield and expert agricultural guidance.';
  String get homeHeroSub => isHi
      ? 'फसल ट्रैक में डेली डेटा भरें — सुझाव और रिपोर्ट अपने आप बनेगी।'
      : 'Log daily data in crop track — suggestions and reports build automatically.';
  String get homeCropTopicsTitle =>
      isHi ? 'फसल के हिसाब से सवाल' : 'Questions by crop';
  String get askAgFarmer => isHi ? 'AG Farmer से पूछें' : 'Ask AG Farmer';
  /// Legacy Agro GPT key used by older home screen copy.
  String get askAgroGpt => askAgFarmer;
  String get fasalCourse => isHi ? 'फसल कोर्स' : 'Crop Course';
  String get premiumFeatures => isHi ? 'खास फीचर्स' : 'Key Features';
  String get featureChatTitle => isHi ? 'AI खेती चैट' : 'AI Farming Chat';
  String get featureChatSub => isHi
      ? 'फसल, मौसम, खाद और रोग की सलाह'
      : 'Crop, weather, fertilizer & disease advice';
  String get featureCourseTitle => isHi ? 'फसल कोर्स' : 'Crop Course';
  String get featureCourseSub => isHi
      ? 'डेली डेटा, सुझाव और रिपोर्ट'
      : 'Daily data, suggestions and reports';
  String get jankariSubtitle => isHi
      ? 'हर फसल की जानकारी, रोग नाम और सुझाव'
      : 'Crop facts, disease names and tips';
  String get allCropsFilter => isHi ? 'सभी फसलें' : 'All crops';
  String get relatedPostsTitle =>
      isHi ? 'और संबंधित पोस्ट' : 'More related posts';
  String get seeAllRelated => isHi ? 'सभी देखें' : 'See all';
  String relatedCropTitle(String crop) =>
      isHi ? '$crop की सभी पोस्ट' : 'All $crop posts';
  String afimStageLabel(String id) {
    switch (id) {
      case 'sowing':
        return isHi ? 'शुरुआत में' : 'At the start';
      case 'day10':
        return isHi ? '10–30 दिन' : 'Day 10–30';
      case 'day30':
        return isHi ? '30–60 दिन' : 'Day 30–60';
      case 'day60':
        return isHi ? '60+ दिन' : 'Day 60+';
      default:
        return isHi ? 'सभी' : 'All';
    }
  }

  String lasunStageLabel(String id) {
    switch (id) {
      case 'day1':
        return isHi ? 'शुरुआत में' : 'At the start';
      case 'day45':
        return isHi ? '30–60 दिन' : 'Day 30–60';
      case 'day60':
        return isHi ? '60+ दिन' : 'Day 60+';
      case 'end':
        return isHi ? 'पकना / खुदाई' : 'Ripen / harvest';
      default:
        return isHi ? 'सभी' : 'All';
    }
  }

  String get noJankariPosts =>
      isHi ? 'इस फ़िल्टर में पोस्ट नहीं' : 'No posts for this filter';
  String get searchJankari =>
      isHi ? 'खोजें... यूरिया, buwai, bimari' : 'Search... urea, buwai, bimari';
  String get searchJankariFail =>
      isHi ? 'खोज अभी नहीं हो सकी' : 'Search could not finish';
  String get courseLoginGateTitle =>
      isHi ? 'आपका प्रीमियम फसल कोर्स' : 'Your premium crop course';
  String get courseLoginGateSub => isHi
      ? 'लॉगिन करें और अपनी फसल का स्पेशल मेंबर चैट खोलें — शुरू से कटाई तक गाइड'
      : 'Sign in to unlock your crop’s special member chat — guidance from start to harvest';
  String get courseLoginBadge =>
      isHi ? '★ मेंबर एक्सक्लूसिव' : '★ MEMBER EXCLUSIVE';
  String get courseLoginCta =>
      isHi ? 'प्रीमियम एक्सेस खोलें' : 'Unlock premium access';
  List<String> get courseLoginBenefits => isHi
      ? const [
          'एक फसल = एक प्राइवेट कोर्स चैट',
          'फोटो भेजकर तुरंत सलाह',
          'कैलेंडर में हर तारीख का रिकॉर्ड',
        ]
      : const [
          'One crop = one private course chat',
          'Send photos for instant advice',
          'Calendar log of every date',
        ];
  String get pickCourseCropSub => isHi
      ? 'एक फसल चुनें (एक फसल = एक कोर्स चैट)'
      : 'Pick one crop (one crop = one course chat)';
  String get oneCropOneChat => isHi ? 'एक फसल · एक चैट' : 'One crop · one chat';
  String get fasalCourseChatSub => isHi
      ? 'शुरुआत की तारीख से चालू — अंत तब जब बंद करें'
      : 'Runs from start date — ends only when closed';
  String get courseClosedInputHint => isHi
      ? 'कोर्स बंद है — सिर्फ पुराना चैट देख सकते हैं'
      : 'Course closed — you can only view past chat';
  String get adminCourseSection =>
      isHi ? 'फसल कोर्स (एडमिन)' : 'Crop courses (admin)';
  String get adminSendClosePrompt =>
      isHi ? 'बंद / जारी रखें भेजें' : 'Send close / continue';
  String get adminForceCloseCourse => isHi ? 'अभी बंद करें' : 'Close now';
  String get adminClosePromptSent => isHi
      ? 'किसान को बंद/जारी रखने का मैसेज भेज दिया'
      : 'Close/continue message sent to farmer';
  String get adminCourseClosedNow =>
      isHi ? 'कोर्स बंद कर दिया गया' : 'Course closed';
  String get closeThisCourse => isHi ? 'कोर्स बंद करें' : 'Close this course';
  String get closeTypeTitle => isHi ? 'STOP लिखें' : 'Type STOP';
  String get closeTypeBody => isHi
      ? 'कोर्स बंद करने के लिए बॉक्स में Stop लिखें। लिखने के बाद कन्फर्म करें।'
      : 'Type Stop in the box to close the course. Confirm after you type it.';
  String get changeCourseCrop => isHi ? 'फसल बदलें' : 'Change crop';
  String get courseChatHint =>
      isHi ? 'इस फसल के बारे में पूछें…' : 'Ask about this crop…';
  String get addCourseCrop => isHi ? 'और फसल जोड़ें' : 'Add crop';
  String get courseAttach => isHi ? 'अटैच करें' : 'Attach';
  String get attachCameraPhoto => isHi ? 'कैमरा फोटो' : 'Camera photo';
  String get attachGalleryPhoto => isHi ? 'गैलरी फोटो' : 'Gallery photo';
  String get attachCameraVideo => isHi ? 'कैमरा वीडियो' : 'Camera video';
  String get attachGalleryVideo => isHi ? 'गैलरी वीडियो' : 'Gallery video';
  String get attachVoiceFile =>
      isHi ? 'वॉइस / ऑडियो फाइल' : 'Voice / audio file';
  String get attachAnyFile => isHi ? 'अन्य फाइल' : 'Other file';
  String get fileTooLarge => isHi
      ? 'फाइल 20 MB से बड़ी नहीं हो सकती'
      : 'File cannot be larger than 20 MB';
  String get removeAttachment => isHi ? 'हटाएँ' : 'Remove';
  String get courseCalendarTitle => isHi ? 'कोर्स कैलेंडर' : 'Course calendar';
  String get courseCalendarTooltip =>
      isHi ? 'किस तारीख को क्या हुआ' : 'What happened on which date';
  String get courseCalAddNote => isHi ? 'नोट जोड़ें' : 'Add note';
  String get courseCalNoteTitle => isHi ? 'शीर्षक' : 'Title';
  String get courseCalNoteDetail =>
      isHi ? 'विवरण (वैकल्पिक)' : 'Detail (optional)';
  String get courseCalPickDay => isHi ? 'तारीख चुनें' : 'Pick a date';
  String courseCalDayTitle(String d) =>
      isHi ? '$d को क्या हुआ' : 'Activity on $d';
  String courseCalDayChatTitle(String d) =>
      isHi ? '$d का पूरा चैट' : 'Full chat for $d';
  String courseCalMsgCount(int n) => isHi ? '$n संदेश' : '$n messages';
  String get courseCalEmptyDay =>
      isHi ? 'इस दिन कोई चैट नहीं' : 'No chat on this day';
  String get courseCalDone => isHi ? 'हो चुका' : 'Done';
  String get courseCalAhead =>
      isHi ? 'आगे क्या करना है' : 'What to do next';
  String get courseCalAheadHint =>
      isHi ? 'आज सहित अगले 15 दिन' : 'Today and the next 15 days';
  String courseCalAheadWait(int have, int need) => isHi
      ? '$need दिन का विश्लेषण होने पर आगे के 15 दिन बनेंगे। अभी $have/$need।'
      : 'The next 15 days open after $need analyzed days. $have/$need so far.';
  String get courseCalAheadEmpty =>
      isHi ? 'इस दिन कोई काम नहीं' : 'Nothing scheduled this day';
  String get courseCalAheadLoading =>
      isHi ? '15 दिन का शेड्यूल बन रहा है' : 'Building the 15-day schedule';
  String get courseCalAdvisorNote => isHi
      ? 'दवाई और AI की राय के लिए एक बार स्थानीय सलाहकार से पूछना जरूरी है।'
      : 'For medicine and the AI’s advice, ask a local advisor once. This is necessary.';
  String get openJankari => isHi ? 'फसल जानकारी' : 'Crop Info';
  String get seeMoreArticle => isHi ? 'पूरा आर्टिकल देखें' : 'See full article';
  String get jankariLoginTitle =>
      isHi ? 'पूरा ज्ञान — मेंबरों के लिए' : 'Full knowledge — for members';
  String get jankariLoginBody => isHi
      ? 'प्रीव्यू मुफ़्त है। लंबा एक्सपर्ट आर्टिकल पढ़ने के लिए लॉगिन करें — सुरक्षित और स्पेशल एक्सेस।'
      : 'Preview is free. Sign in for the full expert article — secure, special member access.';
  String get jankariLoginBadge => isHi ? '★ नॉलेज वॉल्ट' : '★ KNOWLEDGE VAULT';
  String get jankariLoginCta =>
      isHi ? 'आर्टिकल अनलॉक करें' : 'Unlock full article';
  List<String> get jankariLoginBenefits => isHi
      ? const [
          'लंबे एक्सपर्ट आर्टिकल',
          'रोग नाम + इलाज डिटेल',
          'आपका डेटा सुरक्षित',
        ]
      : const [
          'Long expert articles',
          'Disease names + treatment detail',
          'Your data stays secure',
        ];
  String readMinutesLabel(int m) => isHi ? '$m मिनट पढ़ें' : '$m min read';
  String get jankariArticleFooter => isHi
      ? 'यह जानकारी सामान्य मार्गदर्शन है। स्प्रे/खाद की सटीक डोज अपने क्षेत्र की सलाह या फसल कोर्स चैट से लें।'
      : 'This is general guidance. Confirm spray/fertilizer doses with local advice or Crop Course chat.';
  String get featureDailyTitle => isHi ? 'डेली डेटा इंजन' : 'Daily Data Engine';
  String get featureDailySub => isHi
      ? 'रोज़ के डेटा से सुझाव और रिपोर्ट बनती है'
      : 'Suggestions and reports from daily field data';
  String get premiumThemeActive => isHi ? 'थीम सक्रिय' : 'Theme Active';
  String get premiumThemeSub => isHi
      ? 'फॉरेस्ट ग्रीन + गोल्ड एग्री डिज़ाइन'
      : 'Forest green + gold agri design system';
  String get changeLanguage => isHi ? 'भाषा बदलें' : 'Change Language';
  String get premiumThemeBar => isHi ? 'थीम' : 'THEME';
  String get themeSettings => isHi ? 'थीम सेटिंग्स' : 'Theme Settings';
  String get themeSettingsSub => isHi
      ? 'ऑटो / लाइट / डार्क — सिस्टम के हिसाब से भी'
      : 'Auto / Light / Dark — follows system too';
  String get themeAuto => isHi ? 'ऑटो' : 'Auto';
  String get themeLight => isHi ? 'लाइट' : 'Light';
  String get themeDark => isHi ? 'डार्क' : 'Dark';

  // Auth
  String get loginTitle => isHi ? 'वापसी पर स्वागत है' : 'Welcome back';
  String get loginSubtitle => isHi
      ? 'अपने प्रीमियम AG Farmer अकाउंट में साइन इन करें'
      : 'Sign in to your premium AG Farmer account';
  String get loginBadge =>
      isHi ? '★ सुरक्षित मेंबर लॉगिन' : '★ SECURE MEMBER LOGIN';
  String get loginBtn => isHi ? 'लॉगिन करें' : 'Login';
  String get loginContinueSecure =>
      isHi ? 'सुरक्षित रूप से जारी रखें' : 'Continue securely';
  String get logoutBtn => isHi ? 'लॉगआउट' : 'Logout';
  String get createAccountTitle => isHi ? 'अकाउंट बनाएँ' : 'Create Account';
  String get createAccountSubtitle => isHi
      ? 'नाम, ईमेल, पता, नंबर और पासवर्ड भरें'
      : 'Fill name, email, address, phone and password';
  String get createAccountBtn => isHi ? 'अकाउंट बनाएँ' : 'Create Account';
  String get createAccountCta =>
      isHi ? 'नया अकाउंट बनाएँ' : 'Create new account';
  String get alreadyHaveAccount =>
      isHi ? 'पहले से अकाउंट है? लॉगिन करें' : 'Already have an account? Login';
  String get emailLabel => isHi ? 'ईमेल / अकाउंट' : 'Email / Account';
  String get addressLabel => isHi ? 'पता' : 'Address';
  String get passwordLabel => isHi ? 'पासवर्ड' : 'Password';
  String get confirmPasswordLabel =>
      isHi ? 'पासवर्ड कन्फर्म करें' : 'Confirm Password';
  String get forgotPassword => isHi ? 'पासवर्ड भूल गए?' : 'Forgot password?';
  String get forgotPasswordTitle => isHi ? 'पासवर्ड रीसेट' : 'Reset Password';
  String get forgotPasswordSubtitle => isHi
      ? 'अपना रजिस्टर्ड ईमेल डालें — रीसेट लिंक उसी ईमेल पर भेजी जाएगी'
      : 'Enter your registered email — a reset link will be sent there';
  String get sendResetOtpBtn =>
      isHi ? 'ईमेल पर OTP भेजें' : 'Send OTP to Email';
  String get sendResetLinkBtn => isHi ? 'रीसेट लिंक भेजें' : 'Send Reset Link';
  String get resendResetLinkBtn => isHi ? 'लिंक दोबारा भेजें' : 'Resend link';
  String get backToLoginBtn => isHi ? 'लॉगिन पर वापस जाएँ' : 'Back to Login';
  String get resetLinkSentTitle => isHi ? 'ईमेल भेज दी गई!' : 'Email sent!';
  String resetLinkSentBody(String masked) => isHi
      ? '$masked पर पासवर्ड रीसेट लिंक भेजी गई है। इनबॉक्स और स्पैम दोनों देखें। लिंक खोलकर नया पासवर्ड सेट करें, फिर उसी ईमेल से लॉगिन करें — आपका पुराना डेटा वैसा ही रहेगा।'
      : 'A password reset link was sent to $masked. Check the inbox and the spam folder. Open the link, set a new password, then login with the same email — your old data stays.';
  String get newPasswordLabel => isHi ? 'नया पासवर्ड' : 'New Password';
  String get resetPasswordBtn => isHi ? 'पासवर्ड बदलें' : 'Change Password';
  String get passwordResetDone => isHi
      ? 'पासवर्ड बदल गया! अब लॉगिन करें'
      : 'Password updated! Please login';
  String otpSentToMasked(String masked) =>
      isHi ? 'OTP $masked पर भेज दिया गया' : 'OTP sent to $masked';
  String get errAccountNotFound =>
      isHi ? 'यह ईमेल रजिस्टर नहीं है' : 'This email is not registered';
  String get errNoPhoneOnAccount => isHi
      ? 'अकाउंट पर मोबाइल नंबर नहीं मिला'
      : 'No mobile number on this account';
  String get errEmailSendFailed => isHi
      ? 'ईमेल नहीं भेज सका। थोड़ी देर बाद कोशिश करें'
      : 'Could not send email. Please try again later';
  String get errEmailAuthDisabled => isHi
      ? 'ईमेल लॉगिन अभी उपलब्ध नहीं है। थोड़ी देर बाद कोशिश करें।'
      : 'Email login is not available right now. Please try again later.';
  String get errOtpExpired =>
      isHi ? 'OTP समाप्त हो गया, दोबारा भेजें' : 'OTP expired, please resend';
  String get ageLabel => isHi ? 'उम्र चुनें' : 'Select Age';
  String get continueWithGoogle =>
      isHi ? 'Google से जारी रखें' : 'Continue with Google';
  String get orContinueWith => isHi ? 'या' : 'OR';
  String get orDivider => orContinueWith;
  String get fillAllFields =>
      isHi ? 'कृपया सभी फ़ील्ड भरें' : 'Please fill all fields';
  String get passwordMismatch =>
      isHi ? 'पासवर्ड मेल नहीं खा रहे' : 'Passwords do not match';
  String get acceptPolicyFirst => isHi
      ? 'पहले Terms और Privacy Policy स्वीकार करें'
      : 'Please accept Terms & Privacy Policy first';
  String get accountCreated => isHi ? 'अकाउंट बन गया!' : 'Account created!';
  String get completeProfileTitle =>
      isHi ? 'प्रोफाइल पूरा करें' : 'Complete Profile';
  String get completeProfileSubtitle => isHi
      ? 'Google से नाम/ईमेल मिल गया। अब नंबर, उम्र और पॉलिसी चाहिए।'
      : 'Name/email from Google. Now add phone, age and policy.';
  String get googleAccountInfo =>
      isHi ? 'Google अकाउंट जानकारी' : 'Google account info';
  String get agreePrefix => isHi ? 'मैं सहमत हूँ' : 'I agree to';
  String get andWord => isHi ? 'और' : 'and';
  String get termsTitle => isHi ? 'नियम व शर्तें' : 'Terms & Conditions';
  String get privacyTitle => isHi ? 'प्राइवेसी पॉलिसी' : 'Privacy Policy';
  String get ok => isHi ? 'ठीक है' : 'OK';
  String get loginRequired =>
      isHi ? 'प्रोफाइल देखने के लिए लॉगिन करें' : 'Login to view your profile';
  String get welcomeBack => isHi ? 'वापसी पर स्वागत है' : 'Welcome back';
  String get signedInAs => isHi ? 'साइन इन:' : 'Signed in:';

  String get termsBody => isHi
      ? 'AG Farmer सेवाओं का उपयोग करते हुए आप सहमत हैं कि दी गई जानकारी सही है, सब्सक्रिप्शन नियमों का पालन करेंगे, और ऐप का उपयोग कानूनी कृषि मार्गदर्शन के लिए करेंगे। गलत जानकारी या दुरुपयोग पर अकाउंट बंद हो सकता है।'
      : 'By using AG Farmer you agree that provided information is accurate, you will follow subscription rules, and use the app for lawful agricultural guidance. Misuse may lead to account suspension.';

  String get privacyBody => isHi
      ? 'हम आपका नाम, ईमेल, नंबर, उम्र और फसल पसंद सुरक्षित रखते हैं ताकि कोर्स और सलाह बेहतर मिल सके। हम आपकी जानकारी बिना अनुमति तीसरे पक्ष को नहीं बेचते।'
      : 'We store your name, email, phone, age and crop preferences securely to improve courses and advice. We do not sell your data to third parties without consent.';

  String get phoneLoginTitle =>
      isHi ? 'मोबाइल नंबर से लॉगिन' : 'Login with Mobile Number';
  String get phoneLoginSubtitle => isHi
      ? 'लॉगिन या नया खाता बनाने के लिए अपना 10 अंकों का नंबर दर्ज करें'
      : 'Enter your 10-digit number to log in or create account';
  String get mobileNumberLabel => isHi ? 'मोबाइल नंबर' : 'Mobile Number';
  String get enterMobileNumber =>
      isHi ? '10 अंकों का मोबाइल नंबर डालें' : 'Enter 10-digit mobile number';
  String get sendOtpBtn => isHi ? 'OTP प्राप्त करें' : 'Get OTP';
  String get sendingOtp => isHi ? 'OTP भेजा जा रहा है...' : 'Sending OTP...';
  String get otpTitle => isHi ? 'OTP सत्यापन' : 'OTP Verification';
  String otpSubtitle(String phone) => isHi
      ? 'हमने +91 $phone पर 6 अंकों का OTP भेजा है'
      : 'We sent a 6-digit OTP to +91 $phone';
  String get enterOtpLabel =>
      isHi ? '6 अंकों का OTP दर्ज करें' : 'Enter 6-digit OTP';
  String get verifyOtpBtn =>
      isHi ? 'वेरिफाई करें और लॉगिन करें' : 'Verify & Login';
  String get resendOtpBtn => isHi ? 'OTP दोबारा भेजें' : 'Resend OTP';
  String get changeEmailBtn => isHi ? 'ईमेल बदलें' : 'Change Email';
  String resendOtpIn(int sec) =>
      isHi ? '$sec सेकंड में दोबारा भेजें' : 'Resend in $sec s';
  String get changePhoneBtn => isHi ? 'नंबर बदलें' : 'Change Number';
  String get farmerNameOptional =>
      isHi ? 'किसान का नाम (वैकल्पिक)' : 'Farmer Name (Optional)';
  String get farmerNameHintExample =>
      isHi ? 'जैसे: रामलाल पटेल' : 'e.g. Ramlal Patel';
  String get loginSuccess =>
      isHi ? 'सफलतापूर्वक लॉगिन हो गया!' : 'Logged in successfully!';

  String get errInvalidPhone => isHi
      ? 'कृपया 10 अंकों का सही मोबाइल नंबर दर्ज करें'
      : 'Please enter a valid 10-digit mobile number';
  String get errInvalidOtp => isHi
      ? 'कृपया 6 अंकों का सही OTP कोड दर्ज करें'
      : 'Please enter a valid 6-digit OTP code';
  String get errSessionExpired => isHi
      ? 'OTP सत्र समाप्त हो गया, कृपया दोबारा भेजें'
      : 'OTP session expired, please resend';
  String get errTooManyRequests => isHi
      ? 'बहुत अधिक प्रयास हुए। कृपया थोड़ी देर बाद पुनः प्रयास करें।'
      : 'Too many attempts. Please try again later.';
  String get errQuotaExceeded => isHi
      ? 'SMS सीमा समाप्त हो गई है। कृपया बाद में प्रयास करें।'
      : 'SMS quota exceeded. Please try later.';

  String get errEmailInUse => isHi
      ? 'इस ईमेल से पहले ही एक खाता है। एक ईमेल से एक ही खाता बन सकता है।'
      : 'This email already has an account. One email can create only one account.';
  String get errAccountPending => isHi
      ? 'यह खाता डिलीट के लिए है। डेटा 30 दिन बाद हटेगा। इस ईमेल से नया खाता नहीं बन सकता।'
      : 'This account is scheduled for deletion. Data is removed after 30 days. This email cannot create a new account.';
  String get errInvalidEmail => isHi ? 'ईमेल सही नहीं है' : 'Invalid email';
  String get errWeakPassword => isHi
      ? 'पासवर्ड कम से कम 6 अक्षर का हो'
      : 'Password must be at least 6 characters';
  String get errBadCredentials =>
      isHi ? 'ईमेल या पासवर्ड गलत है' : 'Wrong email or password';
  String get errNetwork => isHi ? 'नेटवर्क समस्या है' : 'Network error';
  String get errGeneric => isHi ? 'कुछ गलत हो गया' : 'Something went wrong';

  // Account Deletion (Google Play Compliance)
  String get deleteAccountBtn =>
      isHi ? 'खाता और डेटा हटाएं' : 'Delete Account & Data';
  String get deleteAccountTitle => isHi ? 'खाता हटाएं?' : 'Delete account?';
  String get deleteAccountWarning => isHi
      ? 'खाता अभी नहीं मिटेगा। आपका डेटा 30 दिन तक Firebase में रहेगा, फिर अपने आप हट जाएगा।'
      : 'The account is not erased now. Your data stays in Firebase for 30 days, then it is removed.';
  String get deleteAccountConfirm => isHi ? 'कन्फर्म' : 'Confirm';
  String get deleteAccountCancel => isHi ? 'रद्द करें' : 'Cancel';
  String get deleteTypeTitle => isHi ? 'DELETE लिखें' : 'Type DELETE';
  String get deleteTypeBody => isHi
      ? 'आगे बढ़ने के लिए बॉक्स में delete लिखें।'
      : 'Type delete in the box to continue.';
  String get deleteFinalTitle => isHi ? 'अंतिम कन्फर्म' : 'Final confirm';
  String get deleteFinalBody => isHi
      ? 'कन्फर्म करने पर खाता 30 दिन बाद मिटेगा। तब तक डेटा Firebase में रहेगा।'
      : 'Confirm and the account is erased after 30 days. Until then the data stays in Firebase.';
  String get deleteAccountSuccess => isHi
      ? 'खाता डिलीट के लिए चिह्नित हो गया। डेटा 30 दिन बाद हटेगा।'
      : 'Account marked for deletion. Data is removed after 30 days.';
  String get deleteAccountReauth => isHi
      ? 'सुरक्षा कारणों से, कृपया पहले फिर से लॉगिन करें और फिर खाता हटाएं।'
      : 'For security, please log out, log in again, and retry deleting your account.';
  String get deletingAccount =>
      isHi ? 'खाता चिह्नित हो रहा है...' : 'Scheduling account deletion...';
  String get logoutConfirmTitle => isHi ? 'लॉगआउट करें?' : 'Log out?';
  String get logoutConfirmBody => isHi
      ? 'क्या आप इस खाते से लॉगआउट करना चाहते हैं?'
      : 'Do you want to log out of this account?';
  String get logoutConfirmBtn => isHi ? 'लॉगआउट' : 'Log out';
  String get dangerZoneTitle =>
      isHi ? 'अकाउंट सेटिंग्स (Danger Zone)' : 'Account Actions (Danger Zone)';

  // Generative AI Compliance (Reporting, Feedback & Disclaimer)
  String get reportAiButton => isHi ? 'रिपोर्ट करें' : 'Report';
  String get reportAiTitle =>
      isHi ? 'AI उत्तर की रिपोर्ट करें' : 'Report AI Response';
  String get reportAiSubtitle => isHi
      ? 'गलत या हानिकारक सलाह की रिपोर्ट करके AG Farmer को सुरक्षित व सटीक बनाने में मदद करें।'
      : 'Help keep AG Farmer safe and accurate by reporting incorrect or harmful advice.';
  String get reportReasonPesticide => isHi
      ? 'गलत दवा या कीटनाशक की मात्रा (Wrong/Harmful chemical dosage)'
      : 'Wrong or harmful chemical/pesticide dosage';
  String get reportReasonInaccurate => isHi
      ? 'तथ्यात्मक रूप से गलत कृषि जानकारी (Factually inaccurate farming info)'
      : 'Factually inaccurate farming information';
  String get reportReasonOffensive => isHi
      ? 'अनुचित या आपत्तिजनक भाषा (Offensive or inappropriate content)'
      : 'Offensive or inappropriate language';
  String get reportReasonOther =>
      isHi ? 'अन्य समस्या (Other issue)' : 'Other issue or concern';
  String get reportSubmitBtn => isHi ? 'रिपोर्ट सबमिट करें' : 'Submit Report';
  String get reportSuccess => isHi
      ? 'आपकी रिपोर्ट दर्ज कर ली गई है। हमारी कृषि टीम 24 घंटे में इसकी समीक्षा करेगी। धन्यवाद!'
      : 'Your report has been submitted. Our agricultural experts will review it. Thank you!';
  String get helpfulFeedback => isHi ? 'सटीक उत्तर' : 'Helpful';
  String get unhelpfulFeedback => isHi ? 'मददगार नहीं' : 'Not helpful';
  String get feedbackThanks =>
      isHi ? 'फीडबैक के लिए धन्यवाद!' : 'Thank you for your feedback!';
  String get aiDisclaimerNotice => isHi
      ? '⚠️ दवाइयों का उपयोग एक बार स्थानीय डिस्ट्रीब्यूटर से सलाह लेकर ही करें।'
      : '⚠️ Use medicines only after consulting your local distributor once.';

  // Legal & Privacy Policy In-App Viewer
  String get legalAndPrivacyTitle =>
      isHi ? 'प्राइवेसी पॉलिसी व नियम' : 'Privacy Policy & Terms';
  String get legalAndPrivacySubtitle => isHi
      ? 'डेटा सुरक्षा, AI नीतियां और नियम'
      : 'Data safety, AI usage policy & terms of service';
  String get closeBtn => isHi ? 'बंद करें' : 'Close';

  // Live support + admin
  String get liveSupportTitle => isHi ? 'लाइव सपोर्ट' : 'Live Support';
  String get liveSupportSubtitle => isHi
      ? 'पेड यूज़र के लिए लाइव सपोर्ट टोकन जनरेट करें'
      : 'Generate live support token for paid users';
  String get liveSupportPaidOnly => isHi
      ? 'लाइव सपोर्ट सिर्फ पेड सब्सक्रिप्शन पर मिलेगा। पहले प्लान खरीदें।'
      : 'Live support is only for paid subscribers. Buy a plan first.';
  String get liveSupportReady => isHi
      ? 'आपका प्लान एक्टिव है। टोकन जनरेट करें — अनुरोध Admin Panel पर जाएगा।'
      : 'Your plan is active. Generate token — request goes to Admin Panel.';
  String get generateLiveToken =>
      isHi ? 'लाइव टोकन जनरेट करें' : 'Generate Live Token';
  String get generatingToken => isHi ? 'जनरेट हो रहा है...' : 'Generating...';
  String get yourLiveToken => isHi ? 'आपका लाइव टोकन' : 'Your live token';
  String get tokenGenerated => isHi ? 'टोकन बन गया' : 'Token generated';
  String get tokenCopied => isHi ? 'टोकन कॉपी हो गया' : 'Token copied';
  String get tokenSentToAdmin => isHi
      ? 'रिक्वेस्ट एडमिन पैनल पर भेज दी गई है'
      : 'Request submitted to the admin panel';
  String get supportMessageLabel => isHi ? 'सपोर्ट मैसेज' : 'Support message';
  String get supportMessageHint =>
      isHi ? 'समस्या संक्षेप में लिखें...' : 'Briefly describe your issue...';
  String get mySupportRequests =>
      isHi ? 'मेरी सपोर्ट रिक्वेस्ट' : 'My support requests';
  String get noSupportRequests =>
      isHi ? 'अभी कोई रिक्वेस्ट नहीं' : 'No requests yet';
  String get statusLabel => isHi ? 'स्टेटस' : 'Status';
  String get tokenLabel => isHi ? 'टोकन' : 'Token';
  String get planLabel => isHi ? 'प्लान' : 'Plan';

  String get adminPanelTitle => isHi ? 'एडमिन पैनल' : 'Admin Panel';
  String get adminControlPanel =>
      isHi ? 'एडमिन कंट्रोल पैनल' : 'Admin Control Panel';
  String get adminPanelSubtitle => isHi
      ? 'सभी लाइव सपोर्ट रिक्वेस्ट यहाँ मैनेज करें'
      : 'Manage all live support requests here';
  String get adminUnlockSubtitle => isHi
      ? 'एडमिन पैनल अनलॉक तभी होगा जब पेमेंट पूरा होगा'
      : 'Admin panel unlocks only after payment';
  String get adminPayToUnlockNote => isHi
      ? 'बिना पेमेंट के Admin Control Panel नहीं खुलेगा। पेमेंट के बाद सभी सपोर्ट टोकन और रिक्वेस्ट कंट्रोल कर सकेंगे।'
      : 'Admin Control Panel stays locked until payment. After payment you can control all support tokens and requests.';
  String get adminUnlockPlan => isHi ? 'एडमिन अनलॉक' : 'Admin Unlock';
  String get adminUnlockBenefits => isHi
      ? '• सभी लाइव सपोर्ट रिक्वेस्ट\n• टोकन देखें / कॉपी करें\n• स्टेटस अपडेट (Pending/Active/Resolved)\n• लाइव अपडेट'
      : '• All live support requests\n• View / copy tokens\n• Update status (Pending/Active/Resolved)\n• Live updates';
  String get payAndUnlockAdmin =>
      isHi ? 'पेमेंट कर अनलॉक करें' : 'Pay & Unlock';
  String get adminUnlocked =>
      isHi ? 'एडमिन पैनल अनलॉक हो गया!' : 'Admin panel unlocked!';
  String get adminUnlockedBadge => isHi ? 'अनलॉक्ड' : 'UNLOCKED';
  String get openAdminPanel => isHi ? 'एडमिन पैनल खोलें' : 'Open Admin Panel';
  String get unlockAdminPanel =>
      isHi ? 'एडमिन पैनल अनलॉक करें' : 'Unlock Admin Panel';
  String get updateRequestStatus =>
      isHi ? 'रिक्वेस्ट स्टेटस अपडेट' : 'Update request status';
  String get adminNoteLabel => isHi ? 'एडमिन नोट' : 'Admin note';
  String get saveStatus => isHi ? 'स्टेटस सेव करें' : 'Save Status';
  String get filterAll => isHi ? 'सभी' : 'ALL';
  String get liveSupportMenu =>
      isHi ? 'लाइव सपोर्ट टोकन' : 'Live Support Token';
  String get liveSupportMenuSub => isHi
      ? 'पेड यूज़र के लिए टोकन जनरेट + Admin को भेजें'
      : 'Generate token for paid users + send to Admin';
  String get adminMenuSub => isHi
      ? 'पेमेंट के बाद कंट्रोल पैनल अनलॉक'
      : 'Control panel unlocks after payment';

  String get chatSubtitle =>
      isHi ? 'देसी AI कृषि वैज्ञानिक' : 'AI Farming Scientist';
  String get chatWelcome => isHi
      ? 'राम-राम किसान भाई! 🙏 मैं AG Farmer हूँ — आपका देसी कृषि सलाहकार। अपनी फसल, बीमारी, खाद, स्प्रे या मंडी भाव के बारे में पूछें।'
      : 'Welcome Farmer Friend! 🙏 I am AG Farmer — your dedicated farming assistant. Ask about crops, pests, fertilizers, sprays or mandi prices.';
  String get chatReset => isHi
      ? 'नई बातचीत शुरू हो गई है। बताइए आज खेत में किस फसल के बारे में सलाह चाहिए?'
      : 'New conversation started. Which crop would you like advice on today?';
  String get chatGreetingTitle =>
      isHi ? 'राम-राम किसान भाई! 🙏' : 'Welcome Farmer Friend! 🙏';
  String get chatGreetingSub => isHi
      ? 'AG Farmer देसी कृषि सलाहकार • फसल, रोग, खाद, स्प्रे या मंडी भाव के बारे में पूछें'
      : 'AG Farmer AI Farming Advisor • Ask about crops, pests, sprays, fertilizers or mandi rates';
  String get online24x7 =>
      isHi ? '24x7 ऑनलाइन कृषि वैज्ञानिक' : '24x7 AI Agri-Scientist';
  String get chatNewTopic => isHi ? 'नया सवाल' : 'New Chat';
  String get chatHistoryTitle => isHi ? 'पिछली बातचीत' : 'Chat History';
  String get noChatHistory =>
      isHi ? 'अभी कोई पुरानी बातचीत नहीं है।' : 'No saved conversations yet.';
  String get clearChatConfirm => isHi
      ? 'क्या आप पूरी बातचीत साफ करना चाहते हैं?'
      : 'Clear all conversation?';
  String get cropFilterAll => isHi ? '🌾 सभी फसलें' : '🌾 All Crops';
  String get voiceModalTitle =>
      isHi ? 'बोलिए किसान भाई... 🎙️' : 'Speak Farmer Friend... 🎙️';
  String get voiceModalSub => isHi
      ? 'हिन्दी या अंग्रेज़ी में बोलें। राजस्थानी / गुजराती / मराठी बोली भी हिन्दी टेक्स्ट में बदल जाएगी।'
      : 'Speak in Hindi or English. Rajasthani / Gujarati / Marathi speech is converted toward Hindi text.';
  String get voiceModePickerTitle =>
      isHi ? 'वॉइस मोड चुनें' : 'Choose voice mode';
  String get voiceModePickerSub => isHi
      ? 'दो तरीके — लिखने के लिए बोलें, या लाइव बात करें'
      : 'Two ways — speak to type, or talk live';
  String get voiceModeSttTitle => isHi ? 'बोलकर लिखो' : 'Speak to type';
  String get voiceModeSttSub => isHi
      ? 'आप बोलें, टेक्स्ट चैट में भेजा जाएगा'
      : 'You speak, text is sent in chat';
  String get voiceModeLiveTitle => isHi ? 'AG Live बात' : 'AG Live talk';
  String get voiceModeLiveSub => isHi
      ? 'आप बोलें, आवाज़ जाएगी। जवाब आवाज़ में आएगा।'
      : 'You speak, your voice goes. The answer comes back as voice.';
  String get voiceLiveConnecting =>
      isHi ? 'लाइव आवाज़ जुड़ रही है…' : 'Connecting live voice…';
  String get voiceLiveListening => isHi
      ? 'आप बोल रहे हैं — आवाज़ जा रही है'
      : 'You are speaking — your voice is going';
  String get voiceLiveSpeaking => isHi
      ? 'जवाब आ रहा है — आवाज़ आ रही है'
      : 'Answer is coming — voice is playing';
  String get voiceLiveEnded => isHi ? 'कॉल समाप्त' : 'Call ended';
  String get voiceLiveUnavailable => isHi
      ? 'लाइव वॉइस अभी उपलब्ध नहीं। बाद में कोशिश करें।'
      : 'Live voice is unavailable. Try again later.';
  String get voiceLivePlanRequired => isHi
      ? 'AG Live सिर्फ High प्लान (₹299+) पर उपलब्ध है। प्लान खरीदें।'
      : 'AG Live needs a High plan (₹299+). Please upgrade.';
  String get voiceLiveWebOnly => isHi
      ? 'लाइव वॉइस अभी वेब / ब्राउज़र पर बेहतर चलता है।'
      : 'Live voice works best on web / browser for now.';
  String get voiceLiveEndCall => isHi ? 'कॉल बंद करें' : 'End call';
  String get voiceTapToSpeak => isHi ? 'माइक दबाकर बोलें' : 'Tap mic to speak';
  String get voiceListening =>
      isHi ? 'सुन रहा हूँ… बोलते रहें' : 'Listening… keep speaking';
  String get voicePreparing =>
      isHi ? 'माइक तैयार हो रहा है…' : 'Preparing microphone…';
  String get voiceWriting =>
      isHi ? 'जो बोला वही लिख रहा हूँ…' : 'Writing down exactly what you said…';
  String get voiceUnavailable => isHi
      ? 'आवाज़ पहचान उपलब्ध नहीं। माइक अनुमति दें या बाद में कोशिश करें।'
      : 'Speech not available. Allow mic permission or try again later.';
  String get voiceQuickOr =>
      isHi ? 'या इनमें से बोलें / टैप करें:' : 'Or tap a popular voice prompt:';
  String get photoModalTitle =>
      isHi ? 'पत्ती / पौधे की फोटो भेजें 📸' : 'Send Leaf / Crop Photo 📸';
  String get photoModalSub => isHi
      ? 'AI फोटो देखकर तुरंत बीमारी और स्प्रे की दवा बताएगा'
      : 'AI analyzes leaf photo for pest, disease & cure';
  String get cameraButton =>
      isHi ? 'खेत से सीधी फोटो लें (Camera)' : 'Take Photo (Camera)';
  String get galleryButton =>
      isHi ? 'गैलरी से फोटो चुनें' : 'Choose from Gallery';
  String get listenButton => isHi ? 'बोलकर सुनो' : 'Listen Voice';
  String get copySuccess => isHi ? 'सलाह कॉपी हो गई! 📋' : 'Advice copied! 📋';
  String get photoAnalysisHint => isHi
      ? '🌱 पत्ती की फोटो जाँची गई: पीलापन व फंगस के लक्षण मिले हैं। नीचे स्प्रे की दवा देखें।'
      : '🌱 Leaf photo analyzed: Signs of yellowing & fungus found. See spray solution below.';

  String get todaySmartFocus =>
      isHi ? 'आज का स्मार्ट फोकस' : "Today's Smart Focus";
  String get todaySmartFocusBody => isHi
      ? 'फसल की नमी जाँचें, दिन के टास्क पूरे करें, फिर कल के प्लान के लिए AG Farmer से पूछें।'
      : "Check crop moisture, finish Day tasks, then ask AG Farmer for tomorrow's plan.";
  String get chatHint => isHi
      ? 'अपनी भाषा में पूछें (उदा. लहसुन, खाद, स्प्रे)...'
      : 'Ask in your words (e.g. garlic, fertilizer, spray)...';
  String get sug1 => isHi
      ? '🧄 लहसुन में पीलापन कैसे ठीक करें?'
      : '🧄 How to stop garlic yellowing?';
  String get sug2 =>
      isHi ? 'अफीम डोडा व फुलाव के उपाय' : 'Opium pod sizing & care';
  String get sug3 => isHi
      ? '🌾 गेहूँ में कल्ले व फुटाव की खाद'
      : '🌾 Tillering fertilizer for wheat';
  String get sug4 =>
      isHi ? '🐛 पत्तियों पर कीड़े व सफेद मच्छर' : '🐛 Pest & whitefly spray';
  String get sug5 =>
      isHi ? '💧 आज पानी (सिंचाई) देना चाहिए?' : '💧 Should I irrigate today?';
  String get sug6 =>
      isHi ? '📊 आज का ताजा मंडी भाव' : '📊 Today mandi price updates';
  String get sugCreateCourse =>
      isHi ? 'फसल ट्रैक शुरू करें' : 'Start Crop Track';

  String get createCourseTitle =>
      isHi ? 'फसल ट्रैक शुरू करें' : 'Start Crop Track';
  String get createCourseSubtitle => isHi
      ? 'सभी फसलों के नाम दिखेंगे। कोर्स तैयार करने पर प्लान सुझाव मिलेगा।'
      : 'All crop names are listed. Plan suggestions appear when you start a course.';
  String get createCourseSticky => isHi ? 'ट्रैक शुरू' : 'Start Track';
  String get selectCropSticky => isHi ? 'फसल चुनें' : 'Select Crop';
  String get createCoursePinNote => isHi
      ? 'अफीम → ₹599 · लहसुन → ₹299 या ₹599 · बाकी फसलें → ₹299'
      : 'Afim → ₹599 · Garlic → ₹299 or ₹599 · Other crops → ₹299';
  String get topTargetCrops => isHi ? 'टॉप टारगेट फसलें' : 'Top target crops';
  String get indiaCropsList =>
      isHi ? 'भारत की फसलें व सब्जियाँ' : 'Crops & vegetables of India';
  String get createCourseForCrop =>
      isHi ? 'टैप करें → डेली डेटा ट्रैक शुरू' : 'Tap → start daily data track';
  String get addNewCourse => isHi ? 'नया जोड़ें' : 'Add New';
  String get createNewCourseTitle =>
      isHi ? 'नया कोर्स बनाएँ' : 'Create New Course';
  String get createNewCourseSub => isHi
      ? 'लिस्ट में फसल नहीं है? अपना नाम लिखकर नया ट्रैक शुरू करें।'
      : 'Crop missing from the list? Type your own name and start a new track.';
  String get createNewCourseHint =>
      isHi ? 'फसल / सब्ज़ी का नाम' : 'Crop / vegetable name';
  String get createNewCourseCta => isHi ? 'कोर्स बनाएँ' : 'Create course';
  String get createNewCourseEmpty => isHi ? 'नाम लिखें' : 'Enter a name';
  String get createNewCourseShort =>
      isHi ? 'नाम थोड़ा और लंबा लिखें' : 'Name is too short';
  String seeMoreCrops(int more) =>
      isHi ? 'और देखें ($more और)' : 'See more ($more more)';
  String get seeLessCrops => isHi ? 'कम दिखाएँ' : 'See less';
  String courseAllCropsNote(int n) => isHi
      ? '$n फसलें व सब्जियाँ उपलब्ध — नीचे See More से सब देखें।'
      : '$n crops & veggies available — use See More below for the full list.';
  String get chatCreateCourseBanner => isHi
      ? 'फसल चुनकर डेली डेटा ट्रैक शुरू करें। डेटा से सुझाव और रिपोर्ट बनेगी। अफीम और लसून सबसे ऊपर हैं।'
      : 'Pick a crop to start daily data tracking. Suggestions and reports come from your logs. Afim & Garlic stay on top.';
  String get courseCreateHintChat => isHi
      ? 'फसल ट्रैक खुल चुका था। डेली डेटा भरकर सुझाव और रिपोर्ट देख सकते हैं।'
      : 'Crop track opened. Log daily data to see suggestions and reports.';

  String replyFor(String query, {String? activeCropId}) {
    return AgroAiService.answer(
      query,
      activeCropId: activeCropId,
      isHi: isHi,
    ).text;
  }

  String get courseTitle => isHi ? 'फसल ट्रैक' : 'Crop Track';
  String get courseSubtitle => isHi
      ? 'डेली डेटा → सुझाव → रिपोर्ट'
      : 'Daily data → suggestions → report';
  String get cropTrackBadge => isHi ? 'स्मार्ट ट्रैक' : 'SMART TRACK';
  String get courseHero => isHi
      ? 'रोज़ का डेटा। रोज़ की सलाह। रिपोर्ट तैयार।'
      : 'Daily data. Daily advice. Ready reports.';
  String get courseHeroSub => isHi
      ? '21 दिन का फिक्स्ड कोर्स नहीं — आप डेली डेटा भरेंगे, सिस्टम सुझाव और रिपोर्ट बनाएगा।'
      : 'Not a fixed 21-day course — you log daily data, the system builds suggestions and reports.';
  String get availableCourses => isHi ? 'मेरे ट्रैक' : 'My Tracks';
  String get myCropTracks => isHi ? 'मेरे फसल ट्रैक' : 'My crop tracks';
  String get myCoursesTitle => isHi ? 'मेरे कोर्स' : 'My Courses';
  String get createNewCourseBar =>
      isHi ? 'नया कोर्स बनाएँ' : 'Create New Course';
  String courseDayProgress(int day) => isHi ? 'दिन $day' : 'Day $day';
  String get courseRunning => isHi ? 'चालू कोर्स' : 'Ongoing';
  String get courseClosedBadge => isHi ? 'बंद' : 'Closed';
  String get courseSavedHint => isHi
      ? 'चैट हमेशा सेव रहता है — ऊपर से कोर्स चुनें'
      : 'Chat stays saved — pick a course above';
  String get addCropTrack => isHi ? 'नई फसल ट्रैक जोड़ें' : 'Add crop track';
  String get noCropTracksYet => isHi
      ? 'अभी कोई ट्रैक नहीं। फसल चुनकर डेली डेटा शुरू करें।'
      : 'No tracks yet. Pick a crop and start daily logging.';
  String logsCount(int n) => isHi ? '$n दिन का डेटा' : '$n day log(s)';
  String lastLogLine(String date, int moisture) => isHi
      ? 'आखिरी लॉग: $date • नमी $moisture%'
      : 'Last log: $date • moisture $moisture%';

  String get trackDetailSubtitle => isHi
      ? 'डेली डेटा भरें, सुझाव देखें, रिपोर्ट बनाएँ'
      : 'Log daily data, view suggestions, build report';
  String get tabDailyData => isHi ? 'डेली डेटा' : 'Daily Data';
  String get tabSuggestions => isHi ? 'सुझाव' : 'Suggestions';
  String get tabReport => isHi ? 'रिपोर्ट' : 'Report';
  String get enterTodayData => isHi
      ? 'आज का खेत डेटा भरें — इससे सुझाव बनेंगे।'
      : "Enter today's field data — suggestions will be built from it.";
  String get updateTodayData =>
      isHi ? 'आज का डेटा अपडेट करें।' : "Update today's data.";
  String get saveDailyData => isHi ? 'डेली डेटा सेव करें' : 'Save Daily Data';
  String get dailyDataSaved =>
      isHi ? 'डेली डेटा सेव हो गया' : 'Daily data saved';
  String get recentLogs => isHi ? 'हाल के लॉग' : 'Recent logs';
  String get noDailyLogsYet =>
      isHi ? 'अभी डेली लॉग नहीं है' : 'No daily logs yet';
  String get suggestionsExplain => isHi
      ? 'ये सुझाव आपके आज/आखिरी डेली डेटा से बने हैं।'
      : 'These suggestions are built from your today/latest daily data.';
  String get noSuggestionsYet => isHi
      ? 'पहले डेली डेटा सेव करें, फिर सुझाव यहाँ दिखेंगे।'
      : 'Save daily data first, then suggestions appear here.';
  String get cropReportTitle => isHi ? 'फसल रिपोर्ट' : 'Crop Report';
  String get daysLogged => isHi ? 'लॉग दिन' : 'Days logged';
  String get avgMoisture => isHi ? 'औसत नमी' : 'Avg moisture';
  String get commonMood => isHi ? 'आम मूड' : 'Common mood';
  String get commonPest => isHi ? 'आम कीट स्तर' : 'Common pest';
  String get commonWeather => isHi ? 'आम मौसम' : 'Common weather';
  String get reportKeySuggestions => isHi ? 'मुख्य सुझाव' : 'Key suggestions';
  String get trackNotFound => isHi ? 'ट्रैक नहीं मिला' : 'Track not found';
  String get pestLevelLabel => isHi ? 'कीट स्तर' : 'Pest level';
  String get weatherLabel => isHi ? 'मौसम' : 'Weather';
  String get pestNone => isHi ? 'नहीं' : 'None';
  String get pestLow => isHi ? 'कम' : 'Low';
  String get pestMedium => isHi ? 'मध्यम' : 'Medium';
  String get pestHigh => isHi ? 'ज्यादा' : 'High';
  String get weatherSunny => isHi ? 'धूप' : 'Sunny';
  String get weatherCloudy => isHi ? 'बादल' : 'Cloudy';
  String get weatherRainy => isHi ? 'बारिश' : 'Rainy';
  String get weatherHot => isHi ? 'गर्मी' : 'Hot';
  String get locationForWeatherTitle => isHi
      ? 'सही मौसम के लिए लोकेशन'
      : 'Location for accurate weather';
  String get locationForWeatherBody => isHi
      ? 'ऐप खुलते ही आपके खेत का मौसम सही आए, इसके लिए लोकेशन चालू करें।'
      : 'Turn on location so the forecast matches your field when the app opens.';
  String get locationEnableButton =>
      isHi ? 'लोकेशन चालू करें' : 'Turn on location';
  String get locationLater => isHi ? 'बाद में' : 'Later';

  String dayProgress(int day, int percent) =>
      isHi ? '$day लॉग • $percent% ट्रेंड' : '$day logs • $percent% trend';
  String get todayDailyStatus =>
      isHi ? 'आज का डेली डेटा' : "Today's Daily Data";
  String dayLabel(int day, String title) =>
      isHi ? 'दिन $day: $title' : 'Day $day: $title';
  String get openTodayStatus => isHi ? 'आज का डेटा खोलें' : "Open Today's Data";
  String get roadmap => isHi ? 'डेली लॉग इतिहास' : 'Daily log history';
  String get statusDone => isHi ? 'हो गया' : 'Done';
  String get statusToday => isHi ? 'आज' : 'Today';
  String get statusNext => isHi ? 'अगला' : 'Next';
  String get statusMissed => isHi ? 'छूटा' : 'Missed';
  String get statusLocked => isHi ? 'लॉक' : 'Locked';
  String get season => isHi ? 'सीजन' : 'Season';
  String get duration => isHi ? 'अवधि' : 'Duration';
  String get progress => isHi ? 'प्रगति' : 'Progress';

  String get dailyStatus => isHi ? 'डेली स्टेटस' : 'Daily Status';
  String dayCourse(int day, String name) =>
      isHi ? 'दिन $day • $name' : 'Day $day • $name';
  String get lockedDayMsg => isHi
      ? 'यह दिन अभी लॉक है। पहले पिछले दिन का स्टेटस पूरा करें।'
      : 'This day is locked. Complete the previous day status first.';
  String get fieldMood => isHi ? 'खेत की स्थिति' : 'Field Mood';
  String get soilMoisture => isHi ? 'मिट्टी की नमी' : 'Soil Moisture';
  String get todaysTasks => isHi ? 'आज के टास्क' : "Today's Tasks";
  String get eveningNote => isHi ? 'शाम का नोट' : 'Evening Note';
  String get eveningHint => isHi
      ? 'आज खेत में क्या देखा?'
      : 'What did you observe in the field today?';
  String tip(String text) => isHi ? '💡 टिप: $text' : '💡 Tip: $text';
  String get saveDailyStatus =>
      isHi ? 'डेली स्टेटस सेव करें' : 'Save Daily Status';
  String get statusUpdated => isHi ? 'स्टेटस अपडेट हो गया' : 'Status Updated';
  String get completeTasksFirst => isHi
      ? 'पहले सारे डेली टास्क पूरे करें।'
      : 'Please complete all daily tasks first.';
  String statusSaved(int day) => isHi
      ? 'दिन $day स्टेटस सेव हो गया। कल का प्लान अनलॉक तैयार!'
      : 'Day $day status saved. Tomorrow’s plan is ready to unlock!';

  String get moodExcellent => isHi ? 'उत्तम' : 'Excellent';
  String get moodGood => isHi ? 'अच्छा' : 'Good';
  String get moodAverage => isHi ? 'सामान्य' : 'Average';
  String get moodPoor => isHi ? 'खराब' : 'Poor';

  List<String> get moods => [moodExcellent, moodGood, moodAverage, moodPoor];
}

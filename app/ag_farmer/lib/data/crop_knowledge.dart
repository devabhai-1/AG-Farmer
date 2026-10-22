/// Local crop knowledge for Fasal Jankari — long articles with short previews.
class CropKnowledgePost {
  final String id;
  final String cropId;
  final String category; // about | stages | diseases | tips
  final String titleHi;
  final String titleEn;
  final String bodyHi;
  final String bodyEn;
  final int readMinutes;
  final List<String> images;
  final String phase;

  const CropKnowledgePost({
    required this.id,
    required this.cropId,
    required this.category,
    required this.titleHi,
    required this.titleEn,
    required this.bodyHi,
    required this.bodyEn,
    this.readMinutes = 4,
    this.images = const [],
    this.phase = '',
  });

  factory CropKnowledgePost.fromApi(Map<String, dynamic> json) {
    final minutes = json['readMinutes'];
    return CropKnowledgePost(
      id: '${json['id'] ?? ''}',
      cropId: '${json['cropId'] ?? 'afim'}',
      category: '${json['category'] ?? 'about'}',
      titleHi: '${json['titleHi'] ?? ''}',
      titleEn: '${json['titleEn'] ?? ''}',
      bodyHi: '${json['bodyHi'] ?? ''}',
      bodyEn: '${json['bodyEn'] ?? ''}',
      readMinutes: minutes is num ? minutes.toInt() : 6,
      images: _imageNames(json['images']),
      phase: '${json['phase'] ?? ''}',
    );
  }

  static List<String> _imageNames(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  String title(bool hi) => hi ? titleHi : titleEn;
  String body(bool hi) => hi ? bodyHi : bodyEn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cropId': cropId,
    'category': category,
    'titleHi': titleHi,
    'titleEn': titleEn,
    'bodyHi': bodyHi,
    'bodyEn': bodyEn,
    'readMinutes': readMinutes,
    'images': images,
    'phase': phase,
  };

  String preview(bool hi, {int maxChars = 140}) {
    final raw = body(
      hi,
    ).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.length <= maxChars) return raw;
    return '${raw.substring(0, maxChars).trim()}…';
  }

  /// Split full article into paragraphs for smart page layout.
  List<String> paragraphs(bool hi) => body(hi)
      .split(RegExp(r'\n\s*\n'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class CropKnowledge {
  static const categories = ['about', 'stages', 'diseases', 'tips'];
  static List<CropKnowledgePost> _remote = const [];

  /// Articles fetched from Realtime Database. They are not compiled into the APK.
  static void replaceRemote(List<CropKnowledgePost> posts) {
    final keep = <String, List<CropKnowledgePost>>{};
    for (final post in _remote) {
      keep.putIfAbsent(post.cropId, () => []).add(post);
    }
    final incoming = <String, List<CropKnowledgePost>>{};
    for (final post in posts) {
      incoming.putIfAbsent(post.cropId, () => []).add(post);
    }
    final merged = <CropKnowledgePost>[];
    for (final id in {...keep.keys, ...incoming.keys}) {
      final old = keep[id] ?? const <CropKnowledgePost>[];
      final neu = incoming[id] ?? const <CropKnowledgePost>[];
      if (old.length >= 80 && old.length > neu.length) {
        merged.addAll(old);
      } else if (neu.isNotEmpty) {
        merged.addAll(neu);
      } else {
        merged.addAll(old);
      }
    }
    _remote = List<CropKnowledgePost>.unmodifiable(merged);
  }

  static int remoteCount(String cropId) =>
      _remote.where((post) => post.cropId == cropId).length;

  static void upsertCrop(String cropId, List<CropKnowledgePost> posts) {
    if (posts.isEmpty) return;
    final rest = _remote.where((post) => post.cropId != cropId).toList();
    _remote = List<CropKnowledgePost>.unmodifiable([...rest, ...posts]);
  }

  static List<CropKnowledgePost> _merge(List<CropKnowledgePost> local) {
    if (_remote.isEmpty) return local;
    final remoteIds = _remote.map((p) => p.id).toSet();
    return [
      ..._remote,
      ...local.where((p) => !remoteIds.contains(p.id)),
    ];
  }

  static String categoryLabel(String key, bool hi) {
    switch (key) {
      case 'all':
        return hi ? 'सभी' : 'All';
      case 'about':
        return hi ? 'फसल क्या है' : 'About crop';
      case 'stages':
        return hi ? 'शुरुआत → अंत' : 'Start → End';
      case 'diseases':
        return hi ? 'रोग / कीट' : 'Diseases / Pests';
      case 'tips':
        return hi ? 'सुझाव' : 'Tips';
      default:
        return key;
    }
  }

  static List<CropKnowledgePost> forCrop(String cropId) {
    final remote = _remote.where((p) => p.cropId == cropId).toList();
    if (remote.isNotEmpty) return remote;
    final specific = _posts.where((p) => p.cropId == cropId).toList();
    if (specific.isNotEmpty) return specific;
    return _generic(cropId);
  }

  static List<CropKnowledgePost> allPosts({String? cropId}) {
    if (cropId == null || cropId.isEmpty || cropId == 'all') {
      return _merge(List<CropKnowledgePost>.from(_posts));
    }
    return forCrop(cropId);
  }

  static CropKnowledgePost? byId(String id) {
    for (final post in _merge(_posts)) {
      if (post.id == id) return post;
    }
    return null;
  }

  static String courseWelcome(String cropId, String cropName, bool hi) {
    final posts = forCrop(cropId);
    final stages = posts.where((p) => p.category == 'stages').toList();
    final diseases = posts.where((p) => p.category == 'diseases').toList();
    final stageLine = stages.isNotEmpty
        ? stages.first
              .body(hi)
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .take(5)
              .join('\n')
        : (hi
              ? '• भूमि तैयारी → बुवाई → देखभाल → कटाई'
              : '• Land prep → sowing → care → harvest');
    final diseaseLine = diseases.isNotEmpty
        ? diseases.map((d) => '• ${d.title(hi)}').take(4).join('\n')
        : (hi ? '• सामान्य रोगों पर नजर रखें' : '• Watch common diseases');

    if (hi) {
      return '🌾 **$cropName फसल कोर्स चैट**\n\n'
          'यह चैट सिर्फ **$cropName** के लिए है — शुरुआत से कटाई तक।\n\n'
          '**फसल यात्रा:**\n$stageLine\n\n'
          '**ध्यान रखने वाले रोग:**\n$diseaseLine\n\n'
          'कोई भी सवाल पूछें: पानी, खाद, स्प्रे, रोग…';
    }
    return '🌾 **$cropName Crop Course Chat**\n\n'
        'This chat is only for **$cropName** — from start to harvest.\n\n'
        '**Crop journey:**\n$stageLine\n\n'
        '**Watch for:**\n$diseaseLine\n\n'
        'Ask anything: water, fertilizer, spray, disease…';
  }

  static List<CropKnowledgePost> _generic(String cropId) => [
    CropKnowledgePost(
      id: '${cropId}_about',
      cropId: cropId,
      category: 'about',
      titleHi: 'फसल परिचय — पूरी गाइड',
      titleEn: 'Crop overview — full guide',
      readMinutes: 5,
      bodyHi:
          'यह फसल भारत की मुख्य खेती प्रणाली का हिस्सा है। सही मौसम, प्रमाणित बीज, मिट्टी जाँच और पानी प्रबंधन मिलकर पैदावार तय करते हैं।\n\n'
          '**क्यों ज़रूरी है समझना?**\n'
          'बिना सही जानकारी के अधिक खाद या गलत स्प्रे नुकसान पहुँचा सकता है। इस लेख में फसल का स्वभाव, उपयुक्त जलवायु और बुनियादी देखभाल लिखी है।\n\n'
          '**मिट्टी व जलवायु**\n'
          'अच्छी जल निकासी वाली दोमट मिट्टी अधिकतर फसलों के लिए अनुकूल होती है। अत्यधिक जलभराव जड़ गलन बढ़ाता है। स्थानीय मौसम कैलेंडर के अनुसार बुवाई करें।\n\n'
          '**अगला कदम**\n'
          'पूरा लेख पढ़ने के बाद “शुरुआत → अंत” टैब में अवस्था-दर-अवस्था योजना देखें, और रोग टैब में आम समस्याएँ जाँचें। विस्तार के लिए फसल कोर्स चैट में पूछ सकते हैं।',
      bodyEn:
          'This crop is part of India’s farming system. Season, seed, soil test and water management decide yield.\n\n'
          '**Why learn this?**\n'
          'Wrong fertilizer or spray timing can hurt the crop. This article covers crop nature, climate fit and basic care.\n\n'
          '**Soil & climate**\n'
          'Well-drained loam suits most crops. Waterlogging raises root-rot risk. Sow by local calendar.\n\n'
          '**Next**\n'
          'Read Start→End for stage plan and Diseases for common issues. Ask more in Crop Course chat.',
    ),
    CropKnowledgePost(
      id: '${cropId}_stages',
      cropId: cropId,
      category: 'stages',
      titleHi: 'शुरुआत से कटाई — चरण गाइड',
      titleEn: 'Start to harvest — stage guide',
      readMinutes: 6,
      bodyHi:
          '**1) भूमि तैयारी**\nगहरी जुताई, खरपतवार सफाई, बेसल खाद मिट्टी जाँच के बाद।\n\n'
          '**2) बीज / पौध**\nप्रमाणित बीज या स्वस्थ पौध चुनें। बीजोपचार रोग दबाव कम करता है।\n\n'
          '**3) सिंचाई व निराई**\nजरूरत अनुसार पानी — न सूखा छोड़ें न खेत डुबाएँ। समय पर निराई पोषक तत्व बचाती है।\n\n'
          '**4) रोग-कीट निगरानी**\nहफ्ते में खेत घूमें। शुरुआती लक्षण पर स्प्रे सस्ता और असरदार पड़ता है।\n\n'
          '**5) कटाई व भंडारण**\nसही नमी पर कटाई करें। सूखा भंडारण कीट व फफूंद घटाता है।',
      bodyEn:
          '**1) Land prep**\nDeep tillage, weed clean-up, basal fertilizer after soil test.\n\n'
          '**2) Seed / nursery**\nUse certified seed or healthy seedlings. Seed treatment cuts disease pressure.\n\n'
          '**3) Irrigation & weeding**\nIrrigate as needed — avoid drought and flooding. Timely weeding saves nutrients.\n\n'
          '**4) Scout pests/diseases**\nWalk the field weekly. Early spray is cheaper and stronger.\n\n'
          '**5) Harvest & storage**\nHarvest at right moisture. Dry storage cuts pests and fungus.',
    ),
    CropKnowledgePost(
      id: '${cropId}_diseases',
      cropId: cropId,
      category: 'diseases',
      titleHi: 'आम रोग व कीट — पहचान गाइड',
      titleEn: 'Common diseases & pests — ID guide',
      readMinutes: 5,
      bodyHi:
          '**फफूंद धब्बे**\nपत्तियों पर गोल/कोणीय धब्बे, कभी किनारों से फैलते हुए। नमी अधिक हो तो फंगीसाइड चक्र सोचें।\n\n'
          '**रस चूसने वाले कीट**\nपत्तियाँ मुड़ना, चिपचिपा मल, सिल्वर धब्बे। शुरुआती अवस्था में कीटनाशक सलाह लें।\n\n'
          '**जड़ गलन**\nअधिक पानी + खराब निकासी। नालियाँ साफ रखें, सिंचाई अंतराल बढ़ाएँ।\n\n'
          'लक्षण दिखते ही स्थानीय कृषि सलाह / फसल कोर्स चैट से स्प्रे पूछें — डोज फसल और अवस्था पर निर्भर है।',
      bodyEn:
          '**Fungal spots**\nRound/angular leaf spots, often spreading in humidity. Plan fungicide cycles.\n\n'
          '**Sucking pests**\nCurling leaves, sticky honeydew, silver patches. Ask early insecticide advice.\n\n'
          '**Root rot**\nExcess water + poor drainage. Clear drains; widen irrigation gaps.\n\n'
          'When symptoms appear, ask Course chat for spray — dose depends on crop and stage.',
    ),
    CropKnowledgePost(
      id: '${cropId}_tips',
      cropId: cropId,
      category: 'tips',
      titleHi: 'स्मार्ट किसान सुझाव',
      titleEn: 'Smart farmer tips',
      readMinutes: 3,
      bodyHi:
          '• मिट्टी जाँच के बाद ही खाद का फॉर्मूला तय करें।\n'
          '• स्प्रे शाम को, हवा शांत हो तब बेहतर असर।\n'
          '• एक ही खेत में लगातार एक फसल न लगाएँ — फसल चक्र अपनाएँ।\n'
          '• रिकॉर्ड रखें: कौन सा स्प्रे, कब, कितना असर।\n\n'
          'ये छोटी आदतें लागत घटाती और पैदावार स्थिर रखती हैं।',
      bodyEn:
          '• Decide fertilizer only after soil test.\n'
          '• Prefer calm evening sprays.\n'
          '• Rotate crops — avoid same crop every season.\n'
          '• Keep records: spray, date, result.\n\n'
          'Small habits cut cost and stabilize yield.',
    ),
  ];

  static final List<CropKnowledgePost> _posts = [
    CropKnowledgePost(
      id: 'afim_about',
      cropId: 'afim',
      category: 'about',
      titleHi: 'अफीम (Afim) पूरी कहानी — जलवायु से दूध तक',
      titleEn: 'Opium (Afim) full story — climate to latex',
      readMinutes: 7,
      bodyHi:
          'अफीम रबी मौसम की महत्वपूर्ण **नकदी फसल** है। डोडे से निकलने वाला दूध (latex) मुख्य उपज है। सफल फसल के लिए ठंडी रातें, साफ धूप और अच्छी जल निकासी वाली भूमि चाहिए।\n\n'
          '**कहाँ अच्छी होती है?**\n'
          'उत्तर–पश्चिम भारत के कुछ इलाकों में पारंपरिक खेती है। भारी चिकनी या जलभराव वाली मिट्टी में जड़ समस्याएँ बढ़ जाती हैं। हल्की दोमट–बलुई दोमट बेहतर रहती है।\n\n'
          '**पौधे का स्वभाव**\n'
          'शुरुआत में पौधा धीरे बढ़ता है, फिर शाखाएँ और पत्तियाँ फैलती हैं। फूल आने के बाद डोडा बनता है — यही अवस्था पैदावार का केंद्र है।\n\n'
          '**कानूनी / सावधानी**\n'
          'अफीम खेती और संग्रहण सरकारी नियमों के अधीन है। केवल अधिकृत क्षेत्रों और लाइसेंस के अनुसार कार्य करें।\n\n'
          '**इस लेख के बाद क्या पढ़ें?**\n'
          '“शुरुआत → अंत” में अवस्था योजना, “रोग / कीट” में खाखरिया व फफूंद, और “सुझाव” में डोडा–दूध बढ़ाने के व्यावहारिक टिप्स।',
      bodyEn:
          'Opium is a key **Rabi cash crop**. Latex from pods is the main product. Cool nights, clear sun and well-drained soil help.\n\n'
          '**Where it thrives**\n'
          'Traditional belts in parts of NW India. Heavy waterlogged clay raises root issues. Light loam–sandy loam is better.\n\n'
          '**Plant habit**\n'
          'Slow early growth, then branching. After flowering, pods form — the yield center.\n\n'
          '**Legal note**\n'
          'Cultivation and collection follow government rules. Work only in authorized areas/licenses.\n\n'
          '**Read next**\n'
          'Start→End for stages, Diseases for mildew issues, Tips for latex yield.',
    ),
    CropKnowledgePost(
      id: 'afim_stages',
      cropId: 'afim',
      category: 'stages',
      titleHi: 'अफीम फसल यात्रा — अक्टूबर से कटाई तक',
      titleEn: 'Afim journey — October to harvest',
      readMinutes: 8,
      bodyHi:
          '**1) भूमि तैयारी (अक्टूबर–नवंबर)**\n'
          'गहरी जुताई, खरपतवार सफाई, बेसल खाद मिट्टी जाँच के बाद। खेत समतल रखें ताकि पानी रुके नहीं।\n\n'
          '**2) बुवाई व अंकुरण**\n'
          'सही नमी पर बुवाई। अंकुरण के बाद घनापन नियंत्रित करें — भीड़ रोग बढ़ाती है।\n\n'
          '**3) वानस्पतिक वृद्धि**\n'
          'सिंचाई हल्की–नियमित। अधिक पानी खाखरिया/गलान का खतरा बढ़ाता है। निराई समय पर।\n\n'
          '**4) फूल → डोडा**\n'
          'फूल झड़ने के बाद डोडा फुलाव अवस्था आती है। पोषण (P–K–बोरॉन) इसी समय महत्वपूर्ण।\n\n'
          '**5) चीरा व दूध**\n'
          'चीरा दोपहर 2–4 बजे हल्की गहराई में। सुबह ओस सूखने के बाद दूध उतारें। औजार साफ रखें।\n\n'
          '**6) कटाई**\n'
          'अंतिम दूध के बाद पौधे सुखाकर कटाई/निपटान नियमों के अनुसार।',
      bodyEn:
          '**1) Land prep (Oct–Nov)**\n'
          'Deep tillage, weed clean-up, basal fertilizer after soil test. Level fields to avoid standing water.\n\n'
          '**2) Sowing & germination**\n'
          'Sow at right moisture. Thin crowded stands — density raises disease.\n\n'
          '**3) Vegetative growth**\n'
          'Light, regular irrigation. Excess water raises mildew risk. Weed on time.\n\n'
          '**4) Flower → pod**\n'
          'After flowering, pod sizing starts. P–K–boron nutrition matters here.\n\n'
          '**5) Lancing & latex**\n'
          'Lance 2–4 PM, shallow. Collect latex next morning after dew. Keep tools clean.\n\n'
          '**6) Harvest**\n'
          'After final latex, dry and dispose per rules.',
    ),
    CropKnowledgePost(
      id: 'afim_disease_khakharia',
      cropId: 'afim',
      category: 'diseases',
      titleHi: 'खाखरिया / गलान — लक्षण, कारण, बचाव',
      titleEn: 'Khakharia / Downy mildew — signs, causes, control',
      readMinutes: 6,
      bodyHi:
          'खाखरिया (डाउनी मिल्ड्यू / गलान) अफीम की सबसे खतरनाक फफूंद समस्याओं में है। नमी और ठंडक में तेजी से फैलती है।\n\n'
          '**लक्षण**\n'
          '• पत्तियों के नीचे सफेद–धुंधली फफूंद\n'
          '• ऊपर पीले–भूरे धब्बे\n'
          '• तेज हमले में पत्तियाँ झुलसना / पौधा कमजोर\n\n'
          '**क्यों आता है?**\n'
          'खेत में पानी रुकना, घना पौध घनत्व, लगातार नमी वाली रातें।\n\n'
          '**क्या करें?**\n'
          '• नालियाँ साफ रखें, सिंचाई नियंत्रित करें\n'
          '• Metalaxyl + Mancozeb (रिडोमिल टाइप) स्प्रे — डोज स्थानीय सलाह अनुसार\n'
          '• स्प्रे शाम को, हवा शांत हो\n'
          '• दोबारा स्प्रे अंतराल रोग दबाव देखकर\n\n'
          'शुरुआती लक्षण पर तुरंत कार्रवाई नुकसान घटाती है। कोर्स चैट में अपनी अवस्था बताकर डोज पूछ सकते हैं।',
      bodyEn:
          'Khakharia (downy mildew) is among the most serious fungal issues in opium. It spreads fast in cool humidity.\n\n'
          '**Symptoms**\n'
          '• White fuzzy growth under leaves\n'
          '• Yellow–brown patches on top\n'
          '• Severe cases: leaf burn / weak plants\n\n'
          '**Why**\n'
          'Standing water, dense stands, humid nights.\n\n'
          '**What to do**\n'
          '• Clear drains; control irrigation\n'
          '• Metalaxyl + Mancozeb (Ridomil-type) — dose per local advice\n'
          '• Spray in calm evening\n'
          '• Re-spray based on pressure\n\n'
          'Act early. Ask Course chat with your stage for dosing help.',
    ),
    CropKnowledgePost(
      id: 'afim_disease_powdery',
      cropId: 'afim',
      category: 'diseases',
      titleHi: 'सफेद फफूंद (Powdery Mildew) पूरी गाइड',
      titleEn: 'Powdery mildew full guide',
      readMinutes: 5,
      bodyHi:
          'सफेद फफूंद पत्तियों पर पाउडर जैसा सफेद जमाव छोड़ती है। शुष्क–मध्यम नमी में भी रह सकती है, लेकिन कमजोर पौधों पर जल्दी बढ़ती है।\n\n'
          '**पहचान**\n'
          'ऊपरी पत्ती सतह पर सफेद चूर्ण, बाद में पत्तियाँ पीली / झुलसी।\n\n'
          '**प्रबंधन**\n'
          '• सल्फर या सिस्टमिक फंगीसाइड — लेबल व सलाह अनुसार\n'
          '• अधिक नाइट्रोजन से बचें जो नरम वृद्धि बढ़ाए\n'
          '• खेत में हवा का संचार रखें\n\n'
          'खाखरिया से अलग पहचान ज़रूरी है क्योंकि स्प्रे विकल्प भिन्न हो सकते हैं।',
      bodyEn:
          'Powdery mildew leaves white powdery deposits. It can appear in moderate humidity and prefers weak plants.\n\n'
          '**ID**\n'
          'White powder on upper leaf surface; later yellowing/scorch.\n\n'
          '**Management**\n'
          '• Sulfur or systemic fungicide per label/advice\n'
          '• Avoid excess nitrogen soft growth\n'
          '• Keep airflow in the canopy\n\n'
          'Distinguish from downy mildew — spray choices differ.',
    ),
    CropKnowledgePost(
      id: 'afim_tips',
      cropId: 'afim',
      category: 'tips',
      titleHi: 'डोडा फुलाव व दूध — व्यावहारिक सुझाव',
      titleEn: 'Pod sizing & latex — practical tips',
      readMinutes: 5,
      bodyHi:
          'फूल झड़ने के बाद डोडा बनने की अवस्था में पोषण बदलता है। सिर्फ नाइट्रोजन बढ़ाने से नुकसान हो सकता है।\n\n'
          '**पोषण टिप**\n'
          'NPK 0:52:34 + बोरॉन स्प्रे कई किसानों में डोडा चमक/फुलाव में मदद करता है — डोज खेत सलाह से लें। कैल्शियम डोडा दीवार मजबूत करने में सहायक माना जाता है।\n\n'
          '**चीरा**\n'
          'गहराई बहुत ज्यादा न रखें। दोपहर का समय चुनें। औजार तेज व साफ हो।\n\n'
          '**रिकॉर्ड**\n'
          'किस दिन स्प्रे/चीरा किया — नोट रखें। अगले मौसम में यही रिकॉर्ड सोना बनता है।',
      bodyEn:
          'After flowering, nutrition needs shift. Pushing only nitrogen can hurt.\n\n'
          '**Nutrition tip**\n'
          'NPK 0:52:34 + boron sprays often help pod size — confirm dose locally. Calcium supports pod wall strength.\n\n'
          '**Lancing**\n'
          'Keep shallow depth. Prefer afternoon. Sharp clean tools.\n\n'
          '**Records**\n'
          'Note spray/lance dates. Next season those notes are gold.',
    ),
    CropKnowledgePost(
      id: 'lasun_about',
      cropId: 'lasun',
      category: 'about',
      titleHi: 'लहसुन — किस्म, जलवायु और खेती का सार',
      titleEn: 'Garlic — variety, climate and farming basics',
      readMinutes: 6,
      bodyHi:
          'लहसुन रबी की प्रमुख **मसाला व नकदी** फसल है। कलियों (cloves) से उगाई जाती है। ठंडी जलवायु, हल्की सिंचाई और अच्छी निकासी वाली मिट्टी में कंद चमकदार बनते हैं।\n\n'
          '**बीज सामग्री**\n'
          'स्वस्थ, बीमारी-मुक्त कलियाँ चुनें। सड़े/कोमल कलियाँ खेत में समस्या फैलाती हैं।\n\n'
          '**मिट्टी**\n'
          'दोमट–बलुई दोमट उपयुक्त। भारी जलभराव पर सड़न बढ़ती है।\n\n'
          '**बाजार नजर**\n'
          'गुणवत्ता (आकार, छिलका, सूखापन) कीमत तय करती है — सिर्फ वजन नहीं।',
      bodyEn:
          'Garlic is a key Rabi spice/cash crop grown from cloves. Cool climate, light irrigation and drained soil give shiny bulbs.\n\n'
          '**Seed material**\n'
          'Use healthy disease-free cloves. Soft/rotten cloves spread field problems.\n\n'
          '**Soil**\n'
          'Loam–sandy loam suits. Waterlogging raises rot.\n\n'
          '**Market**\n'
          'Quality (size, skin, dryness) sets price — not weight alone.',
    ),
    CropKnowledgePost(
      id: 'lasun_stages',
      cropId: 'lasun',
      category: 'stages',
      titleHi: 'लहसुन: क्यारी से खुदाई तक',
      titleEn: 'Garlic: beds to harvest',
      readMinutes: 7,
      bodyHi:
          '**1) क्यारियाँ व बेसल**\n'
          'उठी हुई क्यारियाँ निकासी सुधारती हैं। बेसल खाद मिट्टी जाँच के बाद।\n\n'
          '**2) कलियाँ लगाना**\n'
          'सही गहराई व दूरी — भीड़ से फफूंद दबाव बढ़ता है।\n\n'
          '**3) सिंचाई / निराई**\n'
          'हल्की सिंचाई। अधिक पानी = सड़न। समय पर निराई।\n\n'
          '**4) कंद बनना**\n'
          'पत्तियाँ हरी रहें लेकिन नाइट्रोजन का अंत समय पर नियंत्रित करें ताकि कंद पक सकें।\n\n'
          '**5) खुदाई**\n'
          'जब ऊपरी भाग पीला/सूखने लगे। छाया में सुखाएँ, फिर भंडारण।',
      bodyEn:
          '**1) Beds & basal**\n'
          'Raised beds improve drainage. Basal fertilizer after soil test.\n\n'
          '**2) Planting cloves**\n'
          'Right depth/spacing — crowding raises fungus.\n\n'
          '**3) Irrigation / weeding**\n'
          'Light irrigations. Excess water = rot. Weed on time.\n\n'
          '**4) Bulbing**\n'
          'Keep canopy green but taper nitrogen so bulbs mature.\n\n'
          '**5) Harvest**\n'
          'When tops yellow/dry. Cure in shade, then store.',
    ),
    CropKnowledgePost(
      id: 'lasun_disease_blight',
      cropId: 'lasun',
      category: 'diseases',
      titleHi: 'पर्पल ब्लॉच / झुलसा — पहचान व नियंत्रण',
      titleEn: 'Purple blotch / blight — ID & control',
      readMinutes: 5,
      bodyHi:
          'पत्तियों पर बैंगनी–भूरे धब्बे फैलकर झुलसा पैदा करते हैं। नमी और बार-बार ओस में तेज फैलता है।\n\n'
          '**प्रबंधन**\n'
          '• मैंकोजेब / कॉपर आधारित स्प्रे (सलाह अनुसार)\n'
          '• नमी घटाएँ, घना रोपण न करें\n'
          '• रोगग्रस्त अवशेष हटाएँ\n\n'
          'शुरुआत में पकड़ना आसान है — देर से नुकसान बड़ा हो जाता है।',
      bodyEn:
          'Purple–brown leaf blotches spread into blight. Fast under dew/humidity.\n\n'
          '**Management**\n'
          '• Mancozeb / copper sprays (per advice)\n'
          '• Reduce humidity; avoid dense planting\n'
          '• Remove infected debris\n\n'
          'Catch early — late loss is costly.',
    ),
    CropKnowledgePost(
      id: 'lasun_disease_thrips',
      cropId: 'lasun',
      category: 'diseases',
      titleHi: 'थrips — सिल्वर पत्तियाँ और नुकसान',
      titleEn: 'Thrips — silvering and crop loss',
      readMinutes: 4,
      bodyHi:
          'थrips पत्तियों का रस चूसते हैं। पत्तियाँ सिल्वर–सफेद दिखती हैं, वृद्धि रुकती है।\n\n'
          '**क्या करें**\n'
          '• खेत नियमित स्काउट करें\n'
          '• अनुशंसित कीटनाशक (इमिडाक्लोप्रिड / स्पाइनोसैड प्रकार) — लेबल व स्थानीय सलाह\n'
          '• खरपतवार मेजबान घटाएँ\n\n'
          'तेज धूप व सूखे में हमला बढ़ सकता है — पानी का संतुलन रखें।',
      bodyEn:
          'Thrips suck leaf sap. Leaves look silvery-white; growth slows.\n\n'
          '**Actions**\n'
          '• Scout regularly\n'
          '• Recommended insecticides (imidacloprid / spinosad types) — label + local advice\n'
          '• Reduce weed hosts\n\n'
          'Hot dry spells can worsen attack — keep irrigation balanced.',
    ),
    CropKnowledgePost(
      id: 'lasun_tips',
      cropId: 'lasun',
      category: 'tips',
      titleHi: 'चमकदार कंद के लिए सुझाव',
      titleEn: 'Tips for shiny bulbs',
      readMinutes: 4,
      bodyHi:
          '• अधिक पानी से सड़न — निकासी पहले।\n'
          '• सल्फर पोषण कंद गुणवत्ता में मददगार माना जाता है।\n'
          '• खुदाई के बाद सही क्योरिंग भंडारण अवधि बढ़ाती है।\n'
          '• बाजार से पहले छंटाई — छोटे/बिगड़े अलग।\n\n'
          'गुणवत्ता = बेहतर भाव।',
      bodyEn:
          '• Excess water causes rot — drainage first.\n'
          '• Sulfur nutrition often helps bulb quality.\n'
          '• Proper curing after harvest extends storage.\n'
          '• Grade before market — separate small/damaged.\n\n'
          'Quality = better price.',
    ),
    CropKnowledgePost(
      id: 'wheat_about',
      cropId: 'wheat',
      category: 'about',
      titleHi: 'गेहूँ — भारत की रबी रीढ़',
      titleEn: 'Wheat — India’s Rabi backbone',
      readMinutes: 5,
      bodyHi:
          'गेहूँ देश की मुख्य रबी अनाज फसल है। समय पर बुवाई, सही किस्म और सिंचाई अनुसूची पैदावार की कुंजी है।\n\n'
          '**किस्म चुनना**\n'
          'क्षेत्रीय अनुशंसित किस्में रोग प्रतिरोध और अवधि के हिसाब से चुनें।\n\n'
          '**मिट्टी**\n'
          'उपजाऊ दोमट बेहतर। जल निकासी रखें।\n\n'
          '**उद्देश्य**\n'
          'अधिक पैदावार के साथ दाना गुणवत्ता (भरपूर दाना, कम झड़न) भी लक्ष्य रखें।',
      bodyEn:
          'Wheat is India’s main Rabi cereal. Timely sowing, right variety and irrigation schedule drive yield.\n\n'
          '**Variety**\n'
          'Pick region-recommended varieties for disease resistance and duration.\n\n'
          '**Soil**\n'
          'Fertile loam preferred. Keep drainage.\n\n'
          '**Goal**\n'
          'Aim for yield plus grain quality (bold grain, less shatter).',
    ),
    CropKnowledgePost(
      id: 'wheat_stages',
      cropId: 'wheat',
      category: 'stages',
      titleHi: 'गेहूँ अवस्थाएँ — पानी कब ज़रूरी',
      titleEn: 'Wheat stages — when water matters',
      readMinutes: 6,
      bodyHi:
          '**1) बुवाई**\n'
          'समय पर बुवाई ठंड पकड़ने से पहले अच्छी स्थापना देती है।\n\n'
          '**2) कल्ले (Tillering)**\n'
          'कल्ले संख्या पैदावार आधार है — नमी व नाइट्रोजन संतुलन।\n\n'
          '**3) गांठ / बाली**\n'
          'गांठ व बाली निकलना — पानी की कमी नुकसानदायक।\n\n'
          '**4) दूधिया दाना**\n'
          'दाना भरने की अवस्था — सिंचाई महत्वपूर्ण।\n\n'
          '**5) पकना व कटाई**\n'
          'सही नमी पर कटाई। देर से झड़न/गुणवत्ता नुकसान।',
      bodyEn:
          '**1) Sowing**\n'
          'Timely sowing gives strong establishment.\n\n'
          '**2) Tillering**\n'
          'Tiller count sets yield base — balance moisture and N.\n\n'
          '**3) Jointing / earing**\n'
          'Water stress here is costly.\n\n'
          '**4) Milk stage**\n'
          'Grain fill — irrigation critical.\n\n'
          '**5) Maturity & harvest**\n'
          'Harvest at right moisture. Late harvest risks shatter/quality loss.',
    ),
    CropKnowledgePost(
      id: 'wheat_disease_rust',
      cropId: 'wheat',
      category: 'diseases',
      titleHi: 'रतुआ (Rust) — पहचान और रणनीति',
      titleEn: 'Rust — ID and strategy',
      readMinutes: 5,
      bodyHi:
          'पत्तियों पर नारंगी–भूरे पाउडर धब्बे रतुआ की निशानी हैं। प्रतिरोधी किस्म पहला बचाव है।\n\n'
          '**जब हमला दिखे**\n'
          '• क्षेत्रीय सलाह अनुसार फंगीसाइड\n'
          '• खेत में घनापन/नमी प्रबंधन\n'
          '• स्वस्थ अवशेष प्रबंधन\n\n'
          'शुरुआती स्काउटिंग से स्प्रे खर्च बचता है।',
      bodyEn:
          'Orange–brown powdery pustules mark rust. Resistant varieties are first defense.\n\n'
          '**If outbreak**\n'
          '• Fungicide per regional advice\n'
          '• Manage canopy humidity\n'
          '• Residue hygiene\n\n'
          'Early scouting saves spray cost.',
    ),
    CropKnowledgePost(
      id: 'wheat_tips',
      cropId: 'wheat',
      category: 'tips',
      titleHi: 'CRI व अन्य सिंचाई — याद रखने लायक',
      titleEn: 'CRI and key irrigations — remember these',
      readMinutes: 3,
      bodyHi:
          'मुकुट जड़ (CRI), कल्ले, गांठ, दूधिया अवस्था — ये पानी की महत्वपूर्ण खिड़कियाँ हैं।\n\n'
          'अनावश्यक पानी न दें; सही समय पर एक सिंचाई कई अनावश्यक सिंचाई से बेहतर। खाद को किस्तों में बाँटें।',
      bodyEn:
          'CRI, tillering, jointing, milk stage — critical water windows.\n\n'
          'Don’t over-irrigate; one timely irrigation beats many wasteful ones. Split fertilizer doses.',
    ),
    CropKnowledgePost(
      id: 'rice_about',
      cropId: 'rice',
      category: 'about',
      titleHi: 'धान / चावल — पानी की फसल की समझ',
      titleEn: 'Paddy / rice — understanding the water crop',
      readMinutes: 6,
      bodyHi:
          'धान खरीफ की मुख्य फसल है। नर्सरी→रोपाई या सीधी बुवाई — दोनों में **पानी प्रबंधन** केंद्र है।\n\n'
          'लगातार जलभराव हमेशा जरूरी नहीं। सही नालियाँ और AWD जैसी विधियाँ पानी बचाकर पैदावार बनाए रख सकती हैं।\n\n'
          'किस्म अवधि (अगेती/मध्यम/देर) अपने मौसम और पानी स्रोत के अनुसार चुनें।',
      bodyEn:
          'Paddy is the main Kharif crop. Nursery→transplant or direct seeding — **water management** is central.\n\n'
          'Continuous flooding is not always required. Drains and AWD-style methods can save water while holding yield.\n\n'
          'Pick variety duration (early/medium/late) for your season and water source.',
    ),
    CropKnowledgePost(
      id: 'rice_stages',
      cropId: 'rice',
      category: 'stages',
      titleHi: 'धान यात्रा — नर्सरी से कटाई',
      titleEn: 'Paddy journey — nursery to harvest',
      readMinutes: 6,
      bodyHi:
          '**1) नर्सरी**\n'
          'स्वस्थ पौध — रोग कम, स्थापना अच्छी।\n\n'
          '**2) रोपाई**\n'
          'सही उम्र व दूरी।\n\n'
          '**3) कल्ले**\n'
          'नाइट्रोजन व पानी संतुलन।\n\n'
          '**4) बाली / दाना**\n'
          'पानी की कमी यहाँ नुकसानदायक।\n\n'
          '**5) कटाई**\n'
          'सही नमी — बहुत गीला या बहुत सूखा दोनों समस्या।',
      bodyEn:
          '**1) Nursery**\n'
          'Healthy seedlings — less disease, better stand.\n\n'
          '**2) Transplant**\n'
          'Right age and spacing.\n\n'
          '**3) Tillering**\n'
          'Balance N and water.\n\n'
          '**4) Panicle / grain**\n'
          'Water stress costly here.\n\n'
          '**5) Harvest**\n'
          'Right moisture — too wet or too dry both hurt.',
    ),
    CropKnowledgePost(
      id: 'rice_disease_blast',
      cropId: 'rice',
      category: 'diseases',
      titleHi: 'ब्लास्ट रोग — आँख जैसे धब्बे',
      titleEn: 'Blast disease — eye-shaped spots',
      readMinutes: 5,
      bodyHi:
          'पत्तियों पर आँख जैसे धब्बे ब्लास्ट की पहचान हैं। नमी व घना रोपण बढ़ाते हैं।\n\n'
          '**प्रबंधन**\n'
          '• प्रतिरोधी किस्म जहाँ संभव\n'
          '• ट्राइसाइक्लाजोल आदि — सलाह अनुसार\n'
          '• नाइट्रोजन का असंतुलन न बढ़ाएँ\n\n'
          'शुरुआती लक्षण पर स्प्रे असरदार।',
      bodyEn:
          'Eye-shaped leaf spots identify blast. Humidity and dense planting worsen it.\n\n'
          '**Management**\n'
          '• Resistant varieties where possible\n'
          '• Tricyclazole etc. per advice\n'
          '• Avoid unbalanced nitrogen\n\n'
          'Early spray works better.',
    ),
    CropKnowledgePost(
      id: 'rice_tips',
      cropId: 'rice',
      category: 'tips',
      titleHi: 'पानी बचाकर पैदावार',
      titleEn: 'Save water, keep yield',
      readMinutes: 3,
      bodyHi:
          'AWD / सही नाली प्रबंधन पानी घटाता है। खेत में हमेशा खड़ा पानी जरूरी नहीं।\n\n'
          'लीक नालियाँ ठीक करें। सिंचाई रिकॉर्ड रखें।',
      bodyEn:
          'AWD / good drains cut water use. Standing water is not always mandatory.\n\n'
          'Fix leaky channels. Keep irrigation records.',
    ),
    CropKnowledgePost(
      id: 'maize_about',
      cropId: 'maize',
      category: 'about',
      titleHi: 'मक्का — अनाज, चारा और बाजार',
      titleEn: 'Maize — grain, fodder and market',
      readMinutes: 5,
      bodyHi:
          'मक्का बहुउपयोगी फसल है — अनाज, चारा, उद्योग। अच्छी निकासी और संतुलित NPK चाहिए।\n\n'
          'किस्म (संकर/संमिश्र) अपने उद्देश्य के अनुसार चुनें। फॉल आर्मीवर्म जैसी कीट समस्याओं की निगरानी रखें।',
      bodyEn:
          'Maize is versatile — grain, fodder, industry. Needs drainage and balanced NPK.\n\n'
          'Pick hybrid/composite for your goal. Scout for fall armyworm and similar pests.',
    ),
    CropKnowledgePost(
      id: 'maize_stages',
      cropId: 'maize',
      category: 'stages',
      titleHi: 'मक्का अवस्थाएँ — नाइट्रोजन कब दें',
      titleEn: 'Maize stages — when to apply nitrogen',
      readMinutes: 6,
      bodyHi:
          '**1) बुवाई**\n'
          'नमी व बीज गहराई सही रखें।\n\n'
          '**2) वानस्पतिक**\n'
          'नाइट्रोजन की पहली किस्त।\n\n'
          '**3) घुटनों तक / फूल**\n'
          'दूसरी–तीसरी किस्त; पानी महत्वपूर्ण।\n\n'
          '**4) दाना भरना**\n'
          'नमी बनाएँ।\n\n'
          '**5) कटाई**\n'
          'दाना नमी बाजार/भंडारण के हिसाब से।',
      bodyEn:
          '**1) Sowing**\n'
          'Right moisture and depth.\n\n'
          '**2) Vegetative**\n'
          'First N split.\n\n'
          '**3) Knee-high / flowering**\n'
          'Next N splits; water critical.\n\n'
          '**4) Grain fill**\n'
          'Maintain moisture.\n\n'
          '**5) Harvest**\n'
          'Grain moisture for market/storage.',
    ),
    CropKnowledgePost(
      id: 'maize_disease_fall',
      cropId: 'maize',
      category: 'diseases',
      titleHi: 'फॉल आर्मीवर्म — स्काउटिंग गाइड',
      titleEn: 'Fall armyworm — scouting guide',
      readMinutes: 5,
      bodyHi:
          'पत्तियों में छेद और गोबर जैसा मल फॉल आर्मीवर्म का संकेत है। शुरुआती अवस्था में नियंत्रण सस्ता।\n\n'
          '**क्या करें**\n'
          '• हफ्ते में खेत देखें\n'
          '• अनुशंसित कीटनाशक / जैव विकल्प — सलाह अनुसार\n'
          '• एक ही दवा बार-बार न दोहराएँ\n\n'
          'देर से हमला नियंत्रण मुश्किल और महँगा।',
      bodyEn:
          'Leaf holes and frass signal fall armyworm. Early control is cheaper.\n\n'
          '**Actions**\n'
          '• Scout weekly\n'
          '• Recommended insecticides / bio options per advice\n'
          '• Rotate chemistries\n\n'
          'Late outbreaks are hard and costly.',
    ),
    CropKnowledgePost(
      id: 'maize_tips',
      cropId: 'maize',
      category: 'tips',
      titleHi: 'नाइट्रोजन किस्तें — सरल नियम',
      titleEn: 'Nitrogen splits — simple rule',
      readMinutes: 3,
      bodyHi:
          'नाइट्रोजन 2–3 किस्तों में बाँटें — शुरुआत और घुटनों तक ऊँचाई के आसपास।\n\n'
          'एक साथ सारी नाइट्रोजन देने से नुकसान/बहाव हो सकता है।',
      bodyEn:
          'Split N in 2–3 doses — early and around knee-high.\n\n'
          'All-at-once N risks loss/leaching.',
    ),
  ];
}

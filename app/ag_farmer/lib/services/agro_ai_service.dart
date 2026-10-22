class AgroAiResponse {
  final String text;
  final String? dosageHighlight;
  final List<String> quickReplies;
  final String category;
  final String? provider;
  final String? model;
  final bool blocked;
  final String? blockReason;
  final String? imageUrl;

  const AgroAiResponse({
    required this.text,
    this.dosageHighlight,
    this.quickReplies = const [],
    this.category = 'general',
    this.provider,
    this.model,
    this.blocked = false,
    this.blockReason,
    this.imageUrl,
  });
}

/// Dedicated Indian Agriculture Intelligence Engine (देसी किसान ज्ञान प्रणाली)
class AgroAiService {
  static AgroAiResponse answer(String query, {String? activeCropId, bool isHi = true}) {
    final q = query.toLowerCase().trim();

    // 1. अफीम (Opium / Afim)
    if (q.contains('afim') ||
        q.contains('अफीम') ||
        q.contains('doda') ||
        q.contains('डोडा') ||
        q.contains('chira') ||
        q.contains('चीरा') ||
        q.contains('khakharia') ||
        q.contains('खाखरिया') ||
        activeCropId == 'afim') {
      if (q.contains('khakharia') || q.contains('खाखरिया') || q.contains('galan') || q.contains('गलान')) {
        return AgroAiResponse(
          category: 'afim_disease',
          dosageHighlight: isHi
              ? '💊 मेटालैक्सिल 8% + मैंकोजेब 64% (रिडोमिल): 35 ग्राम प्रति 15 लीटर टंकी'
              : '💊 Metalaxyl 8% + Mancozeb 64%: 35g per 15L water spray pump',
          quickReplies: isHi
              ? ['स्प्रे के बाद पानी कब दें?', 'डोडा वृद्धि की खाद', 'कीटनाशक क्या मिलाएँ?']
              : ['When to irrigate after spray?', 'Pod growth fertilizer', 'Pest spray mix'],
          text: isHi
              ? '🌸 **अफीम में खाखरिया (Downy Mildew / गलान) का पक्का इलाज:**\n\n'
                '• **लक्षण:** पत्तियों के नीचे सफेद-धुंधली फंगस और ऊपर पीले-भूरे धब्बे पड़ना।\n'
                '• **तुरंत स्प्रे करें:** रिडोमिल गोल्ड (Metalaxyl 8% + Mancozeb 64%) 35 ग्राम प्रति 15L पंप।\n'
                '• **सपोर्ट स्प्रे:** इसके साथ स्ट्रेप्टोसाइक्लिन (1 ग्राम प्रति 15L) और सिलिकॉन चिपको (5ml) मिलाएँ।\n'
                '• **सावधानी:** खेत में ज्यादा पानी भरा न रहने दें। स्प्रे हमेशा दोपहर बाद हवा शांत होने पर करें।'
              : '🌸 **Opium Downy Mildew / Root Rot Solution:**\n\n'
                '• **Symptoms:** White fungal fuzz under leaves, yellow patches on top.\n'
                '• **Immediate Spray:** Ridomil Gold (Metalaxyl 8% + Mancozeb 64%) 35g per 15L pump.\n'
                '• **Booster:** Add Streptocycline (1g/15L) + Silicon spreader (5ml).\n'
                '• **Precaution:** Avoid stagnant water; spray in calm evening hours.',
        );
      }

      if (q.contains('doda') || q.contains('डोडा') || q.contains('fulav') || q.contains('फुलाव') || q.contains('chira') || q.contains('चीरा')) {
        return AgroAiResponse(
          category: 'afim_pod',
          dosageHighlight: isHi
              ? '🧪 NPK 0:52:34 (75 ग्राम) + बोरॉन 20% (15 ग्राम) प्रति 15L पंप'
              : '🧪 NPK 0:52:34 (75g) + Boron 20% (15g) per 15L pump',
          quickReplies: isHi
              ? ['चीरा लगाने का सही समय?', 'सफेद फफूंद का स्प्रे', 'खाद कब डालें?']
              : ['Right time for lancing?', 'Powdery mildew spray', 'Fertilizer timing'],
          text: isHi
              ? '🌸 **अफीम डोडा फुलाव, चमक व दूध (Latex) बढ़ाने का उपाय:**\n\n'
                '• **पहला काम:** फूल झड़ने के बाद जब डोडा बन रहा हो, तब NPK 0:52:34 (75g) और बोरॉन 20% (15g) का स्प्रे करें।\n'
                '• **कैल्शियम बोरॉन:** डोडे की दीवार मजबूत करने और फटने से बचाने के लिए चिलेटेड कैल्शियम 20ml मिलाएँ।\n'
                '• **चीरा लगाने की टिप:** चीरा दोपहर 2 से 4 बजे के बीच 1mm गहराई में ही लगाएँ। सुबह ओस सूखने के बाद दूध उतारें।'
              : '🌸 **Opium Pod Sizing & Latex Yield Improvement:**\n\n'
                '• **Action:** Post-flowering pod formation stage requires NPK 0:52:34 (75g) + Boron 20% (15g) per 15L pump.\n'
                '• **Shell Strength:** Add Chelated Calcium (20ml) to prevent pod burst and enhance gum yield.\n'
                '• **Lancing Tip:** Lance between 2–4 PM at 1mm depth; collect latex next morning after dew dries.',
        );
      }
    }

    // 2. लहसुन (Garlic / Lasun)
    if (q.contains('lasun') ||
        q.contains('lahsun') ||
        q.contains('लहसुन') ||
        q.contains('garlic') ||
        activeCropId == 'lasun') {
      if (q.contains('peel') || q.contains('पील') || q.contains('jalebi') || q.contains('जलेबी') || q.contains('thrips') || q.contains('थ्रिप्स')) {
        return AgroAiResponse(
          category: 'garlic_yellowing',
          dosageHighlight: isHi
              ? '🌿 थियामेथोक्सम 25% WG (10 ग्राम) + साफ फंगीसाइड (35 ग्राम) प्रति 15L'
              : '🌿 Thiamethoxam 25% WG (10g) + Saaf Fungicide (35g) per 15L',
          quickReplies: isHi
              ? ['लहसुन कंद फुलाव की दवा?', 'पानी कब दें?', 'NPK 0:0:50 का नाप']
              : ['Garlic bulb size medicine?', 'When to irrigate?', 'NPK 0:0:50 dosage'],
          text: isHi
              ? '🧄 **लहसुन में पीलापन व जलेबी रोग (Thrips/Pest) का पक्का देसी समाधान:**\n\n'
                '• **मुख्य कारण:** मौसम में नमी-गर्मी से थ्रिप्स (बारीक पीले-सफेद कीड़े) पत्तियों का रस चूसते हैं और फंगस लगती है।\n'
                '• **छिड़काव नुस्खा:**\n'
                '  1. थियामेथोक्सम 25% WG: 10 ग्राम\n'
                '  2. कार्बेंडाजिम 12% + मैंकोजेब 63% (Saaf): 35 ग्राम\n'
                '  3. माइक्रोन्यूट्रिएंट्स (जिंक + फेरस): 20 ग्राम\n'
                '  4. सिलिकॉन स्टीकर (चिपको): 5ml (ताकि दवा पत्तों पर चिपकी रहे)\n'
                '• **सलाह:** छिड़काव हमेशा शाम के समय करें। पानी 3 दिन बाद ही दें।'
              : '🧄 **Garlic Yellowing & Thrips/Curling Control:**\n\n'
                '• **Diagnosis:** Thrips sucking leaf sap combined with fungal blight cause yellow tips and curl.\n'
                '• **Recommended Tank Mix (per 15L pump):**\n'
                '  1. Thiamethoxam 25% WG: 10g\n'
                '  2. Carbendazim + Mancozeb (Saaf): 35g\n'
                '  3. Chelated Micronutrients: 20g\n'
                '  4. Silicon spreader: 5ml\n'
                '• **Note:** Spray in the evening; irrigate 3 days after spray.',
        );
      }

      if (q.contains('kand') || q.contains('कंद') || q.contains('size') || q.contains('fulav') || q.contains('फुलाव') || q.contains('mota') || q.contains('मोटा')) {
        return AgroAiResponse(
          category: 'garlic_bulb',
          dosageHighlight: isHi
              ? '⚖️ 0:0:50 (पोटाश) 100 ग्राम + बोरॉन 20% (20 ग्राम) प्रति 15L पानी'
              : '⚖️ NPK 0:0:50 (100g) + Boron 20% (20g) per 15L pump',
          quickReplies: isHi
              ? ['पानी कब बंद करें?', 'लहसुन मंडी भाव', 'पीलापन कैसे रोकें?']
              : ['When to stop irrigation?', 'Mandi prices', 'Prevent yellowing'],
          text: isHi
              ? '🧄 **लहसुन का कंद (गांठ) बड़ा, चमकदार और भारी करने की विधि:**\n\n'
                '• **सही समय:** जब लहसुन 75 से 95 दिन का हो जाए।\n'
                '• **पहला स्प्रे:** NPK 0:0:50 (100g) + बोरॉन 20% (20g) प्रति 15 लीटर टंकी। इससे कंद की सफेदी और वजन बढ़ता है।\n'
                '• **पीजीआर विकल्प:** यदि पौधा जरूरत से ज्यादा लंबा हो रहा है, तो कल्टार (Paclobutrazol) 5ml प्रति 15L स्प्रे करें ताकि पौधे की सारी ताकत कंद में जाए।\n'
                '• **सिंचाई नियम:** खुदाई से 12–15 दिन पहले सिंचाई पूरी तरह बंद कर दें, वरना लहसुन में पर्दा काला पड़ता है।'
              : '🧄 **Garlic Bulb Enlargement & Quality Boost:**\n\n'
                '• **Stage:** Best applied at 75–95 days after sowing.\n'
                '• **Foliar Spray:** NPK 0:0:50 (100g) + Boron 20% (20g) per 15L pump for weight and bright white skin.\n'
                '• **PGR Option:** If vegetative growth is excessive, Paclobutrazol 5ml/15L diverts energy to bulb.\n'
                '• **Irrigation:** Stop watering 12–15 days before harvest to avoid skin discoloration.',
        );
      }
    }

    // 3. गेहूँ (Wheat / Gehun)
    if (q.contains('gehun') || q.contains('wheat') || q.contains('गेहूं') || q.contains('गेहूँ') || activeCropId == 'gehun') {
      return AgroAiResponse(
        category: 'wheat',
        dosageHighlight: isHi
            ? '🌾 पहले पानी पर: 35 किलो यूरिया + 5 किलो जिंक सल्फेट 33% प्रति बीघा'
            : '🌾 1st Irrigation: 35kg Urea + 5kg Zinc Sulphate 33% per Bigha',
        quickReplies: isHi
            ? ['पीला रतुआ रोग इलाज', 'दूसरा पानी कब दें?', 'कल्ले फुटाव उपाय']
            : ['Yellow rust treatment', '2nd irrigation timing', 'Tillering tips'],
        text: isHi
            ? '🌾 **गेहूँ में ज्यादा कल्ले (फुटाव) व हरी-भरी फसल के नियम:**\n\n'
              '• **पहला पानी (CRI अवस्था):** बुवाई के 21–25 दिन बाद पहला पानी जरूर दें। इसी समय जड़ें और कल्ले बनते हैं।\n'
              '• **खाद डोज:** प्रति बीघा 30–35 किलो यूरिया के साथ 5 किलो जिंक 33% और 4 किलो बेंटोनाइट सल्फर मिलाकर डालें।\n'
              '• **पीला रतुआ (Yellow Rust) दिखे तो:** प्रोपिकोनाजोल 25% EC (टिल्ट) 20ml प्रति 15 लीटर पानी में स्प्रे करें।\n'
              '• **खरपतवार नियंत्रण:** चौड़ी पत्ती के लिए 2,4-D या संकरी पत्ती के लिए क्लोडिनाफॉप का स्प्रे बुवाई के 30–35 दिन पर करें।'
            : '🌾 **Wheat Tillering & Nutrient Management:**\n\n'
              '• **CRI Stage (21–25 Days):** First irrigation is vital for crown root and tiller formation.\n'
              '• **Fertilizer:** 35kg Urea + 5kg Zinc 33% + 4kg Sulphur per Bigha.\n'
              '• **Yellow Rust:** Spray Propiconazole 25% EC (Tilt) 20ml per 15L water.\n'
              '• **Weed Management:** Apply recommended herbicide between 30–35 days after sowing.',
      );
    }

    // 4. खाद / यूरिया / NPK / DAP (Fertilizers)
    if (q.contains('khaad') ||
        q.contains('खाद') ||
        q.contains('urea') ||
        q.contains('यूरिया') ||
        q.contains('dap') ||
        q.contains('डीएप') ||
        q.contains('npk') ||
        q.contains('fertilizer') ||
        q.contains('potash') ||
        q.contains('पोटाश')) {
      return AgroAiResponse(
        category: 'fertilizer',
        dosageHighlight: isHi
            ? '🌱 1 बीघा मानक नाप: 25-30kg DAP (बुवाई पर) + 30kg यूरिया (विभाजित डोज में)'
            : '🌱 Standard 1 Bigha Dose: 25-30kg DAP at sowing + 30kg Urea in split doses',
        quickReplies: isHi
            ? ['NPK 19:19:19 का स्प्रे कब करें?', 'जिंक और सल्फर का महत्व', 'देसी केंचुआ खाद']
            : ['When to spray NPK 19:19:19?', 'Zinc & Sulphur benefits', 'Vermicompost guide'],
        text: isHi
            ? '🧪 **खाद और उर्वरक का सही वैज्ञानिक नाप (देसी किसान गाइड):**\n\n'
              '• **बुवाई के समय:** DAP या NPK 12:32:16 बेसल डोज में दें ताकि जड़ों को फास्फोरस मिले।\n'
              '• **वृद्धि की अवस्था (25–50 दिन):** यूरिया एक साथ न डालें। इसे 2 बार में आधा-आधा (15-15 किलो) दें।\n'
              '• **स्प्रे ग्रेड वाटर सॉल्युबल खाद:**\n'
              '  - शुरुआती बढ़वार: NPK 19:19:19 (75g प्रति 15L)\n'
              '  - फूल व शाखा आते समय: 12:61:00 (70g प्रति 15L)\n'
              '  - फल/कंद फुलाव के समय: 0:52:34 या 0:0:50 (80g प्रति 15L)\n'
              '• **देसी सलाह:** हर फसल में 5 किलो दानेदार सल्फर जरूर दें, इससे तेल व चमक बढ़ती है।'
            : '🧪 **Complete Fertilizer Schedule (Practical Farmer Dose):**\n\n'
              '• **Basal at Sowing:** DAP or NPK 12:32:16 for deep root establishment.\n'
              '• **Vegetative Growth:** Split Urea application into 2 rounds rather than dumping at once.\n'
              '• **Water Soluble Foliar Sprays:**\n'
              '  - Early growth: NPK 19:19:19 (75g/15L)\n'
              '  - Flowering: NPK 12:61:00 (70g/15L)\n'
              '  - Maturation & Fruiting: NPK 0:0:50 (80g/15L)\n'
              '• **Pro Tip:** Add 4–5kg Sulphur granules to soil for disease resistance and shining produce.',
      );
    }

    // 5. कीड़े / मच्छर / इल्ली / रोग (Pest & Disease)
    if (q.contains('keet') ||
        q.contains('कीट') ||
        q.contains('keeda') ||
        q.contains('कीड़ा') ||
        q.contains('illi') ||
        q.contains('इल्ली') ||
        q.contains('machar') ||
        q.contains('मच्छर') ||
        q.contains('fungus') ||
        q.contains('फंगस') ||
        q.contains('faphund') ||
        q.contains('फफूंद') ||
        q.contains('spray') ||
        q.contains('स्प्रे')) {
      return AgroAiResponse(
        category: 'pest_disease',
        dosageHighlight: isHi
            ? '🎯 इल्ली के लिए: इमामेक्टिन बेंजोएट 5% SG (10 ग्राम) प्रति 15L पंप'
            : '🎯 For Caterpillars: Emamectin Benzoate 5% SG (10g) per 15L pump',
        quickReplies: isHi
            ? ['सफेद मच्छर का इलाज', 'फंगस व ब्लाइट का स्प्रे', 'नीम का तेल कैसे इस्तेमाल करें?']
            : ['Whitefly solution', 'Blight fungicide spray', 'Neem oil dosage'],
        text: isHi
            ? '🐛 **कीट व रोग नियंत्रण की तुरंत असरदार दवाइयां:**\n\n'
              '1. **हरी व काली इल्ली (Caterpillar):** इमामेक्टिन बेंजोएट 5% SG (10g) या कोराजन (Chlorantraniliprole) 6ml प्रति 15L पानी।\n'
              '2. **सफेद मच्छर व थ्रिप्स (Sucking Pests):** एसिटामिप्रिड 20% SP (10g) या डायफेन्थियुरॉन 50% WP (20g) प्रति 15L पानी।\n'
              '3. **पत्ती धब्बा व फफूंद (Blight/Fungus):** मैंकोजेब 75% WP (M-45) 35g या एज़ोक्सीस्ट्रोबिन + डाइफेनोकोनाज़ोल (कस्टोडिया/एमीस्टार) 15ml।\n'
              '• **देसी सावधानी:** दवा में हमेशा सिलिकॉन स्प्रेडर (स्टीकर) मिलाएँ और तेज धूप में स्प्रे न करें।'
            : '🐛 **Fast-Action Pest & Disease Management:**\n\n'
              '1. **Caterpillars & Borers:** Emamectin Benzoate 5% SG (10g) or Coragen (6ml) per 15L water.\n'
              '2. **Sucking Pests (Whitefly/Thrips):** Acetamiprid 20% SP (10g) or Diafenthiuron 50% WP (20g).\n'
              '3. **Fungal Blights:** Mancozeb 75% WP (35g) or Azoxystrobin + Difenoconazole (15ml).\n'
              '• **Farmer Tip:** Always add silicon spreader and spray in cool evening hours.',
      );
    }

    // 6. पानी / सिंचाई / मौसम (Water / Weather)
    if (q.contains('paani') ||
        q.contains('पानी') ||
        q.contains('sinchai') ||
        q.contains('सिंचाई') ||
        q.contains('water') ||
        q.contains('irrigation') ||
        q.contains('mausam') ||
        q.contains('मौसम') ||
        q.contains('pala') ||
        q.contains('पाला')) {
      return AgroAiResponse(
        category: 'irrigation',
        dosageHighlight: isHi
            ? '💧 मिट्टी की 2-3 इंच गहराई जाँचें: लड्डू बने तो पानी न दें, बिखर जाए तो दें'
            : '💧 Soil Check: If soil rolls into a moist ball wait; if powdery irrigate',
        quickReplies: isHi
            ? ['पाले से फसल कैसे बचाएँ?', 'फव्वारा या ड्रिप कौन बेहतर?', 'खाद देने के बाद पानी कब?']
            : ['Frost protection tips', 'Drip vs sprinkler', 'Watering after fertilizer'],
        text: isHi
            ? '💧 **आज सिंचाई (पानी) देने का देसी वैज्ञानिक नियम:**\n\n'
              '• **मिट्टी का टेस्ट:** खेत में 3 इंच नीचे की मिट्टी हाथ में दबाएँ। यदि लड्डू बन रहा है और नमी है तो 2–3 दिन पानी रोकें।\n'
              '• **समय का ध्यान:** पानी हमेशा सुबह 6 से 9 बजे या शाम को दें। दोपहर की धूप में पानी देने से जड़ें उबलने का खतरा रहता है।\n'
              '• **पाला (Cold wave) पड़ने पर:** हल्की सिंचाई तुरंत चालू करें या खेत की मेड़ पर शाम को धुआँ करें ताकि तापमान 2 डिग्री बढ़ जाए।\n'
              '• **हल्की बनाम भारी जमीन:** रेतीली जमीन में कम पानी बार-बार दें, काली चिकनी मिट्टी में पानी भरने न दें।'
            : '💧 **Irrigation & Soil Moisture Advice:**\n\n'
              '• **Moisture Test:** Check soil 3 inches down. If it sticks together, postpone watering for 2–3 days.\n'
              '• **Best Timing:** Irrigate early morning (6–9 AM) or evening. Avoid midday heat.\n'
              '• **Cold / Frost Alert:** Light irrigation or field-edge smoke significantly buffers against frost damage.\n'
              '• **Soil Type:** Sandy soil requires frequent light rounds; avoid stagnation in heavy black clay.',
      );
    }

    // 7. मंडी भाव (Mandi Bhav)
    if (q.contains('bhav') ||
        q.contains('भाव') ||
        q.contains('mandi') ||
        q.contains('मंडी') ||
        q.contains('price') ||
        q.contains('rate')) {
      return AgroAiResponse(
        category: 'mandi',
        dosageHighlight: isHi
            ? '📈 प्रीमियम क्वालिटी (सुपर ऊटी/बोम) लहसुन: ₹14,000 – ₹21,000 / क्विंटल'
            : '📈 Super Quality Garlic Range: ₹14,000 – ₹21,000 / Quintal',
        quickReplies: isHi
            ? ['सोयाबीन और गेहूँ का भाव', 'लहसुन कब बेचना चाहिए?', 'मंडी में ग्रेडिंग कैसे करें?']
            : ['Soybean & wheat prices', 'When to sell garlic?', 'Grading advice'],
        text: isHi
            ? '📊 **आज का प्रमुख कृषि मंडी ताजा भाव रुझान (मध्य प्रदेश / राजस्थान):**\n\n'
              '• **🧄 देसी व ऊटी लहसुन:**\n'
              '  - सुपर बोल्ड/स्पेशल: ₹16,000 – ₹22,000/क्विंटल\n'
              '  - मीडियम लड्डू माल: ₹10,000 – ₹15,000/क्विंटल\n'
              '  - हल्का / छर्री: ₹5,000 – ₹8,500/क्विंटल\n'
              '• **🌾 शरबती व लोकवान गेहूँ:** ₹2,600 – ₹3,250/क्विंटल\n'
              '• **🌱 सोयाबीन:** ₹4,300 – ₹4,850/क्विंटल\n'
              '• **🌿 चना / सरसों:** ₹5,400 – ₹6,100/क्विंटल\n'
              '• **व्यापारी टिप:** माल को ग्रेडिंग करके (बोल्ड अलग, मीडियम अलग) ले जाने से ₹1,500 प्रति क्विंटल तक ज्यादा दाम मिलता है!'
            : '📊 **Market Price Trends (Central India Mandis):**\n\n'
              '• **🧄 Garlic:**\n'
              '  - Super Bold: ₹16,000 – ₹22,000 / Qtl\n'
              '  - Medium: ₹10,000 – ₹15,000 / Qtl\n'
              '• **🌾 Wheat:** ₹2,600 – ₹3,250 / Qtl\n'
              '• **🌱 Soybean:** ₹4,300 – ₹4,850 / Qtl\n'
              '• **Tip:** Sorting and grading before taking produce to mandi yields up to 15% higher returns.',
      );
    }

    // Default warm farmer-friendly answer
    return AgroAiResponse(
      category: 'general_help',
      dosageHighlight: isHi
          ? '💡 सलाह: अपनी फसल का नाम व पत्ती/तने का लक्षण लिखकर भेजें'
          : '💡 Tip: Mention your crop name and symptoms for exact dosage',
      quickReplies: isHi
          ? ['🐛 कीड़े व फंगस का स्प्रे', '💧 आज पानी दें या नहीं?']
          : ['🐛 Pest & Spray Mix', '💧 Irrigate Today?'],
      text: isHi
          ? 'राम-राम किसान भाई! 🙏\n\n'
            'मैंने आपका सवाल नोट कर लिया है। आपकी फसल को सबसे सही और सटीक इलाज देने के लिए कृपया मुझे यह बताइए:\n'
            '1. **फसल कौनसी है?** (उदा. लहसुन, अफीम, गेहूँ, प्याज, टमाटर)\n'
            '2. **फसल कितने दिन की है?**\n'
            '3. **पत्ती या पौधे में क्या खराबी दिख रही है?** (पीलापन, धब्बे, मुड़ना या कीड़ा)\n\n'
            'यदि आपके पास पत्ती की फोटो है, तो नीचे **कैमरा बटन 📷** दबाकर फोटो भेजें — मैं तुरंत बीमारी पहचानकर सही दवा और मात्रा बता दूँगा!'
          : 'Welcome farmer friend! 🙏\n\n'
            'To give you the most accurate solution and dosage, please share:\n'
            '1. **Which crop?** (e.g. Garlic, Opium, Wheat, Onion, Tomato)\n'
            '2. **Crop age / stage in days?**\n'
            '3. **What symptom is visible?** (Yellowing, spots, curling or insects)\n\n'
            'You can also tap the **Camera button 📷** below to attach a leaf photo for instant AI diagnosis!',
    );
  }
}

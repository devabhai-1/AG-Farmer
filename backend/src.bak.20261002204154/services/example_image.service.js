/**
 * AG Farmer Example Image Service
 * Provides visual examples (disease symptoms, crop stages, pest damage, spray guides)
 * for Super Models (always-on) and Small Models (when relevant or requested).
 */

const CURATED_IMAGES = [
  // ─── लहसुन (Garlic) ───
  {
    keys: ['jalebi', 'जलेबी', 'thrips', 'थ्रिप्स', 'curl', 'मुड़', 'peelapan', 'पीला'],
    crop: 'lasun',
    titleHi: 'लहसुन में थ्रिप्स व जलेबी रोग का लक्षण',
    titleEn: 'Garlic Thrips & Leaf Curl (Jalebi Disease)',
    descHi: 'पत्तियों का मुड़ना (जलेबीनुमा आकार) और चांदी जैसे सफेद-पीले धब्बे।',
    descEn: 'Curling of leaves into spiral shapes with silvery-yellow streaks.',
    url: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'garlic crop leaves curling thrips pest damage close up farm photo',
  },
  {
    keys: ['purple', 'blotch', 'बैंगनी', 'धब्बा', 'fungs', 'फंगस', 'jhulsa', 'झुलसा'],
    crop: 'lasun',
    titleHi: 'लहसुन में पर्पल ब्लॉच (बैंगनी धब्बा रोग)',
    titleEn: 'Garlic Purple Blotch Disease',
    descHi: 'पत्तियों पर अंडाकार भूरे व बैंगनी रंग के धब्बे जो बाद में झुलसा बनते हैं।',
    descEn: 'Elliptical purplish-brown lesions on garlic foliage.',
    url: 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'garlic leaves with purple blotch fungal lesions macro agriculture photo',
  },
  {
    keys: ['kand', 'कंद', 'fulav', 'फुलाव', 'mota', 'मोटा', 'size', 'साइज', 'doda'],
    crop: 'lasun',
    titleHi: 'लहसुन कंद फुलाव व गाँठ विकास',
    titleEn: 'Garlic Bulb Sizing & Development',
    descHi: 'सफेद, ठोस व बड़े कंद की स्वस्थ अवस्था।',
    descEn: 'Healthy large white garlic bulb development.',
    url: 'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'freshly harvested large white garlic bulbs with roots agriculture photo',
  },

  // ─── अफीम (Opium / Afim) ───
  {
    keys: ['doda', 'डोडा', 'fulav', 'फुलाव', 'chira', 'चीरा', 'doodh', 'दूध', 'capsule'],
    crop: 'afim',
    titleHi: 'अफीm डोडा फुलाव व चीरा अवस्था',
    titleEn: 'Opium Poppy Capsule (Doda Development)',
    descHi: 'चमकदार हरा डोडा, सही परिपक्वता व चीरा लगाने की आदर्श स्थिति।',
    descEn: 'Healthy green opium capsule ready for lancing.',
    url: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'opium poppy green capsule close up agricultural field photo',
  },
  {
    keys: ['khakharia', 'खाखरिया', 'downy', 'mildew', 'डाउनी', 'galan', 'गलान'],
    crop: 'afim',
    titleHi: 'अफीम में खाखरिया (डाउनी मिल्ड्यू) रोग',
    titleEn: 'Opium Poppy Downy Mildew (Khakharia)',
    descHi: 'पत्तियों के निचले हिस्से पर भूरी-काली फफूंद व पत्तियों का सूखना।',
    descEn: 'Downy mildew fungal coating under leaves causing rapid dryout.',
    url: 'https://images.unsplash.com/photo-1530595467537-0b5996c41f2d?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'opium poppy leaf downy mildew fungal infection symptom agriculture photo',
  },

  // ─── गेहूँ (Wheat) ───
  {
    keys: ['ratua', 'रतुआ', 'yellow', 'rust', 'peela', 'पीला रतुआ'],
    crop: 'wheat',
    titleHi: 'गेहूँ में पीला रतुआ (Yellow Rust)',
    titleEn: 'Wheat Yellow Stripe Rust',
    descHi: 'पत्तियों पर पीले रंग की कतारबद्ध धारियां और हल्दी जैसा चूर्ण।',
    descEn: 'Linear rows of yellow pustules on wheat leaves.',
    url: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'wheat crop leaf yellow stripe rust fungal spores close up agriculture photo',
  },
  {
    keys: ['kalle', 'कल्ले', 'footav', 'फुटाव', 'tillering', 'पहला पानी', 'water'],
    crop: 'wheat',
    titleHi: 'गेहूँ में कल्ले फुटाव व वानस्पतिक वृद्धि',
    titleEn: 'Wheat Tillering Stage',
    descHi: '21 दिन की क्राउन रूट अवस्था पर भरपूर कल्ले व मजबूत जड़ें।',
    descEn: 'Healthy tillering stage in wheat field.',
    url: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'healthy green wheat crop young plants tillering lush farm field',
  },

  // ─── प्याज (Onion) ───
  {
    keys: ['onion', 'प्याज', 'thrips', 'थ्रिप्स', 'twist', 'मरोड़'],
    crop: 'onion',
    titleHi: 'प्याज में थ्रिप्स व पीलापन',
    titleEn: 'Onion Thrips & Tip Burn',
    descHi: 'पत्तियों पर सफेद खुरचन व नोक का पीला होकर सूखना।',
    descEn: 'Silvery white patches and curling on onion leaves.',
    url: 'https://images.unsplash.com/photo-1518977822534-7049a61ee0c2?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'onion field leaves affected by thrips pests realistic agriculture photo',
  },

  // ─── टमाटर / मिर्च (Tomato / Chilli) ───
  {
    keys: ['chilli', 'मिर्च', 'murdia', 'मुरड़िया', 'curl', 'मरोड़िया'],
    crop: 'chilli',
    titleHi: 'मिर्च में मुरड़िया (पत्ती मरोड़ रोग)',
    titleEn: 'Chilli Leaf Curl Virus / Mites',
    descHi: 'पत्तियों का नाव की तरह ऊपर या नीचे मुड़ना व पौधों का बौनापन।',
    descEn: 'Upward/downward cupping of chilli leaves due to thrips/mites/virus.',
    url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'chilli plant leaf curl disease thrips virus damage farm photo',
  },
  {
    keys: ['tomato', 'टमाटर', 'blight', 'झुलसा', 'borer', 'छेदक'],
    crop: 'tomato',
    titleHi: 'टमाटर में फल छेदक व झुलसा लक्षण',
    titleEn: 'Tomato Fruit Borer / Blight',
    descHi: 'टमाटर के फलों में इल्ली के छेद व पत्ती झुलसा।',
    descEn: 'Fruit borer caterpillar damage on tomato crop.',
    url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'tomato crop pest caterpillar damage on green fruit close up photo',
  },

  // ─── दवा / स्प्रे संदर्भ (Chemical / Spray) ───
  {
    keys: ['spray', 'स्प्रे', 'nozzle', 'नोजल', 'dawa', 'दवा', 'pump', 'पंप'],
    crop: 'general',
    titleHi: 'सही फोलियर स्प्रे विधि व नोजल गाइड',
    titleEn: 'Foliar Spray Technique Guide',
    descHi: 'पौधों के ऊपर व पत्ती के नीचे समान कवरेज हेतु फ्लैट फैन नोजल का उपयोग।',
    descEn: 'Proper foliar application with even leaf underside coverage.',
    url: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?auto=format&fit=crop&w=800&q=80',
    fallbackPrompt: 'agricultural crop spraying farmer with backpack sprayer field photo',
  },
];

function generateDynamicUrl(promptText) {
  const clean = String(promptText || 'agricultural crop disease symptom realistic photo')
    .replace(/[^\w\s-]/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
  return `https://image.pollinations.ai/prompt/${encodeURIComponent(clean)}?width=768&height=512&nologo=true`;
}

function normalizeCrop(raw) {
  const c = String(raw || '').toLowerCase().trim();
  if (c.includes('lasun') || c.includes('lahsun') || c.includes('garlic')) return 'garlic';
  if (c.includes('afim') || c.includes('afeem') || c.includes('opium') || c.includes('poppy')) return 'afim';
  if (c.includes('wheat') || c.includes('gehu') || c.includes('gehun')) return 'wheat';
  if (c.includes('onion') || c.includes('pyaj') || c.includes('pyaz')) return 'onion';
  if (c.includes('chilli') || c.includes('chili') || c.includes('mirch')) return 'chilli';
  if (c.includes('tomato') || c.includes('tamatar')) return 'tomato';
  return c;
}

export const ExampleImageService = {
  /**
   * Resolve an example image for the AI response
   */
  resolve({
    cropId = null,
    query = '',
    answerText = '',
    modelExampleImage = null,
    isSuper = false,
    planId = 'free',
  }) {
    const qLower = String(query || '').toLowerCase();
    const aLower = String(answerText || '').toLowerCase();
    const normCrop = normalizeCrop(cropId);

    // 1. If the AI model returned a valid image with an explicit URL
    if (modelExampleImage && typeof modelExampleImage === 'object') {
      const u = modelExampleImage.url || modelExampleImage.imageUrl;
      if (u && typeof u === 'string' && u.startsWith('http')) {
        return {
          url: u,
          title: modelExampleImage.title || 'उदाहरण संदर्भ (Visual Example)',
          description: modelExampleImage.description || modelExampleImage.caption || '',
        };
      }
    }

    // 2. Check if user query explicitly asked for an image/photo
    const askedForPhoto =
      qLower.includes('photo') ||
      qLower.includes('फोटो') ||
      qLower.includes('image') ||
      qLower.includes('तस्वीर') ||
      qLower.includes('चित्र') ||
      qLower.includes('दिखाओ') ||
      qLower.includes('कैसा दिखता') ||
      qLower.includes('सिक्का') ||
      qLower.includes('example');

    // 3. Search curated database
    let matchedCurated = null;
    const fullSearch = `${qLower} ${aLower} ${normCrop}`;
    for (const item of CURATED_IMAGES) {
      const itemCrop = normalizeCrop(item.crop);
      if (itemCrop !== 'general' && normCrop && itemCrop !== normCrop) {
        if (!fullSearch.includes(itemCrop)) continue;
      }
      const match = item.keys.some((k) => fullSearch.includes(k.toLowerCase()));
      if (match) {
        matchedCurated = item;
        break;
      }
    }

    const hasModelSuggestion = Boolean(
      modelExampleImage && (modelExampleImage.title || modelExampleImage.searchKeyword || modelExampleImage.url)
    );

    // Super plans (₹2,650, ₹13,500) ALWAYS provide an image
    // Small models provide an image if model suggested it OR user asked for photo OR diagnosis matches
    const shouldProvide = isSuper || askedForPhoto || hasModelSuggestion || Boolean(matchedCurated);

    if (!shouldProvide) {
      return null;
    }

    if (matchedCurated) {
      return {
        url: matchedCurated.url,
        title: matchedCurated.titleHi,
        description: matchedCurated.descHi,
      };
    }

    // 4. Model gave title or searchKeyword, generate dynamic high-res visual
    if (modelExampleImage && (modelExampleImage.title || modelExampleImage.searchKeyword)) {
      const keyword = modelExampleImage.searchKeyword || modelExampleImage.title;
      const prompt = `agricultural farm crop ${normCrop || ''} ${keyword} realistic photography close up`;
      return {
        url: generateDynamicUrl(prompt),
        title: modelExampleImage.title || 'फसल लक्षण व उदाहरण संदर्भ',
        description: modelExampleImage.description || 'रोग/कीट पहचान व उपचार हेतु सचित्र संदर्भ।',
      };
    }

    // 5. Fallback for Super plans: Generate dynamic image based on query & crop
    if (isSuper) {
      const topicSnippet = qLower.slice(0, 80).replace(/[^\w\s]/g, ' ');
      const prompt = `agricultural crop ${normCrop || ''} plant leaves ${topicSnippet} farm realistic photo`;
      const title = normCrop ? `${normCrop.toUpperCase()} - उदाहरण व पहचान संदर्भ` : 'कृषि रोग व पहचान संदर्भ (Visual Guide)';
      return {
        url: generateDynamicUrl(prompt),
        title,
        description: 'रोग, कीट व पोषण अवस्था की सही पहचान के लिए उदाहरण संदर्भ।',
      };
    }

    return null;
  },
};

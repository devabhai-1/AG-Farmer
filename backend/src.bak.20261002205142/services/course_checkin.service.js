/**
 * Daily course greeting. No canned disease or medicine chips.
 */

function getTodayString() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

const CROP_NAMES = {
  afim: { nameHi: 'अफ़ीम', nameEn: 'Opium' },
  afeem: 'afim',
  opium: 'afim',
  lahsun: { nameHi: 'लहसुन', nameEn: 'Garlic' },
  lasun: 'lahsun',
  garlic: 'lahsun',
  gehu: { nameHi: 'गेहूँ', nameEn: 'Wheat' },
  wheat: 'gehu',
  sarson: { nameHi: 'सरसों', nameEn: 'Mustard' },
  mustard: 'sarson',
  pyaj: { nameHi: 'प्याज', nameEn: 'Onion' },
  onion: 'pyaj',
  chana: { nameHi: 'चना', nameEn: 'Chickpea' },
  gram: 'chana',
  mirch: { nameHi: 'मिर्च', nameEn: 'Chilli' },
  chilli: 'mirch',
  aalu: { nameHi: 'आलू', nameEn: 'Potato' },
  potato: 'aalu',
  tamatar: { nameHi: 'टमाटर', nameEn: 'Tomato' },
  tomato: 'tamatar',
  soyabean: { nameHi: 'सोयाबीन', nameEn: 'Soybean' },
  soybean: 'soyabean',
  dhan: { nameHi: 'धान', nameEn: 'Paddy' },
  rice: 'dhan',
  paddy: 'dhan',
};

function resolveCrop(cropId) {
  if (!cropId) return null;
  const norm = String(cropId).toLowerCase().trim().replace(/[^a-z0-9]/g, '');
  const entry = CROP_NAMES[norm];
  if (typeof entry === 'string') return CROP_NAMES[entry] || null;
  return entry || null;
}

export const CourseCheckinService = {
  getCheckin({
    cropId,
    cropName = null,
    lang = 'hi',
    dayNumber = 1,
  } = {}) {
    const isHi = lang !== 'en';
    const todayStr = getTodayString();
    const crop = resolveCrop(cropId);
    const displayName =
      cropName ||
      (isHi ? crop?.nameHi : crop?.nameEn) ||
      cropId ||
      (isHi ? 'फसल' : 'Crop');

    const text = isHi
      ? `राम राम किसान भाई!\nआज आपकी ${displayName} कैसी है? जो खेत में दिखे वही लिखें, या फोटो भेजें।`
      : `राम राम किसान भाई!\nHow is your ${displayName} today? Write what you see in the field, or send a photo.`;

    return {
      ok: true,
      checkin: {
        id: `checkin_${cropId || 'crop'}_${todayStr}`,
        cropId: cropId || null,
        cropName: displayName,
        date: todayStr,
        text,
        quickReplies: [],
        dayNumber: Number(dayNumber) || 1,
        meta: {
          kind: 'daily_checkin',
          source: 'course_checkin_service',
          today: todayStr,
        },
      },
    };
  },
};

import 'package:flutter/material.dart';

class AgroColors {
  // === 3-TIER PREMIUM AASMANI PALETTE (3 रंगों की गहरा-कम गहरा लेयर्ड थीम) ===
  
  // 1. गहरा आसमानी (Deep Dark Royal Azure - TONE 1)
  // उपयोग: मुख्य हेडर, डार्क कार्ड्स, हाई-कंट्रास्ट टेक्स्ट व शैडोज
  static const Color skyDeep = Color(0xFF032B43);       // गहरा नेवी स्काई
  static const Color skyDeepNavy = Color(0xFF073A5C);   // गहरा ओशनिक स्काई
  static const Color forest = Color(0xFF032B43);        // गहरा स्काई एंकर
  static const Color charcoal = Color(0xFF07243B);      // गहरा हाई-कंट्रास्ट टेक्स्ट

  // 2. मीडियम / मुख्य वाइब्रेंट आसमानी (Vibrant Electric Sky - TONE 2)
  // उपयोग: मुख्य बटन्स, एक्टिव टैब्स, सिग्नेचर आइकन्स और वाइब्रेंट एक्सेंट्स
  static const Color skyPrimary = Color(0xFF0284C7);    // क्लासिक स्काई 600
  static const Color skyVibrant = Color(0xFF0EA5E9);    // वाइब्रेंट स्काई 500
  static const Color deepGreen = Color(0xFF0284C7);     // प्राइमरी स्काई
  static const Color leaf = Color(0xFF0EA5E9);          // रेडियंट स्काई
  static const Color gold = Color(0xFF0284C7);          // एक्सेंट स्काई
  static const Color richGold = Color(0xFF0369A1);      // गहरा एक्सेंट (Sky 700)

  // 3. कम गहरा / हल्का आइस आसमानी (Soft Ice Sky / Powder Azure - TONE 3)
  // उपयोग: कार्ड्स बैकग्राउंड, सौम्य चिप्स, इनपुट बॉर्डर और शांत बैकड्रॉप
  static const Color skyLight = Color(0xFF38BDF8);      // ग्लोइंग हल्का आसमानी (Sky 400)
  static const Color skyIce = Color(0xFFBAE6FD);        // आइस-स्काई क्रिस्प बॉर्डर (Sky 200)
  static const Color skySoft = Color(0xFFE0F2FE);       // सौम्य हल्का स्काई वाश (Sky 100)
  static const Color skyMist = Color(0xFFF0F9FF);       // शांत स्काई क्लाउड बैकग्राउंड (Sky 50)
  static const Color mint = Color(0xFF38BDF8);          // ग्लोइंग स्काई
  static const Color softMint = Color(0xFFE0F2FE);      // हल्का स्काई
  static const Color mist = Color(0xFFF0F9FF);          // स्काई क्लाउड
  static const Color champagne = Color(0xFFBAE6FD);     // आइस बॉर्डर
  static const Color softGold = Color(0xFFE0F2FE);      // सॉफ्ट स्काई फिल

  // न्यूट्रल्स व यूटिलिटी कलर्स
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate = Color(0xFF4A728F);         // म्यूटेड स्लेट स्काई टेक्स्ट
  static const Color danger = Color(0xFFEF4444);
  static const Color sky = Color(0xFF0EA5E9);

  // डार्क मोड पैलेट (डार्क में भी 3 लेयर्स)
  static const Color night = Color(0xFF031626);         // गहरा 1: अल्ट्रा डार्क ओशन बैकग्राउंड
  static const Color nightCard = Color(0xFF082236);     // गहरा 2: मिडनाइट स्काई कार्ड
  static const Color nightElevated = Color(0xFF0E314D); // गहरा 3: एलिवेटेड स्काई कार्ड
  static const Color nightBorder = Color(0xFF1B4E74);   // डार्क स्काई बॉर्डर
  static const Color nightText = Color(0xFFF0F9FF);     // क्रिस्प स्काई व्हाइट टेक्स्ट
  static const Color nightMuted = Color(0xFF93C5FD);    // सॉफ्ट स्काई ब्लू टेक्स्ट
  static const Color nightGold = Color(0xFF38BDF8);     // ग्लोइंग स्काई 400 एक्सेंट

  // 3-रंगों का प्रीमियम हीरो ग्रेडिएंट (गहरा -> मीडियम -> हल्का)
  static const LinearGradient premiumHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF032B43), // 1. गहरा आसमानी (Deep Dark Sky)
      Color(0xFF0284C7), // 2. मीडियम वाइब्रेंट आसमानी (Sky 600)
      Color(0xFF0EA5E9), // 2.5 रेडियंट आसमानी (Sky 500)
      Color(0xFF38BDF8), // 3. कम गहरा / हल्का आसमानी (Sky 400)
    ],
    stops: [0.0, 0.38, 0.72, 1.0],
  );

  static const LinearGradient premiumHeroDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF021626), // गहरा
      Color(0xFF07304F), // मीडियम गहरा
      Color(0xFF0369A1), // मीडियम
      Color(0xFF0284C7), // कम गहरा
    ],
    stops: [0.0, 0.36, 0.72, 1.0],
  );

  // 3-रंगों का शीन ग्रेडिएंट (कम गहरा -> ग्लो -> गहरा)
  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFBAE6FD), // 3. कम गहरा / आइस स्काई
      Color(0xFF38BDF8), // 2.5 ग्लोइंग स्काई
      Color(0xFF0284C7), // 2. मीडियम स्काई
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // 3-रंगों का कार्ड ग्रेडिएंट (गहरा -> मीडियम -> हल्का)
  static const LinearGradient triColorCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF032B43), // गहरा
      Color(0xFF0284C7), // मीडियम
      Color(0xFF38BDF8), // कम गहरा
    ],
    stops: [0.0, 0.55, 1.0],
  );
}

extension AgroThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get agroCard => isDark ? AgroColors.nightCard : AgroColors.white;

  Color get agroScaffold => isDark ? AgroColors.night : AgroColors.mist;

  Color get agroBorder => isDark ? AgroColors.nightBorder : const Color(0xFFBAE6FD);

  Color get agroText => isDark ? AgroColors.nightText : AgroColors.charcoal;

  Color get agroMuted => isDark ? AgroColors.nightMuted : AgroColors.slate;
  Color get agroTextMuted => agroMuted;

  Color get agroSoftFill => isDark ? AgroColors.nightElevated : AgroColors.softMint;

  Color get agroSoftGoldFill =>
      isDark ? const Color(0xFF102C42) : AgroColors.softGold;

  Color get agroNavBg => isDark ? AgroColors.nightCard : AgroColors.white;

  Color get agroGold => isDark ? AgroColors.nightGold : AgroColors.deepGreen;

  LinearGradient get agroHeaderGradient =>
      isDark ? AgroColors.premiumHeroDark : AgroColors.premiumHero;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AgroColors.leaf,
        primary: AgroColors.deepGreen,
        secondary: AgroColors.mint,
        surface: AgroColors.white,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AgroColors.mist,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AgroColors.charcoal,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AgroColors.white,
        selectedItemColor: AgroColors.deepGreen,
        unselectedItemColor: AgroColors.slate,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AgroColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: const Color(0xFFBAE6FD),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgroColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AgroColors.deepGreen, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgroColors.deepGreen,
          foregroundColor: AgroColors.white,
          elevation: 0,
          shadowColor: AgroColors.forest.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AgroColors.deepGreen,
          side: const BorderSide(color: AgroColors.leaf, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AgroColors.softMint,
        selectedColor: AgroColors.leaf,
        labelStyle: const TextStyle(color: AgroColors.deepGreen, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AgroColors.charcoal,
        displayColor: AgroColors.charcoal,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AgroColors.mint,
        secondary: AgroColors.nightGold,
        surface: AgroColors.nightCard,
        onPrimary: AgroColors.night,
        onSecondary: AgroColors.night,
        onSurface: AgroColors.nightText,
        error: AgroColors.danger,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AgroColors.night,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AgroColors.nightText,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AgroColors.nightCard,
        selectedItemColor: AgroColors.mint,
        unselectedItemColor: AgroColors.nightMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AgroColors.nightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: AgroColors.nightBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgroColors.nightElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: const TextStyle(color: AgroColors.nightMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AgroColors.nightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AgroColors.nightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AgroColors.mint, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgroColors.mint,
          foregroundColor: AgroColors.night,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AgroColors.mint,
          side: const BorderSide(color: AgroColors.mint, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AgroColors.nightElevated,
        selectedColor: AgroColors.deepGreen,
        labelStyle: const TextStyle(color: AgroColors.nightText, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AgroColors.nightBorder),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AgroColors.nightText,
        displayColor: AgroColors.nightText,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AgroColors.nightElevated,
        contentTextStyle: TextStyle(color: AgroColors.nightText),
      ),
    );
  }
}

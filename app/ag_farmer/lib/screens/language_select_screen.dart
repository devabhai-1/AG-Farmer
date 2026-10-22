import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/app_services.dart';
import '../services/language_service.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import 'main_shell.dart';

class LanguageSelectScreen extends StatefulWidget {
  final LanguageService languageService;
  final bool fromSettings;

  const LanguageSelectScreen({
    super.key,
    required this.languageService,
    this.fromSettings = false,
  });

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> with PageHit {
  @override
  String get analyticsPage => 'language';
  AppLang? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.languageService.lang ?? AppLang.hindi;
  }

  Future<void> _continue() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.languageService.setLanguage(_selected!);
      if (!mounted) return;

      if (widget.fromSettings) {
        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => MainShell(profileService: profileService)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AgroColors.premiumHeroDark : AgroColors.premiumHero,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.fromSettings)
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                              ),
                            ),
                          const Spacer(flex: 1),
                          const BrandLogo(size: 96, radius: 26),
                          const SizedBox(height: 24),
                          const Text(
                            'Choose Language / भाषा चुनें',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select Hindi or English. Full app layout & chat will follow your choice.\nहिन्दी या अंग्रेज़ी चुनें — पूरा ऐप उसी भाषा में चलेगा।',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.45,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _LangCard(
                            title: 'English',
                            subtitle: 'Continue in English',
                            badge: 'EN',
                            selected: _selected == AppLang.english,
                            onTap: () => setState(() => _selected = AppLang.english),
                          ),
                          const SizedBox(height: 12),
                          _LangCard(
                            title: 'हिन्दी',
                            subtitle: 'हिन्दी में जारी रखें',
                            badge: 'हि',
                            selected: _selected == AppLang.hindi,
                            onTap: () => setState(() => _selected = AppLang.hindi),
                          ),
                          const Spacer(flex: 2),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_selected == null || _saving)
                                  ? null
                                  : _continue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF032B43),
                                disabledBackgroundColor: Colors.white24,
                                disabledForegroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                _selected == AppLang.hindi ? 'आगे बढ़ें' : 'Continue',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF032B43),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _LangCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected = solid white + dark text (readable on blue hero).
    // Unselected = translucent glass + white text.
    final titleColor = selected ? const Color(0xFF032B43) : Colors.white;
    final subColor = selected
        ? const Color(0xFF4A728F)
        : Colors.white.withValues(alpha: 0.9);
    final iconColor = selected ? const Color(0xFF0284C7) : Colors.white70;
    final fill = selected ? Colors.white : Colors.white.withValues(alpha: 0.16);
    final badgeBg = selected
        ? const Color(0xFFE0F2FE)
        : Colors.white.withValues(alpha: 0.18);
    final badgeFg = selected ? const Color(0xFF032B43) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFFBAE6FD)
                  : Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subColor,
                          fontWeight: FontWeight.w600,
                          inherit: false,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/agro_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import '../widgets/soft_card.dart';
import 'language_select_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenJankari;
  final void Function(String query, String? cropId)? onSelectTopic;

  const HomeScreen({
    super.key,
    required this.onOpenChat,
    required this.onOpenCourses,
    required this.onOpenJankari,
    this.onSelectTopic,
  });

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final isDark = context.isDark;

    return Column(
      children: [
        PremiumHeader(
          subtitle: s.homeSubtitle,
          showBrand: true,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0xFF071B2B), Color(0xFF04131F)]
                    : const [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                SoftCard(
                  premiumBorder: true,
                  padding: EdgeInsets.zero,
                  gradient: isDark
                      ? AgroColors.premiumHeroDark
                      : AgroColors.premiumHero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AgroColors.goldSheen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s.welcomeFarmer,
                            style: const TextStyle(
                              color: AgroColors.forest,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.homeHero,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.homeHeroSub,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.45,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: onOpenChat,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AgroColors.forest,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  s.askAgroGpt,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onOpenCourses,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AgroColors.champagne,
                                  side: BorderSide(
                                    color: AgroColors.champagne.withValues(alpha: 0.85),
                                    width: 1.4,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  s.fasalCourse,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: AgroColors.goldSheen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.premiumFeatures,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.agroText,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FeatureTile(
                  icon: Icons.auto_awesome_rounded,
                  title: s.featureChatTitle,
                  subtitle: s.featureChatSub,
                  onTap: onOpenChat,
                ),
                _FeatureTile(
                  icon: Icons.agriculture_rounded,
                  title: s.featureCourseTitle,
                  subtitle: s.courseLoginGateSub,
                  onTap: onOpenCourses,
                ),
                _FeatureTile(
                  icon: Icons.menu_book_rounded,
                  title: s.openJankari,
                  subtitle: s.jankariSubtitle,
                  onTap: onOpenJankari,
                ),
                const SizedBox(height: 8),
                SoftCard(
                  premiumBorder: true,
                  color: context.agroSoftGoldFill,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AgroColors.goldSheen,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AgroColors.gold.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AgroColors.forest,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.premiumThemeActive,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: context.agroText,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.premiumThemeSub,
                              style: TextStyle(
                                color: context.agroMuted,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  onTap: () {
                    final service = AgroScope.of(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LanguageSelectScreen(
                          languageService: service,
                          fromSettings: true,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.agroSoftFill,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: context.agroGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.changeLanguage,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: context.agroText,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.agroGold),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        premiumBorder: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.isDark
                      ? const [Color(0xFF102C42), Color(0xFF0369A1)]
                      : const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.agroText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.agroMuted,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.agroGold),
          ],
        ),
      ),
    );
  }
}

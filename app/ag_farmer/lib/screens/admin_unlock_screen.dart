import 'package:flutter/material.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';
import 'admin_panel_screen.dart';

class AdminUnlockScreen extends StatelessWidget {
  const AdminUnlockScreen({super.key});

  Future<void> _pay(BuildContext context) async {
    final s = AgroScope.of(context).s;
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.loginRequired)));
      return;
    }

    final ok = await adminService.payAndUnlock(
      email: authService.profile?.email ?? authService.user?.email,
      name: authService.profile?.name ?? authService.user?.displayName,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminService.error ?? s.errGeneric)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AgroColors.deepGreen,
        content: Text(s.adminUnlocked),
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    PageAnalytics.instance.hit('admin_unlock');
    final s = AgroScope.of(context).s;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1205), Color(0xFF3A2A0A), Color(0xFFC9A227)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.adminPanelTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.adminUnlockSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
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
            child: ListenableBuilder(
              listenable: adminService,
              builder: (context, _) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16, 18, 16, 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    SoftCard(
                      color: context.agroSoftGoldFill,
                      child: Text(
                        s.adminPayToUnlockNote,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.agroText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A1205), Color(0xFFC9A227)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.adminUnlockPlan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.adminUnlockBenefits,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Price shrinks before the pay button is pushed
                              // off-screen on narrow (320dp) phones.
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '₹${adminService.price}',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: adminService.busy ? null : () => _pay(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1A1205),
                                ),
                                child: adminService.busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(s.payAndUnlockAdmin),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subscription_plan.dart';
import '../models/support_request.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';

class LiveSupportScreen extends StatefulWidget {
  const LiveSupportScreen({super.key});

  @override
  State<LiveSupportScreen> createState() => _LiveSupportScreenState();
}

class _LiveSupportScreenState extends State<LiveSupportScreen> with PageHit {
  @override
  String get analyticsPage => 'live_support';
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    supportService.startListening();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final s = AgroScope.of(context).s;
    if (profileService.plan == PlanTier.free) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.liveSupportPaidOnly)));
      return;
    }

    final req = await supportService.submitLiveSupportRequest(
      plan: profileService.plan,
      message: _message.text,
    );

    if (!mounted) return;
    if (req == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(supportService.error ?? s.errGeneric)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AgroColors.deepGreen,
        content: Text('${s.tokenGenerated}: ${req.token}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final paid = profileService.plan != PlanTier.free;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDark
                    ? const [Color(0xFF031626), Color(0xFF082F49), Color(0xFF0369A1)]
                    : const [AgroColors.forest, AgroColors.deepGreen, AgroColors.mint],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
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
                            s.liveSupportTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.liveSupportSubtitle,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.35),
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
              listenable: Listenable.merge([supportService, profileService]),
              builder: (context, _) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16, 18, 16, 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    SoftCard(
                      color: paid ? context.agroSoftFill : context.agroSoftGoldFill,
                      child: Text(
                        paid ? s.liveSupportReady : s.liveSupportPaidOnly,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.agroText,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _message,
                            maxLines: 3,
                            enabled: paid,
                            decoration: InputDecoration(
                              labelText: s.supportMessageLabel,
                              hintText: s.supportMessageHint,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: (!paid || supportService.busy) ? null : _generate,
                            icon: const Icon(Icons.vpn_key_rounded),
                            label: Text(
                              supportService.busy ? s.generatingToken : s.generateLiveToken,
                            ),
                          ),
                          if (supportService.lastToken != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF032B43), Color(0xFF0284C7), Color(0xFF38BDF8)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.yourLiveToken,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          supportService.lastToken!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: supportService.lastToken!),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(s.tokenCopied)),
                                          );
                                        },
                                        icon: const Icon(Icons.copy_rounded, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    s.tokenSentToAdmin,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.mySupportRequests,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (supportService.myRequests.isEmpty)
                      SoftCard(
                        child: Text(
                          s.noSupportRequests,
                          style: TextStyle(color: context.agroMuted),
                        ),
                      )
                    else
                      ...supportService.myRequests.map((r) => _RequestTile(request: r)),
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

class _RequestTile extends StatelessWidget {
  final SupportRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.token,
                    style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(request.message, style: TextStyle(color: context.agroMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${s.statusLabel}: ${request.status.name}',
              style: TextStyle(color: context.agroMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SupportStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SupportStatus.pending => AgroColors.gold,
      SupportStatus.active => AgroColors.sky,
      SupportStatus.resolved => AgroColors.leaf,
      SupportStatus.closed => AgroColors.slate,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }
}

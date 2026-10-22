import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/support_request.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../services/crop_course_service.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with PageHit {
  @override
  String get analyticsPage => 'admin_panel';
  SupportStatus? _filter;

  @override
  void initState() {
    super.initState();
    supportService.startListening();
  }

  Future<void> _setStatus(SupportRequest request, SupportStatus status) async {
    final noteCtrl = TextEditingController(text: request.adminNote ?? '');
    final s = AgroScope.of(context).s;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.agroCard,
        title: Text(s.updateRequestStatus),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.tokenLabel}: ${request.token}'),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: s.adminNoteLabel),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.ok)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.saveStatus),
          ),
        ],
      ),
    );

    if (ok == true) {
      await supportService.updateStatus(
        requestId: request.id,
        status: status,
        adminNote: noteCtrl.text.trim(),
      );
    }
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF04110C), Color(0xFF0B3D2E), Color(0xFFC9A227)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            s.adminControlPanel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AgroColors.gold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s.adminUnlockedBadge,
                            style: const TextStyle(
                              color: AgroColors.forest,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        s.adminPanelSubtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: s.filterAll,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...SupportStatus.values.map(
                    (st) => _FilterChip(
                      label: st.name.toUpperCase(),
                      selected: _filter == st,
                      onTap: () => setState(() => _filter = st),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([supportService, cropCourseService]),
              builder: (context, _) {
                final list = _filter == null
                    ? supportService.allRequests
                    : supportService.allRequests.where((e) => e.status == _filter).toList();
                final courses = cropCourseService.myCourses;

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Text(
                      s.adminCourseSection,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (courses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          s.isHi
                              ? 'अभी कोई चालू कोर्स नहीं'
                              : 'No enrolled courses yet',
                          style: TextStyle(color: context.agroMuted),
                        ),
                      )
                    else
                      ...courses.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.emoji} ${e.name(s.isHi)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: context.agroText,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  e.isClosed
                                      ? e.dateRangeLabel(s.isHi)
                                      : '${e.startOnlyLabel(s.isHi)} · ${s.courseDayProgress(e.dayNumber)}',
                                  style: TextStyle(
                                    color: context.agroMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (e.pendingAdminClose && !e.isClosed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      s.isHi
                                          ? 'किसान के जवाब का इंतज़ार…'
                                          : 'Waiting for farmer reply…',
                                      style: TextStyle(
                                        color: context.agroGold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (!e.isClosed) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _ActionBtn(
                                        label: s.adminSendClosePrompt,
                                        onTap: () async {
                                          await cropCourseService
                                              .setPendingAdminClose(
                                            e.cropId,
                                            isHi: s.isHi,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text(s.adminClosePromptSent),
                                            ),
                                          );
                                        },
                                      ),
                                      _ActionBtn(
                                        label: s.adminForceCloseCourse,
                                        onTap: () async {
                                          await cropCourseService.closeCourse(
                                            e.cropId,
                                            isHi: s.isHi,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text(s.adminCourseClosedNow),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Text(
                      s.isHi ? 'सपोर्ट रिक्वेस्ट' : 'Support requests',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            s.noSupportRequests,
                            style: TextStyle(color: context.agroMuted),
                          ),
                        ),
                      )
                    else
                      ...list.map((r) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.token,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: context.agroText,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: r.token));
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(s.tokenCopied)),
                                        );
                                      },
                                      icon: Icon(Icons.copy_rounded,
                                          color: context.agroMuted, size: 18),
                                    ),
                                  ],
                                ),
                                Text('${r.userName} • ${r.userPhone}',
                                    style:
                                        TextStyle(color: context.agroMuted)),
                                Text(r.userEmail,
                                    style: TextStyle(
                                        color: context.agroMuted,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(
                                    '${s.planLabel}: ${r.planId.toUpperCase()}',
                                    style: TextStyle(
                                        color: context.agroText,
                                        fontWeight: FontWeight.w700)),
                                Text(r.message,
                                    style: TextStyle(
                                        color: context.agroMuted,
                                        fontSize: 13)),
                                if (r.adminNote?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '${s.adminNoteLabel}: ${r.adminNote}',
                                      style: TextStyle(
                                          color: context.agroGold,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _ActionBtn(
                                      label: 'PENDING',
                                      onTap: () =>
                                          _setStatus(r, SupportStatus.pending),
                                    ),
                                    _ActionBtn(
                                      label: 'ACTIVE',
                                      onTap: () =>
                                          _setStatus(r, SupportStatus.active),
                                    ),
                                    _ActionBtn(
                                      label: 'RESOLVED',
                                      onTap: () =>
                                          _setStatus(r, SupportStatus.resolved),
                                    ),
                                    _ActionBtn(
                                      label: 'CLOSED',
                                      onTap: () =>
                                          _setStatus(r, SupportStatus.closed),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AgroColors.leaf,
        labelStyle: TextStyle(
          color: selected ? Colors.white : context.agroText,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: context.agroSoftFill,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 10,
        color: context.agroText,
      ),
    );
  }
}

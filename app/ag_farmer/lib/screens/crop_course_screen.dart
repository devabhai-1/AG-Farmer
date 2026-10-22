import '../platform/local_file.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import '../l10n/strings.dart';
import '../services/agro_scope.dart';
import '../services/ai_provider_prefs.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../services/crop_course_service.dart';
import '../services/chat_pdf.dart';
import '../services/course_summary_notify.dart';
import '../services/feature_controls.dart';
import '../services/leaf_photo.dart';
import '../services/screen_actions.dart';
import '../services/screen_pack.dart';
import '../widgets/server_body.dart';
import '../widgets/server_prompts.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_report_sheet.dart';
import '../widgets/answer_pipe.dart';
import '../theme/front_style.dart';
import '../widgets/brand_logo.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/chat_answer_body.dart';
import '../widgets/message_copy_menu.dart';
import '../widgets/chat_limit_notice.dart';
import '../widgets/plan_unlock_sheet.dart';
import '../widgets/soft_card.dart';
import '../widgets/swipe_message_time.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_crop_style.dart';
import '../widgets/create_custom_course_sheet.dart';
import 'auth/login_screen.dart';
import 'course_calendar_screen.dart';
import 'subscription_screen.dart';
import 'credit_token_screen.dart';
import 'video_call_screen.dart';
import 'voice_live_screen.dart';

/// Fasal Course: My Courses → other crops → Create New. Chat stays simple.
class CropCourseScreen extends StatefulWidget {
  const CropCourseScreen({super.key});

  @override
  State<CropCourseScreen> createState() => _CropCourseScreenState();
}

class _CropCourseScreenState extends State<CropCourseScreen> {
  bool _inChat = false;

  @override
  void initState() {
    super.initState();
    // Refresh courses in the background. Do not close a chat the user just opened.
    cropCourseService.load();
    unawaited(screenPack.refresh());
  }

  Future<void> _requireLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openCourse(CropItem crop) async {
    final s = AgroScope.of(context).s;
    if (!ApiClient.instance.hasSession) {
      await _requireLogin();
      if (!mounted || !ApiClient.instance.hasSession) return;
    }
    await cropCourseService.selectCrop(crop, isHi: s.isHi);
    if (!mounted) return;
    setState(() => _inChat = true);
  }

  Future<void> _openEnrollment(CourseEnrollment e) async {
    final crop = catalogService.cropById(e.cropId) ??
        CropItem(
          id: e.cropId,
          nameEn: e.nameEn,
          nameHi: e.nameHi,
          emoji: e.emoji,
          minPlan: PlanTier.advanced,
          priority: 500,
        );
    await cropCourseService.switchToCrop(e.cropId);
    if (!mounted) return;
    setState(() => _inChat = true);
    // Ensure chat exists
    if (cropCourseService.messagesFor(e.cropId).isEmpty) {
      final s = AgroScope.of(context).s;
      await cropCourseService.selectCrop(crop, isHi: s.isHi);
    }
  }

  Future<void> _createNew() async {
    final crop = await showCreateNewCourseSheet(
      context,
      asFasalCourse: true,
    );
    if (crop == null || !mounted) return;
    await _openCourse(crop);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([authService, cropCourseService, profileService]),
      builder: (context, _) {
        if (!authService.isLoggedIn) {
          return const LoginScreen(embedded: true);
        }
        if (_inChat) {
          return FrontScope(
            child: _CourseChatView(
              onBack: () => setState(() => _inChat = false),
              onAddCrop: () async {
                setState(() => _inChat = false);
                await _createNew();
              },
            ),
          );
        }
        return FrontScope(
          child: _CourseHub(
            onOpenCourse: _openCourse,
            onOpenEnrollment: _openEnrollment,
            onCreateNew: _createNew,
          ),
        );
      },
    );
  }
}

/// Simple list: My Courses → crops (Create New just above Lasun)
class _CourseHub extends StatefulWidget {
  const _CourseHub({
    required this.onOpenCourse,
    required this.onOpenEnrollment,
    required this.onCreateNew,
  });

  final Future<void> Function(CropItem crop) onOpenCourse;
  final Future<void> Function(CourseEnrollment e) onOpenEnrollment;
  final Future<void> Function() onCreateNew;

  @override
  State<_CourseHub> createState() => _CourseHubState();
}

class _CourseHubState extends State<_CourseHub> {
  final _search = TextEditingController();
  String _q = '';
  String? _pickedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final hi = s.isHi;
    final my = cropCourseService.myCourses;
    final enrolledIds = my.map((e) => e.cropId).toSet();
    final others = catalogService.indiaCourseCrops().where((c) {
      if (enrolledIds.contains(c.id)) return false;
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return c.nameEn.toLowerCase().contains(q) ||
          c.nameHi.contains(_q) ||
          c.id.contains(q);
    }).toList();

    final header = FrontBar(
          subtitle: screenPack.t(hi, 'course', 'subtitle', s.pickCourseCropSub),
        );
    final prompts = ServerPromptStrip(
          screen: 'course',
          hi: hi,
          onTap: (text, cropId) {
            screenActions.sendChat?.call(text, cropId: cropId);
          },
        );
    final search = Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: screenPack.t(hi, 'course', 'search', s.searchCrops),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
            ),
          ),
        );
    final list = Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              if (my.isNotEmpty) ...[
                Text(
                  screenPack.t(hi, 'course', 'myTitle', s.myCoursesTitle),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: context.agroText,
                  ),
                ),
                const SizedBox(height: 8),
                ...my.map((e) => _courseTile(
                      context: context,
                      s: s,
                      cropId: e.cropId,
                      emoji: e.emoji,
                      title: e.name(s.isHi),
                      subtitle: e.isClosed
                          ? e.dateRangeLabel(s.isHi)
                          : '${e.startOnlyLabel(s.isHi)} · ${s.courseDayProgress(e.dayNumber)}',
                      badge: e.isClosed ? s.courseClosedBadge : s.courseRunning,
                      trailing: Icons.chat_bubble_outline_rounded,
                      onTap: () => widget.onOpenEnrollment(e),
                    )),
                const SizedBox(height: 12),
              ],
              Text(
                s.isHi ? 'फसल का नाम चुनें' : 'Pick a crop name',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: context.agroText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.isHi
                    ? 'नाम पर टैप करें, फिर कोर्स बनाएँ'
                    : 'Tap a name, then create the course',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.agroMuted,
                ),
              ),
              const SizedBox(height: 10),
              for (final c in others) _nameLine(context, s, c),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => widget.onCreateNew(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  s.isHi ? 'सूची में नहीं? नाम लिखें' : 'Not listed? Type a name',
                ),
              ),
            ],
          ),
        );
    final create = _pickedId == null
        ? const SizedBox.shrink()
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _createPicked(others),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    s.createNewCourseCta,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          );
    return ServerBody(
      screen: 'course',
      fallback: const ['header', 'prompts', 'search', 'list', 'create'],
      slots: {
        'header': header,
        'prompts': prompts,
        'search': search,
        'list': list,
        'create': create,
      },
    );
  }

  Widget _framed({
    required String cropId,
    required String badge,
    required Widget child,
  }) {
    final premium = PremiumCropStyle.of(cropId);
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: premium != null ? 8 : 0),
      child: PremiumCropFrame(
        cropId: cropId,
        badgeLabel: badge,
        child: child,
      ),
    );
  }

  Widget _nameLine(BuildContext context, S s, CropItem crop) {
    final premium = PremiumCropStyle.of(crop.id);
    final selected = _pickedId == crop.id;
    final fg = selected
        ? (context.isDark ? AgroColors.night : Colors.white)
        : (premium?.accent ?? context.agroText);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? (premium?.badge ??
                (context.isDark ? AgroColors.mint : AgroColors.deepGreen))
            : (premium?.fill(context) ?? context.agroCard),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _pickedId = selected ? null : crop.id);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? (premium?.border ?? AgroColors.gold)
                    : (premium?.border ?? context.agroBorder),
                width: premium != null || selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                CropGlyph.item(crop, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    crop.name(s.isHi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 18,
                  color: selected ? fg : (premium?.badge ?? context.agroMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPicked(List<CropItem> others) async {
    final id = _pickedId;
    if (id == null) return;
    CropItem? crop;
    for (final c in others) {
      if (c.id == id) {
        crop = c;
        break;
      }
    }
    if (crop == null || !mounted) return;
    await widget.onOpenCourse(crop);
    if (mounted) setState(() => _pickedId = null);
  }

  Widget _courseTile({
    required BuildContext context,
    required S s,
    required String cropId,
    required String emoji,
    required String title,
    required String subtitle,
    required String badge,
    required IconData trailing,
    required VoidCallback onTap,
  }) {
    final premium = PremiumCropStyle.of(cropId);
    return _framed(
      cropId: cropId,
      badge: s.premiumBadge,
      child: SoftCard(
        onTap: onTap,
        color: premium?.fill(context),
        premiumBorder: premium != null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            CropGlyph(cropId: cropId, emoji: emoji, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: premium?.accent ?? context.agroText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: premium?.badge ??
                              (context.isDark
                                  ? AgroColors.mint
                                  : AgroColors.deepGreen),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: context.agroMuted),
                  ),
                ],
              ),
            ),
            Icon(trailing, color: premium?.badge ?? context.agroMuted),
          ],
        ),
      ),
    );
  }
}

class _PendingMedia {
  _PendingMedia({
    required this.path,
    required this.type,
    required this.name,
    required this.bytes,
    this.base64,
    this.lat,
    this.lon,
  });
  final String path;
  final ChatMediaType type;
  final String name;
  final int bytes;
  final String? base64;
  final double? lat;
  final double? lon;
}

class _CourseChatView extends StatefulWidget {
  const _CourseChatView({
    required this.onBack,
    required this.onAddCrop,
  });
  final VoidCallback onBack;
  final VoidCallback onAddCrop;

  @override
  State<_CourseChatView> createState() => _CourseChatViewState();
}

class _CourseChatViewState extends State<_CourseChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;
  _PendingMedia? _pending;
  String _selectedProvider = AiProviderPrefs.defaultProvider;
  bool _guestLocked = false;
  String? _bottomNotice;
  bool _deepResearch = false;
  final Set<String> _reportedIds = {};

  String? _visitKey;

  void _rememberVisit(String? cropId) {
    if (cropId == null || cropId.isEmpty) return;
    final key = CourseSummaryNotify.instance.visitKey(cropId);
    if (_visitKey == key) return;
    _visitKey = key;
    CourseSummaryNotify.instance.noteOpened(cropId);
  }

  bool _stickBottom = true;
  bool _showDown = false;
  bool _scrollQueued = false;
  double _lastPixels = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposeChanged);
    _scroll.addListener(_onCourseScroll);
    _loadProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rememberVisit(cropCourseService.activeCropId);
    });
  }

  void _onComposeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _reportCourseMessage(ChatMessage message) async {
    if (_reportedIds.contains(message.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final s = AgroScope.of(context).s;
    final ok = await showAiContentReportSheet(
      context,
      messageId: message.id,
      messageText: message.text,
      source: 'course',
    );
    if (!ok || !mounted) return;
    setState(() => _reportedIds.add(message.id));
    messenger.showSnackBar(SnackBar(content: Text(s.reportSuccess)));
  }

  Widget _courseAiMenu(ChatMessage message) {
    final s = AgroScope.of(context).s;
    final reported = _reportedIds.contains(message.id);
    final canShare = !message.isStreaming && !message.id.startsWith('welcome_');
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canShare)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: InkWell(
                onTap: () => _shareTurn(message),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AgroColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AgroColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        size: 14,
                        color: context.isDark
                            ? AgroColors.softGold
                            : AgroColors.deepGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.isHi ? 'शेयर' : 'Share',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.isDark
                              ? AgroColors.softGold
                              : AgroColors.deepGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
        tooltip: s.isHi ? 'और विकल्प' : 'More',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.menu_rounded,
          size: 20,
          color: context.agroTextMuted,
        ),
        onSelected: (value) {
          if (value == 'copy') {
            Clipboard.setData(ClipboardData(text: message.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.copySuccess),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (value == 'up' || value == 'down') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.feedbackThanks),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (value == 'report' && !reported) {
            _reportCourseMessage(message);
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'copy',
            child: Text(s.isHi ? 'कॉपी करें' : 'Copy'),
          ),
          PopupMenuItem(
            value: 'up',
            child: Text(s.helpfulFeedback),
          ),
          PopupMenuItem(
            value: 'down',
            child: Text(s.unhelpfulFeedback),
          ),
          PopupMenuItem(
            value: 'report',
            enabled: !reported,
            child: Text(
              reported
                  ? (s.isHi ? 'रिपोर्ट हुआ' : 'Reported')
                  : s.reportAiButton,
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareTurn(ChatMessage output) async {
    final s = AgroScope.of(context).s;
    final nav = Navigator.of(context, rootNavigator: true);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    nav.push(dialog);
    try {
      final cropId = cropCourseService.activeCropId;
      final all = cropId == null
          ? const <ChatMessage>[]
          : cropCourseService.messagesFor(cropId);
      final turn = turnForPdf(all, output);
      await shareChatPdf(
        title: turnPdfTitle(turn, hi: s.isHi),
        messages: turn,
        hi: s.isHi,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isHi
                ? 'PDF अभी शेयर नहीं हुई। एक बार फिर कोशिश करें।'
                : 'The PDF could not be shared. Try once more.',
          ),
        ),
      );
    } finally {
      if (dialog.isActive) nav.removeRoute(dialog);
    }
  }

  Future<void> _loadProvider() async {
    final p = await AiProviderPrefs.load();
    if (!mounted) return;
    setState(() => _selectedProvider = p);
  }

  Future<void> _setProvider(String provider) async {
    setState(() => _selectedProvider = provider);
    await AiProviderPrefs.save(provider);
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposeChanged);
    _scroll.removeListener(_onCourseScroll);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onCourseScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final away = pos.maxScrollExtent - pos.pixels > 80;
    if (!away) {
      _lastPixels = pos.pixels;
      if (_showDown || !_stickBottom) {
        setState(() {
          _showDown = false;
          _stickBottom = true;
        });
      }
      return;
    }
    if (_showDown) return;
    if (pos.pixels + 8 >= _lastPixels) {
      _lastPixels = pos.pixels;
      return;
    }
    _lastPixels = pos.pixels;
    setState(() {
      _showDown = true;
      _stickBottom = false;
    });
  }

  void _scrollEnd({bool force = false}) {
    if (force) {
      _stickBottom = true;
      _showDown = false;
      _scrollQueued = false;
    }
    if (!_stickBottom || _scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (!mounted || !_stickBottom || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final target = pos.maxScrollExtent;
      if (pos.pixels < target - 1) {
        _scroll.jumpTo(target);
        _scrollEnd();
      }
    });
  }

  void _jumpToLatest() {
    setState(() {
      _stickBottom = true;
      _showDown = false;
    });
    _scrollEnd();
  }

  Widget _latestArrow() {
    return Material(
      color: context.agroCard,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _jumpToLatest,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.agroText,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _showAttachSheet() async {
    final s = AgroScope.of(context).s;
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.agroCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.photoModalTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(s.cameraButton),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCameraPhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(s.galleryButton),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGalleryPhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLiveAssistant() async {
    HapticFeedback.lightImpact();
    final ok = await ensureLiveVoiceAccess(context);
    if (!ok || !mounted) return;
    final s = AgroScope.of(context).s;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceLiveScreen(
          isHi: s.isHi,
          initialLines: cropCourseService.activeMessages
              .where((m) => m.text.trim().isNotEmpty)
              .map(
                (m) => (
                  role: m.role == MessageRole.user ? 'user' : 'assistant',
                  text: m.text,
                ),
              )
              .toList(),
          onAsk: (text) async {
            try {
              final asked = await cropCourseService.ask(
                text,
                isHi: s.isHi,
                provider: 'openai',
                voice: true,
              );
              if (asked.blocked) {
                if (mounted) _handleBlocked(asked.reason);
                return null;
              }
              final reply = asked.message.text.trim();
              return reply.isEmpty ? null : reply;
            } catch (e) {
              debugPrint('course live ask failed: $e');
              return null;
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    if (result is Map && '${result['mode']}' == 'text') {
      final text = '${result['text'] ?? ''}'.trim();
      if (text.isNotEmpty) {
        final cur = _controller.text.trim();
        _controller.text = cur.isEmpty ? text : '$cur $text';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        setState(() {});
      }
      return;
    }
    if (result is List) {
      const hide = {
        'सोच रहा हूँ...',
        'Thinking...',
        'जवाब नहीं आ पाया। फिर बोलें।',
        'No answer came through. Speak again.',
        'राम-राम किसान भाई, बताओ क्या सहायता चाहिए। यहाँ मुझे बोलकर बताएं।',
        'Ram-ram. Tell me what help you need. Say it here.',
      };
      for (final raw in result) {
        if (raw is! Map) continue;
        final role = '${raw['role'] ?? ''}';
        final text = '${raw['text'] ?? ''}'.trim();
        if (text.isEmpty || hide.contains(text)) continue;
        if (cropCourseService.activeMessages.any((m) => m.text.trim() == text)) {
          continue;
        }
        await cropCourseService.appendLiveLine(
          role: role,
          text: text,
          isHi: s.isHi,
        );
      }
      if (mounted) setState(() {});
    }
    if (result == 'upgrade') {
      await showPlanUnlockSheet(context, forLiveVoice: true);
      return;
    }
    if (result == 'limit' || result == 'credit') {
      await openCreditTokenScreen(context);
    }
  }

  Future<void> _openVideoCall() async {
    HapticFeedback.lightImpact();
    final ok = await ensureVideoCallAccess(context);
    if (!ok || !mounted) return;
    final s = AgroScope.of(context).s;
    final all = cropCourseService.messagesFor(
      cropCourseService.activeCropId ?? '',
    );
    final tail = all.length <= 5 ? all : all.sublist(all.length - 5);
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          cropId: cropCourseService.activeCropId,
          mode: 'course',
          isHi: s.isHi,
          recent: [
            for (final m in tail)
              if (m.text.trim().isNotEmpty)
                {
                  'role': m.role == MessageRole.user ? 'user' : 'assistant',
                  'text': m.text.trim().length > 40
                      ? m.text.trim().substring(0, 40)
                      : m.text.trim(),
                },
          ],
          onLine: (role, text) {
            cropCourseService.appendLiveLine(
              role: role,
              text: text,
              isHi: s.isHi,
            );
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'upgrade') {
      await showPlanUnlockSheet(context, forVideo: true);
      return;
    }
    if (result == 'credit') {
      await openCreditTokenScreen(context);
    }
  }

  Future<void> _pickCameraPhoto() async {
    await _pickLeaf(ImageSource.camera);
  }

  Future<void> _pickGalleryPhoto() async {
    await _pickLeaf(ImageSource.gallery);
  }

  Future<void> _pickLeaf(ImageSource source) async {
    final s = AgroScope.of(context).s;
    try {
      final photo = await LeafPhotoPicker.pick(source);
      if (photo == null || !mounted) return;
      setState(() {
        _pending = _PendingMedia(
          path: photo.path,
          type: ChatMediaType.image,
          name: photo.name,
          bytes: photo.bytes,
          base64: photo.base64,
          lat: photo.lat,
          lon: photo.lon,
        );
      });
    } catch (e) {
      if (!mounted) return;
      final tooBig = e.toString().contains('file_too_large');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tooBig ? s.fileTooLarge : s.errGeneric,
          ),
        ),
      );
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return;
    await profileService.syncSession();
    if (!mounted) return;
    setState(() {
      if (ApiClient.instance.hasSession) {
        _guestLocked = false;
        _bottomNotice = null;
      }
    });
  }

  Future<void> _openUpgrade() async {
    final before = profileService.plan.rank;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(profileService: profileService),
      ),
    );
    if (!mounted) return;
    await profileService.syncSession();
    if (!mounted) return;
    setState(() {
      if (profileService.plan.rank > before) _bottomNotice = null;
    });
  }

  void _handleBlocked(String? reason) {
    if (!mounted) return;
    if (reason == 'login' || !ApiClient.instance.hasSession) {
      setState(() {
        _guestLocked = true;
        _bottomNotice = 'login';
      });
      return;
    }
    if (reason == 'chat' ||
        reason == 'daily' ||
        reason == 'month' ||
        reason == 'plan' ||
        reason == 'plan_required' ||
        reason == 'image') {
      if (profileService.plan == PlanTier.distributor) {
        if (reason == 'image') {
          final hi = AgroScope.of(context).s.isHi;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hi
                    ? 'आज की फोटो जाँच पूरी हो गई। कल फिर जाँच कर सकते हो।'
                    : 'Today’s photo checks are used up. You can check again tomorrow.',
              ),
            ),
          );
        }
        return;
      }
      setState(() => _bottomNotice = 'upgrade');
    }
  }

  Future<void> _send([String? preset, String? provider]) async {
    final s = AgroScope.of(context).s;
    final text = (preset ?? _controller.text).trim();
    if ((text.isEmpty && _pending == null) || _typing) return;
    if (!ApiClient.instance.hasSession && _guestLocked) {
      setState(() => _bottomNotice = 'login');
      return;
    }

    final cropId = cropCourseService.activeCropId;
    final closeHints = {
      'कोर्स बंद करें',
      'Close course',
      'close course',
    };
    final continueHints = {
      'जारी रखें',
      'Continue',
      'continue',
    };
    if (cropId != null && closeHints.contains(text)) {
      final stopOk = await _askStopToClose(s);
      if (!stopOk || !mounted) return;
      await cropCourseService.closeCourse(cropId, isHi: s.isHi);
      if (!mounted) return;
      _scrollEnd(force: true);
      return;
    }
    if (cropId != null && continueHints.contains(text)) {
      await cropCourseService.continueCourse(cropId, isHi: s.isHi);
      if (!mounted) return;
      _scrollEnd(force: true);
      return;
    }

    setState(() => _typing = true);
    _controller.clear();
    final pending = _pending;
    final useDeep =
        _deepResearch && chatLimitsService.deepFor(profileService.plan) > 0;
    setState(() {
      _pending = null;
      if (useDeep) _deepResearch = false;
    });
    try {
      final result = await cropCourseService.ask(
        text,
        isHi: s.isHi,
        provider: provider ?? _selectedProvider,
        mediaPath: pending?.path,
        mediaType: pending?.type ?? ChatMediaType.none,
        mediaName: pending?.name,
        mediaBytes: pending?.bytes,
        imageBase64: pending?.base64,
        lat: pending?.lat,
        lon: pending?.lon,
        deepResearch: useDeep,
      );
      if (result.blocked) _handleBlocked(result.reason);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('file_too_large')
          ? s.fileTooLarge
          : e.toString().contains('course_closed')
              ? (s.isHi
                  ? 'यह कोर्स बंद है — नया मैसेज नहीं भेज सकते'
                  : 'This course is closed — cannot send new messages')
              : s.errGeneric;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    if (!mounted) return;
    setState(() => _typing = false);
    _scrollEnd(force: true);
  }

  void _openModelPicker() {
    final s = AgroScope.of(context).s;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.agroCard,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final locked = chatLimitsService.deepFor(profileService.plan) <= 0 ||
                !featureControls.on('deep');
            final deepOn = _deepResearch && !locked;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('AG High'),
                    selected: _selectedProvider == 'gemini',
                    onTap: () {
                      _setProvider('gemini');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    title: const Text('AG Expert'),
                    selected: _selectedProvider == 'openai',
                    onTap: () {
                      _setProvider('openai');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.travel_explore_rounded),
                    title: Text(s.isHi ? 'डीप रिसर्च' : 'Deep research'),
                    trailing: Icon(
                      deepOn
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: deepOn ? const Color(0xFF7C3AED) : null,
                    ),
                    onTap: () {
                      if (locked) {
                        Navigator.pop(ctx);
                        showPlanUnlockSheet(
                          context,
                          requiredPlan: PlanTier.advanced,
                        );
                        return;
                      }
                      setState(() => _deepResearch = !_deepResearch);
                      setSheet(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _bubbleCap(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.62).clamp(200.0, 270.0);
  }

  Widget _userBubble(ChatMessage m) {
    return Align(
      alignment: Alignment.centerRight,
      child: Builder(
        builder: (bubbleContext) => GestureDetector(
          onLongPress: () => showMessageCopyMenu(
            bubbleContext,
            text: m.text,
            hindi: AgroScope.of(bubbleContext).s.isHi,
            copiedLabel: AgroScope.of(bubbleContext).s.copySuccess,
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            constraints: BoxConstraints(maxWidth: _bubbleCap(context)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: Face.of(context).sheen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(
                color: AgroColors.champagne.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (m.hasMedia) ...[
                  _MediaBubble(message: m, onAccent: true),
                  const SizedBox(height: 8),
                ],
                Text(
                  m.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _clock(m.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botBubble(ChatMessage m, S s) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 26, radius: 8, framed: true),
              const SizedBox(width: 8),
              Text(
                'AG Farmer',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: context.agroText,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgroColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.aiLabel.isNotEmpty
                      ? m.aiLabel
                      : (s.isHi ? 'देसी AI वैज्ञानिक' : 'AI Scientist'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.isDark
                        ? AgroColors.softGold
                        : AgroColors.deepGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _clock(m.createdAt),
                style: TextStyle(fontSize: 10.5, color: context.agroTextMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (bubbleContext) => GestureDetector(
              onLongPress: () => showMessageCopyMenu(
                bubbleContext,
                text: m.text,
                hindi: s.isHi,
                copiedLabel: s.copySuccess,
              ),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: -14, right: -14),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: context.agroCard,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.hasMedia) ...[
                      _MediaBubble(message: m, onAccent: false),
                      const SizedBox(height: 8),
                    ],
                    m.isStreaming
                        ? AnswerPipe(
                            key: ValueKey('pipe-${m.id}'),
                            text: m.text,
                            style: TextStyle(
                              color: context.agroText,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: AgroColors.deepGreen,
                            onDone: () => cropCourseService.finishStream(m.id),
                          )
                        : ChatAnswerBody(text: m.text),
                    if (m.text.trim().isNotEmpty) _courseAiMenu(m),
                    if (m.quickReplies.any(_courseActionChip)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: m.quickReplies
                            .where(_courseActionChip)
                            .map(
                              (q) => ActionChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                label: Text(
                                  q,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                onPressed: () => _send(q),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<bool> _askStopToClose(S s) async {
    final typed = TextEditingController();
    var typeOk = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final ready = typed.text.trim().toLowerCase() == 'stop';
            return AlertDialog(
              backgroundColor: ctx.agroCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                s.closeTypeTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: ctx.agroText,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.closeTypeBody,
                    style: TextStyle(
                      color: ctx.agroMuted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typed,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: 'Stop'),
                    onChanged: (v) {
                      final next = v.trim().toLowerCase() == 'stop';
                      if (next != typeOk) setLocal(() => typeOk = next);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isHi ? 'रद्द करें' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: ready ? () => Navigator.pop(ctx, true) : null,
                  child: Text(s.isHi ? 'कन्फर्म' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    typed.dispose();
    return ok == true;
  }

  bool _courseActionChip(String q) {
    final t = q.toLowerCase();
    return t.contains('बंद') ||
        t.contains('जारी') ||
        t.contains('close') ||
        t.contains('continue');
  }

  void _openCourseMenu(S s, {required String? cropId, required bool courseClosed}) {
    final face = Face.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: face.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: face.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (cropId != null && !courseClosed)
                ListTile(
                  leading: Icon(Icons.lock_outline_rounded, color: face.ink),
                  title: Text(s.closeThisCourse),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final stopOk = await _askStopToClose(s);
                    if (stopOk && mounted) {
                      await cropCourseService.closeCourse(cropId, isHi: s.isHi);
                    }
                  },
                ),
              const ThemeMenuPick(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return ListenableBuilder(
      listenable: cropCourseService,
      builder: (context, _) {
        final openIds = cropCourseService.openCropIds.isNotEmpty
            ? cropCourseService.openCropIds
            : cropCourseService.myCourses.map((e) => e.cropId).toList();
        var activeId = cropCourseService.activeCropId;
        if ((activeId == null || !openIds.contains(activeId)) &&
            openIds.isNotEmpty) {
          activeId = openIds.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            cropCourseService.switchToCrop(openIds.first);
          });
        }
        final messages = activeId == null
            ? const <ChatMessage>[]
            : cropCourseService.messagesFor(activeId);
        final enroll =
            activeId == null ? null : cropCourseService.enrollmentFor(activeId);
        final courseClosed = enroll?.isClosed == true;
        if (activeId != null) {
          final visit = CourseSummaryNotify.instance.visitKey(activeId);
          if (_visitKey != visit) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _rememberVisit(activeId);
            });
          }
        }
        final iconColor =
            context.isDark ? AgroColors.nightGold : AgroColors.deepGreen;

        final cropName = enroll?.name(s.isHi) ?? s.fasalCourse;
        final face = Face.of(context);
        final header = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                face.panel.withValues(alpha: 0.92),
                face.panel.withValues(alpha: 0.72),
                face.panel.withValues(alpha: 0.38),
                face.panel.withValues(alpha: 0.12),
                face.panel.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.42, 0.68, 0.86, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: s.isHi ? 'वापस' : 'Back',
                        onPressed: widget.onBack,
                        icon: Icon(Icons.arrow_back_rounded, color: face.ink),
                      ),
                      const BrandLogo(size: 40, radius: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cropName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: face.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (activeId != null)
                        IconButton(
                          tooltip: s.courseCalendarTooltip,
                          onPressed: () {
                            final id = activeId!;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CourseCalendarScreen(cropId: id),
                              ),
                            );
                          },
                          icon: Icon(Icons.calendar_month_rounded, color: face.ink),
                        ),
                      IconButton(
                        tooltip: s.isHi ? 'मेनू' : 'Menu',
                        onPressed: () => _openCourseMenu(
                          s,
                          cropId: activeId,
                          courseClosed: courseClosed,
                        ),
                        icon: Icon(Icons.menu_rounded, color: face.ink, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
              const IgnorePointer(child: SizedBox(height: 36)),
            ],
          ),
        );
        final thread = Expanded(
              child: Stack(
                children: [
              Builder(
                builder: (context) {
                  final rows = _courseChatRows(messages);
                  return SwipeMessageTime(
                    builder: (context, reveal) => ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  14,
                  MediaQuery.paddingOf(context).top + 58,
                  14,
                  16,
                ),
                itemCount: rows.length + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  Widget slot(Widget child, {String? time}) => MessageTimeSlot(
                        reveal: reveal,
                        time: time,
                        child: child,
                      );
                  if (_typing && i == rows.length) {
                    return slot(
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 8),
                          child: _CourseTypingCard(),
                        ),
                      ),
                    );
                  }
                  final row = rows[i];
                  if (row.endedOn != null) {
                    return slot(
                      _DateEndLine(
                        day: row.endedOn!,
                        hi: s.isHi,
                        summary: row.summary,
                      ),
                    );
                  }
                  final m = row.message!;
                  final sent = messageSentTime(m.createdAt, hi: s.isHi);
                  return slot(
                    m.role == MessageRole.user ? _userBubble(m) : _botBubble(m, s),
                    time: sent,
                  );
                },
              ),
                  );
                },
              ),
              if (_showDown)
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: _latestArrow(),
                ),
                ],
              ),
            );
        final dock = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (courseClosed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: SoftCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    s.courseClosedInputHint,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.agroMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            if (_pending != null && !courseClosed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: SoftCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.image_rounded, color: context.agroGold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_pending!.name} (${_mb(_pending!.bytes)} MB)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _pending = null),
                        child: Text(s.removeAttachment),
                      ),
                    ],
                  ),
                ),
              ),
            // Same input as normal chat
            if (!courseClosed)
              Material(
              color: context.agroNavBg,
              child: Container(
              decoration: BoxDecoration(
                color: context.agroNavBg,
                border: Border(
                  top: BorderSide(color: context.agroBorder.withValues(alpha: 0.7)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_bottomNotice != null)
                        ChatLimitNotice(
                          login: _bottomNotice == 'login',
                          isHi: s.isHi,
                              onPressed: _bottomNotice == 'login'
                                  ? _openLogin
                                  : _openUpgrade,
                        ),
                      Builder(
                        builder: (context) {
                          final canSend =
                              _controller.text.trim().isNotEmpty ||
                                  _pending != null;
                          final showVoiceBtn = screenPack.on(
                                'courseChat',
                                'showVoice',
                                true,
                              ) &&
                              featureControls.on('voiceCall');
                          final showVideo = screenPack.on(
                                'courseChat',
                                'showVideo',
                                true,
                              ) &&
                              featureControls.on('videoCall');
                          final modelColor = _deepResearch
                              ? const Color(0xFF7C3AED)
                              : iconColor;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 3,
                                  maxLines: 6,
                                  enabled: !_typing,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    color: context.agroText,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: screenPack.t(
                                      s.isHi,
                                      'courseChat',
                                      'hint',
                                      s.chatHint,
                                    ),
                                    hintStyle: TextStyle(
                                      fontSize: 13.5,
                                      color: context.agroTextMuted,
                                    ),
                                    fillColor: context.agroCard,
                                    filled: true,
                                    isDense: true,
                                    constraints: const BoxConstraints(
                                      minHeight: 98,
                                    ),
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      8,
                                      16,
                                      12,
                                      16,
                                    ),
                                    prefixIcon: _InMix(
                                      parts: [
                                        _MixHalf(
                                          icon: Icons.photo_camera_rounded,
                                          tip: s.isHi ? 'कैमरा' : 'Camera',
                                          color: iconColor,
                                          onTap: _typing
                                              ? null
                                              : _showAttachSheet,
                                        ),
                                        _MixHalf(
                                          icon: Icons.auto_awesome_rounded,
                                          tip: _deepResearch
                                              ? (s.isHi
                                                    ? 'प्रीमियम AI • डीप रिसर्च चालू'
                                                    : 'Premium AI • deep research on')
                                              : ChatMessage.providerDisplayName(
                                                  _selectedProvider,
                                                ),
                                          color: modelColor,
                                          onTap: _typing
                                              ? null
                                              : _openModelPicker,
                                        ),
                                      ],
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0,
                                      minHeight: 44,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: context.agroBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: context.agroBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(22),
                                      borderSide: BorderSide(
                                        color: AgroColors.deepGreen.withValues(
                                          alpha: 0.7,
                                        ),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (canSend || showVideo || showVoiceBtn) ...[
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showVideo)
                                      _FeaturePill(
                                        label: screenPack.t(
                                          s.isHi,
                                          'courseChat',
                                          'video',
                                          s.isHi ? 'वीडियो कॉल' : 'Video call',
                                        ),
                                        icon: Icons.videocam_rounded,
                                        colors: const [
                                          Color(0xFFB45309),
                                          Color(0xFFE8B84A),
                                        ],
                                        onTap: _typing ? null : _openVideoCall,
                                        size: 44,
                                      ),
                                    if (canSend) ...[
                                      if (showVideo) const SizedBox(height: 6),
                                      _FeaturePill(
                                        label: s.isHi ? 'भेजें' : 'Send',
                                        icon: Icons.arrow_upward_rounded,
                                        colors: const [
                                          AgroColors.deepGreen,
                                          AgroColors.leaf,
                                        ],
                                        onTap: _typing ? null : () => _send(),
                                        size: 44,
                                      ),
                                    ] else if (showVoiceBtn) ...[
                                      if (showVideo) const SizedBox(height: 6),
                                      _FeaturePill(
                                        label: screenPack.t(
                                          s.isHi,
                                          'courseChat',
                                          'live',
                                          'AG Live',
                                        ),
                                        icon: Icons.mic_rounded,
                                        colors: const [
                                          Color(0xFF0369A1),
                                          Color(0xFF0EA5E9),
                                        ],
                                        onTap: _typing
                                            ? null
                                            : _openLiveAssistant,
                                        size: 44,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      Text(
                        s.aiDisclaimerNotice,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.25,
                          color: context.agroMuted.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              ),
          ],
        );
        _scrollEnd();
        return FrontScope(
          child: Stack(
            children: [
              Column(
                children: [
                  thread,
                  dock,
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: header,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MixHalf {
  const _MixHalf({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final Color? color;
}

class _InMix extends StatelessWidget {
  const _InMix({required this.parts});

  final List<_MixHalf> parts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _RoundTool(part: parts[i]),
          ],
        ],
      ),
    );
  }
}

class _RoundTool extends StatelessWidget {
  const _RoundTool({required this.part});

  final _MixHalf part;

  @override
  Widget build(BuildContext context) {
    final tint = part.color ?? context.agroText;
    return Tooltip(
      message: part.tip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: part.onTap,
          customBorder: const CircleBorder(),
          splashColor: tint.withValues(alpha: 0.38),
          highlightColor: tint.withValues(alpha: 0.22),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.14),
            ),
            child: Icon(part.icon, size: 22, color: tint),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.size = 60,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

class _CourseRow {
  const _CourseRow.message(this.message)
      : endedOn = null,
        summary = '';
  const _CourseRow.ended(this.endedOn, {this.summary = ''}) : message = null;

  final ChatMessage? message;
  final DateTime? endedOn;
  final String summary;
}

DateTime _calendarDay(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _clock(DateTime t) {
  final local = t.toLocal();
  return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

List<_CourseRow> _courseChatRows(List<ChatMessage> messages) {
  final welcome = <ChatMessage>[];
  final rest = <ChatMessage>[];
  for (final m in messages) {
    if (m.id.startsWith('welcome_')) {
      welcome.add(m);
    } else {
      rest.add(m);
    }
  }
  rest.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final rows = <_CourseRow>[];
  for (final m in welcome) {
    rows.add(_CourseRow.message(m));
  }
  DateTime? day;
  for (final m in rest) {
    final d = _calendarDay(m.createdAt);
    if (day == null || d != day) {
      rows.add(_CourseRow.ended(d));
      day = d;
    }
    rows.add(_CourseRow.message(m));
  }
  return rows;
}

String _courseDateLine(DateTime day, bool hi) {
  const hiMonths = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
  ];
  const enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final month = hi ? hiMonths[day.month - 1] : enMonths[day.month - 1];
  return '${day.day} $month ${day.year}';
}

class _CourseTypingCard extends StatelessWidget {
  const _CourseTypingCard();

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.agroCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.agroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(size: 20, radius: 6, framed: false),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              s.isHi ? 'AG Farmer सोच रहा है...' : 'AG Farmer is thinking...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.agroTextMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const WorkMoment(label: '', barsOnly: true),
        ],
      ),
    );
  }
}

class _DateEndLine extends StatelessWidget {
  const _DateEndLine({
    required this.day,
    required this.hi,
    required this.summary,
  });

  final DateTime day;
  final bool hi;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final line = context.agroMuted.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
      child: Column(
        children: [
          if (summary.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                summary.trim(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: context.agroText,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(child: Divider(color: line, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _courseDateLine(day, hi),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.agroMuted,
                  ),
                ),
              ),
              Expanded(child: Divider(color: line, thickness: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaBubble extends StatelessWidget {
  const _MediaBubble({required this.message, required this.onAccent});
  final ChatMessage message;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final path = message.displayMediaPath;
    if (path == null) return const SizedBox.shrink();
    if (message.mediaType == ChatMediaType.image) {
      if (path.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            path,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: onAccent ? Colors.white70 : context.agroMuted,
            ),
          ),
        );
      }
      if (localFileExists(path)) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: localFileImage(
            path,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return Text(
      message.mediaName ?? 'file',
      style: TextStyle(
        color: onAccent ? Colors.white70 : context.agroMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

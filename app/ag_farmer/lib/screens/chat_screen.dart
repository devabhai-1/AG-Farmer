import '../platform/local_file.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import '../services/agro_ai_backend.dart';
import '../services/agro_scope.dart';
import '../services/ai_provider_prefs.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../services/chat_pdf.dart';
import '../services/chat_sync_service.dart';
import '../services/feature_controls.dart';
import '../services/leaf_photo.dart';
import '../services/screen_pack.dart';
import '../widgets/half_pull_refresh.dart';
import '../widgets/server_prompts.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_pipe.dart';
import '../widgets/brand_logo.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/swipe_message_time.dart';
import '../theme/front_style.dart';
import '../widgets/chat_answer_body.dart';
import '../widgets/message_copy_menu.dart';
import '../widgets/chat_limit_notice.dart';
import '../widgets/plan_unlock_sheet.dart';
import '../services/speech_speak_service.dart';
import 'auth/login_screen.dart';
import 'subscription_screen.dart';
import 'credit_token_screen.dart';
import 'video_call_screen.dart';
import 'voice_live_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _serverSessions = [];
  bool _typing = false;
  String? _seedLang;
  CropItem? _activeCrop;
  bool _isSpeaking = false;
  String? _currentlySpeakingId;
  final Map<String, bool> _feedbackRatings = {};
  final Set<String> _reportedMessageIds = {};
  bool _restoreStarted = false;
  bool _liveOpen = false;
  String _sessionId = 'main';
  String _chatName = 'General Chat';
  bool _deepResearch = false;
  bool _guestLocked = false;
  String? _bottomNotice;
  LeafPhoto? _pendingPhoto;
  String? _seenUid;

  static const List<_QuickCrop> _quickCrops = [
    _QuickCrop(id: 'all', nameHi: 'ऑल चैट', nameEn: 'All Chat', icon: '💬'),
    _QuickCrop(id: 'afim', nameHi: 'अफीम', nameEn: 'Opium', icon: '🌸'),
    _QuickCrop(id: 'lasun', nameHi: 'लहसुन', nameEn: 'Garlic', icon: '🧄'),
    _QuickCrop(id: 'gehun', nameHi: 'गेहूँ', nameEn: 'Wheat', icon: '🌾'),
    _QuickCrop(id: 'pyaj', nameHi: 'प्याज', nameEn: 'Onion', icon: '🧅'),
    _QuickCrop(id: 'tamatar', nameHi: 'टमाटर', nameEn: 'Tomato', icon: '🍅'),
    _QuickCrop(id: 'mirch', nameHi: 'मिर्च', nameEn: 'Chilli', icon: '🌶️'),
    _QuickCrop(id: 'aalu', nameHi: 'आलू', nameEn: 'Potato', icon: '🥔'),
    _QuickCrop(id: 'sarson', nameHi: 'सरसों', nameEn: 'Mustard', icon: '🌿'),
  ];
  String _selectedCropId = 'all';

  /// User-selected AI: gemini | openai — new users start on AG Expert (openai)
  String _selectedProvider = AiProviderPrefs.defaultProvider;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposeChanged);
    _scrollController.addListener(_onChatScroll);
    _loadProvider();
    chatLimitsService.addListener(_onComposeChanged);
    screenPack.addListener(_onScreens);
    featureControls.addListener(_onComposeChanged);
    speechSpeakService.bindHandlers(
      onDone: _onSpeakEnded,
      onCancel: _onSpeakEnded,
    );
    speechSpeakService.init();
    _seenUid = ApiClient.instance.hasSession ? ApiClient.instance.uid : null;
    authService.addListener(_onAccount);
    unawaited(screenPack.refresh());
  }

  void _onAccount() {
    final uid = ApiClient.instance.hasSession ? ApiClient.instance.uid : null;
    if (uid == _seenUid) return;
    _seenUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAccountChat();
    });
  }

  /// Drop the previous account's open chat. Do not upload it to the new login.
  void _showAccountChat() {
    final s = AgroScope.of(context).s;
    speechSpeakService.stop();
    _sessionId = 's_${DateTime.now().millisecondsSinceEpoch}';
    _chatName = s.isHi ? 'नई चैट' : 'New chat';
    _controller.clear();
    _pendingPhoto = null;
    _typing = false;
    _isSpeaking = false;
    _currentlySpeakingId = null;
    _feedbackRatings.clear();
    _reportedMessageIds.clear();
    _bottomNotice = null;
    _guestLocked = !ApiClient.instance.hasSession;
    _serverSessions.clear();
    _messages
      ..clear()
      ..add(
        ChatMessage(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          text: _packText(s, 'welcome', s.chatWelcome),
          role: MessageRole.assistant,
          createdAt: DateTime.now(),
          quickReplies: const [],
        ),
      );
    setState(() {});
    if (ApiClient.instance.hasSession) {
      _refreshSessions();
    }
  }

  void _onComposeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSpeakEnded() {
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _currentlySpeakingId = null;
    });
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

  bool _sessionHasChat(Map<String, dynamic> session) {
    final count = session['msgCount'];
    if (count is num) return count > 0;
    final name = '${session['name'] ?? ''}'.trim();
    return name.isNotEmpty &&
        name != 'नई चैट' &&
        name != 'New chat' &&
        name != 'General Chat';
  }

  Future<void> _restoreFromServer() async {
    await _refreshSessions();
  }

  Future<void> _pullRefresh() async {
    await screenPack.refresh();
    if (ApiClient.instance.hasSession) {
      await _refreshSessions();
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshSessions() async {
    final sessions = (await chatSyncService.listSessions(
      mode: 'chat',
    )).where(_sessionHasChat).toList();
    if (!mounted) return;
    setState(() {
      _serverSessions
        ..clear()
        ..addAll(sessions);
    });
  }

  String _nameFromMessages(List<ChatMessage> msgs, bool isHi) {
    final topic = _topicLine(msgs, isHi);
    if (topic.isNotEmpty) return topic;
    return isHi ? 'नई चैट' : 'New chat';
  }

  String _topicLine(List<ChatMessage> msgs, bool isHi) {
    final users = <String>[];
    var photo = false;
    for (final m in msgs) {
      if (m.id.startsWith('welcome_') || m.id.startsWith('summary_')) continue;
      if (m.hasMedia) photo = true;
      if (m.role != MessageRole.user) continue;
      final t = m.text.trim();
      if (t.isNotEmpty) users.add(t);
    }
    String? real;
    for (final t in users) {
      final stripped = _stripLeadGreeting(t);
      if (stripped.isNotEmpty && !_isWeakTitle(stripped)) {
        real = stripped;
        break;
      }
    }
    if (real == null) {
      if (photo) return isHi ? 'फसल की फोटो' : 'Crop photo';
      if (users.isNotEmpty) return isHi ? 'सामान्य बातचीत' : 'General talk';
      return '';
    }
    final asked = users.map(_stripLeadGreeting).where((t) => t.isNotEmpty).join('\n');
    final crop = _topicHit(real, _topicCrops) ?? _topicHit(asked, _topicCrops);
    final issue = _topicHit(real, _topicIssues) ?? _topicHit(asked, _topicIssues);
    if (crop != null && issue != null) return '$crop · $issue';
    if (crop != null) return crop;
    if (issue != null) return issue;
    final sentence = real
        .split(RegExp(r'[.?!।\n]'))
        .map((s) => s.trim())
        .firstWhere((s) => s.length > 1, orElse: () => real!);
    return _clipTopicWords(sentence, 7);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = AgroScope.of(context).lang?.code;
    if (_seedLang != lang) {
      _seedLang = lang;
      if (!_liveOpen) _resetChat(silent: true);
      if (!_restoreStarted) {
        _restoreStarted = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreFromServer(),
        );
      }
    }
  }

  String _packText(dynamic s, String key, String fallback) =>
      screenPack.t(s.isHi as bool, 'chat', key, fallback);

  void _onScreens() {
    if (!mounted) return;
    setState(() {
      try {
        final s = AgroScope.of(context).s;
        final next = _packText(s, 'welcome', s.chatWelcome);
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.id.startsWith('welcome_') && m.text != next) {
            _messages[i] = m.copyWith(text: next);
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    authService.removeListener(_onAccount);
    screenPack.removeListener(_onScreens);
    featureControls.removeListener(_onComposeChanged);
    speechSpeakService.stop();
    _controller.removeListener(_onComposeChanged);
    _scrollController.removeListener(_onChatScroll);
    chatLimitsService.removeListener(_onComposeChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetChat({bool silent = false}) {
    final s = AgroScope.of(context).s;
    // Archive current session messages to server under current session id
    if (_messages.length > 1 && ApiClient.instance.hasSession) {
      final name = _nameFromMessages(_messages, s.isHi);
      // ignore: unawaited_futures
      chatSyncService.sync(
        List<ChatMessage>.from(_messages),
        sessionId: _sessionId,
        chatName: name,
      );
    }
    final newId = 's_${DateTime.now().millisecondsSinceEpoch}';
    _sessionId = newId;
    _chatName = s.isHi ? 'नई चैट' : 'New chat';
    _messages
      ..clear()
      ..add(
        ChatMessage(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          text: _packText(s, 'welcome', s.chatWelcome),
          role: MessageRole.assistant,
          createdAt: DateTime.now(),
          cropTag: _selectedCropId == 'all' ? null : _selectedCropName(s.isHi),
          quickReplies: const [],
        ),
      );
    if (!silent && mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.chatReset),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // ignore: unawaited_futures
      _refreshSessions();
    }
  }

  String _selectedCropName(bool isHi) {
    final found = _quickCrops.firstWhere(
      (c) => c.id == _selectedCropId,
      orElse: () => _quickCrops.first,
    );
    return isHi ? found.nameHi : found.nameEn;
  }

  void sendQueryFromExternal(String query, {String? cropId}) {
    if (cropId != null && cropId.isNotEmpty) {
      _selectedCropId = cropId;
    }
    _send(query);
  }

  Future<void> _openLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
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

  Future<String?> _send([
    String? preset,
    String? attachedImage,
    String? provider,
    bool voice = false,
  ]) async {
    final s = AgroScope.of(context).s;
    final text = (preset ?? _controller.text).trim();
    final photo = preset == null ? _pendingPhoto : null;
    final LeafPhoto? shot = (photo != null && photo.base64.length > 40)
        ? photo
        : null;
    if (text.isEmpty && attachedImage == null && shot == null) return null;
    if (_typing) {
      if (!voice) return null;
      final started = DateTime.now();
      while (_typing && mounted && DateTime.now().difference(started).inSeconds < 45) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (_typing) return null;
    }
    if (!ApiClient.instance.hasSession && _guestLocked) {
      setState(() => _bottomNotice = 'login');
      return null;
    }

    final userQuery = text.isEmpty
        ? (s.isHi ? '🌱 इस पत्ती की फोटो जाँचें' : '🌱 Check this leaf photo')
        : text;
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: userQuery,
          role: MessageRole.user,
          createdAt: DateTime.now(),
          imagePath: shot?.path ?? attachedImage,
          mediaPath: shot?.path,
          mediaType: shot != null ? ChatMediaType.image : ChatMediaType.none,
          mediaName: shot?.name,
          cropTag: _selectedCropId == 'all' ? null : _selectedCropName(s.isHi),
        ),
      );
      _controller.clear();
      _pendingPhoto = null;
      _typing = true;
    });
    _scrollToEnd(force: true);

    // Backend AI (keys on server only). History = prior turns only.
    final historyForAi = _messages.length > 1
        ? _messages.sublist(0, _messages.length - 1)
        : <ChatMessage>[];
    final useDeep =
        !voice && _deepResearch && profileService.plan.deepResearchLimit > 0;
    final aiResult = await AgroAiBackend.ask(
      userQuery,
      activeCropId: _selectedCropId == 'all'
          ? _activeCrop?.id
          : _selectedCropId,
      isHi: s.isHi,
      mode: 'chat',
      provider: voice ? 'openai' : (provider ?? _selectedProvider),
      voice: voice,
      planId: profileService.planId,
      hasImage: shot != null,
      imageBase64: shot?.base64,
      lat: shot?.lat,
      lon: shot?.lon,
      history: historyForAi,
      sessionId: _sessionId,
      chatName: _chatName,
      deepResearch: useDeep,
    );
    if (!mounted) return null;

    setState(() {
      final savedImage = aiResult.imageUrl;
      if (savedImage != null && savedImage.isNotEmpty) {
        final photoIndex = _messages.lastIndexWhere(
          (m) => m.role == MessageRole.user,
        );
        if (photoIndex >= 0) {
          _messages[photoIndex] = _messages[photoIndex].copyWith(
            imagePath: savedImage,
            mediaPath: savedImage,
            mediaType: ChatMediaType.image,
          );
        }
      }
      if (!aiResult.blocked) {
        _messages.add(
          ChatMessage(
            id: '${DateTime.now().microsecondsSinceEpoch}_ai',
            text: aiResult.text,
            role: MessageRole.assistant,
            createdAt: DateTime.now(),
            dosageHighlight: aiResult.dosageHighlight,
            quickReplies: aiResult.quickReplies,
            cropTag: _selectedCropId == 'all'
                ? null
                : _selectedCropName(s.isHi),
            aiProvider: aiResult.provider ?? _selectedProvider,
            aiModel: aiResult.model,
            isDeepResearch: useDeep,
            isStreaming: aiResult.text.trim().isNotEmpty,
          ),
        );
      }
      _typing = false;
      if (useDeep) _deepResearch = false;
      if (_chatName == 'General Chat' ||
          _chatName == 'New chat' ||
          _chatName == 'नई चैट') {
        _chatName = _nameFromMessages(_messages, s.isHi);
      }
    });
    _scrollToEnd(force: true);
    if (aiResult.blocked) {
      _handleBlocked(aiResult.blockReason);
    }
    // Persist to email/uid RTDB under this named session
    // ignore: unawaited_futures
    chatSyncService.sync(
      List<ChatMessage>.from(_messages),
      sessionId: _sessionId,
      chatName: _chatName,
    );
    if (aiResult.blocked) return null;
    return aiResult.text;
  }

  void _finishPipe(String id) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index < 0 || !_messages[index].isStreaming) return;
    setState(() {
      _messages[index] = _messages[index].copyWith(isStreaming: false);
    });
  }

  bool _stickBottom = true;
  bool _showDown = false;
  bool _scrollQueued = false;
  double _lastPixels = 0;

  void _onChatScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
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

  void _scrollToEnd({bool force = false}) {
    if (force) {
      _stickBottom = true;
      _showDown = false;
      _scrollQueued = false;
    }
    if (!_stickBottom || _scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (!mounted || !_stickBottom || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final target = pos.maxScrollExtent;
      if (pos.pixels < target - 1) {
        _scrollController.jumpTo(target);
        _scrollToEnd();
      }
    });
  }

  void _jumpToLatest() {
    setState(() {
      _stickBottom = true;
      _showDown = false;
    });
    _scrollToEnd();
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

  void _copyToClipboard(String text) {
    final s = AgroScope.of(context).s;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.copySuccess),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleSpeak(ChatMessage message) async {
    HapticFeedback.lightImpact();
    final s = AgroScope.of(context).s;

    // Tap again on same message → stop
    if (_isSpeaking && _currentlySpeakingId == message.id) {
      await speechSpeakService.stop();
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _currentlySpeakingId = null;
      });
      return;
    }

    setState(() {
      _isSpeaking = true;
      _currentlySpeakingId = message.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.volume_up_rounded,
              color: AgroColors.softGold,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.isHi
                    ? '🔊 AG Farmer बोलकर सुना रहा है...'
                    : '🔊 AG Farmer is reading aloud...',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await speechSpeakService.speak(message.text, hindi: s.isHi);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _currentlySpeakingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isHi
                ? 'आवाज़ उपलब्ध नहीं। फोन की TTS / भाषा सेटिंग चेक करें।'
                : 'Voice unavailable. Check device TTS / language settings.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickLeafPhoto(ImageSource source) async {
    final s = AgroScope.of(context).s;
    try {
      final photo = await LeafPhotoPicker.pick(source);
      if (photo == null || !mounted) return;
      setState(() => _pendingPhoto = photo);
    } catch (e) {
      if (!mounted) return;
      final tooBig = e.toString().contains('file_too_large');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tooBig
                ? (s.isHi
                      ? 'फोटो बहुत बड़ी है। पास से एक साफ फोटो लें।'
                      : 'Photo is too large. Take a closer clear photo.')
                : (s.isHi
                      ? 'फोटो नहीं खुली। फिर कोशिश करें।'
                      : 'Could not open the photo. Try again.'),
          ),
        ),
      );
    }
  }

  void _openCameraModal() {
    final s = AgroScope.of(context).s;
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.agroBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AgroColors.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AgroColors.gold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.photoModalTitle,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: context.agroText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.photoModalSub,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.agroTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.agroGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.photo_camera_front_rounded,
                      color: context.agroGold,
                    ),
                  ),
                  title: Text(
                    s.cameraButton,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    s.isHi
                        ? 'पत्ती या कीड़े की तुरंत साफ फोटो लें'
                        : 'Snap a clear leaf/pest photo',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickLeafPhoto(ImageSource.camera);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AgroColors.leaf.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: context.isDark ? AgroColors.mint : AgroColors.leaf,
                    ),
                  ),
                  title: Text(
                    s.galleryButton,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    s.isHi
                        ? 'फोन में पहले से मौजूद फोटो चुनें'
                        : 'Pick existing photo from gallery',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickLeafPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _rateMessage(String messageId, bool isHelpful, dynamic s) {
    HapticFeedback.selectionClick();
    setState(() {
      _feedbackRatings[messageId] = isHelpful;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isHelpful
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_down_alt_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(s.feedbackThanks),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openReportAiModal(ChatMessage message, dynamic s) {
    HapticFeedback.lightImpact();
    String selectedReason = s.reportReasonPesticide;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.agroCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final reasons = [
              s.reportReasonPesticide,
              s.reportReasonInaccurate,
              s.reportReasonOffensive,
              s.reportReasonOther,
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.agroBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AgroColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: AgroColors.danger,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.reportAiTitle,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: context.agroText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.reportAiSubtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.agroTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...reasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedReason = reason;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 6,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AgroColors.deepGreen
                                        : context.agroBorder,
                                    width: isSelected ? 6 : 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? context.agroText
                                        : context.agroTextMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          setState(() {
                            _reportedMessageIds.add(message.id);
                          });

                          try {
                            await ApiClient.instance.call(
                              'report.create',
                              auth: true,
                              data: {
                                'report': {
                                  'messageId': message.id,
                                  'messageSnippet': message.text.length > 200
                                      ? '${message.text.substring(0, 200)}...'
                                      : message.text,
                                  'reason': selectedReason,
                                  'userEmail': authService.user?.email ?? '',
                                  'reportedAt': DateTime.now()
                                      .toIso8601String(),
                                },
                              },
                            );
                          } catch (_) {}

                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(s.reportSuccess)),
                                ],
                              ),
                              backgroundColor: AgroColors.deepGreen,
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(s.reportSubmitBtn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AgroColors.deepGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLiveAssistant() async {
    HapticFeedback.lightImpact();
    final ok = await ensureLiveVoiceAccess(context);
    if (!ok || !mounted) return;
    _liveOpen = true;
    Object? result;
    try {
      result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VoiceLiveScreen(
            isHi: AgroScope.of(context).s.isHi,
            initialLines: _messages
                .where((m) => m.text.trim().isNotEmpty)
                .map(
                  (m) => (
                    role: m.role == MessageRole.user ? 'user' : 'assistant',
                    text: m.text,
                  ),
                )
                .toList(),
            onAsk: (text) => _send(text, null, 'openai', true),
          ),
        ),
      );
    } finally {
      _liveOpen = false;
    }
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
    _mergeLiveTranscript(result);
    if (result == 'upgrade') {
      await showPlanUnlockSheet(context, forLiveVoice: true);
      return;
    }
    if (result == 'limit' || result == 'credit') {
      await openCreditTokenScreen(context);
    }
  }

  void _mergeLiveTranscript(Object? result) {
    if (result is! List) return;
    const hide = {
      'सोच रहा हूँ...',
      'Thinking...',
      'जवाब नहीं आ पाया। फिर बोलें।',
      'No answer came through. Speak again.',
      'राम-राम किसान भाई, बताओ क्या सहायता चाहिए। यहाँ मुझे बोलकर बताएं।',
      'Ram-ram. Tell me what help you need. Say it here.',
    };
    var added = false;
    for (final raw in result) {
      if (raw is! Map) continue;
      final role = '${raw['role'] ?? ''}';
      final text = '${raw['text'] ?? ''}'.trim();
      if (text.isEmpty || hide.contains(text)) continue;
      if (_messages.any((m) => m.text.trim() == text)) continue;
      _messages.add(
        ChatMessage(
          id: 'live_${DateTime.now().microsecondsSinceEpoch}_$role',
          text: text,
          role: role == 'user' ? MessageRole.user : MessageRole.assistant,
          createdAt: DateTime.now(),
        ),
      );
      added = true;
    }
    if (!added) return;
    setState(() {});
    chatSyncService.sync(
      List<ChatMessage>.from(_messages),
      sessionId: _sessionId,
      chatName: _chatName,
    );
  }

  Future<void> _openVideoCall() async {
    HapticFeedback.lightImpact();
    final ok = await ensureVideoCallAccess(context);
    if (!ok || !mounted) return;
    final cropId = _selectedCropId == 'all' ? null : _selectedCropId;
    final recent = _messages.where((m) => m.text.trim().isNotEmpty).toList();
    final tail = recent.length <= 5
        ? recent
        : recent.sublist(recent.length - 5);
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          cropId: cropId,
          mode: 'chat',
          sessionId: _sessionId,
          isHi: AgroScope.of(context).s.isHi,
          recent: [
            for (final m in tail)
              {
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'text': m.text.trim().length > 40
                    ? m.text.trim().substring(0, 40)
                    : m.text.trim(),
              },
          ],
          onLine: (role, text) {
            if (!mounted) return;
            final hi = AgroScope.of(context).s.isHi;
            setState(() {
              _messages.add(
                ChatMessage(
                  id: '${DateTime.now().microsecondsSinceEpoch}_$role',
                  text: text,
                  role: role == 'user'
                      ? MessageRole.user
                      : MessageRole.assistant,
                  createdAt: DateTime.now(),
                  cropTag: _selectedCropId == 'all'
                      ? null
                      : _selectedCropName(hi),
                  aiProvider: role == 'user' ? null : 'openai',
                ),
              );
            });
            _scrollToEnd(force: true);
            chatSyncService.sync(
              List<ChatMessage>.from(_messages),
              sessionId: _sessionId,
              chatName: _chatName,
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

  String _historyWhen(dynamic raw, bool hi) {
    final ms = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (ms == null || ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return hi ? 'आज · $hm' : 'Today · $hm';
    if (day == today.subtract(const Duration(days: 1))) {
      return hi ? 'कल · $hm' : 'Yesterday · $hm';
    }
    return '${dt.day}/${dt.month} · $hm';
  }

  DateTime _sessionDay(Map<String, dynamic> session) {
    final raw = session['lastMessageAt'] ?? session['updatedAt'];
    final ms = raw is num ? raw.toInt() : int.tryParse('$raw');
    final dt = ms == null || ms <= 0
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(dt.year, dt.month, dt.day);
  }

  String _dayTitle(DateTime day, bool hi, int count) {
    const hiMonths = [
      'जनवरी',
      'फ़रवरी',
      'मार्च',
      'अप्रैल',
      'मई',
      'जून',
      'जुलाई',
      'अगस्त',
      'सितंबर',
      'अक्टूबर',
      'नवंबर',
      'दिसंबर',
    ];
    const enMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = hi ? hiMonths[day.month - 1] : enMonths[day.month - 1];
    final talks = hi ? '$count बातचीत' : '$count chats';
    return '${day.day} $month · $talks';
  }

  List<Widget> _historyDaySections({
    required bool hi,
    required void Function(String sid, String name) onOpen,
    required void Function(String sid, String name) onRename,
    required void Function(String sid, String name) onShare,
    required void Function(String sid, String name) onDelete,
  }) {
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final session in _serverSessions) {
      groups.putIfAbsent(_sessionDay(session), () => []).add(session);
    }
    final days = groups.keys.toList()..sort((a, b) => a.compareTo(b));
    final out = <Widget>[];
    for (final day in days) {
      final items = groups[day]!
        ..sort((a, b) {
          int ms(Map<String, dynamic> row) {
            final raw = row['lastMessageAt'] ?? row['updatedAt'];
            if (raw is num) return raw.toInt();
            return int.tryParse('$raw') ?? 0;
          }
          return ms(a).compareTo(ms(b));
        });
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            _dayTitle(day, hi, items.length),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: context.agroText,
            ),
          ),
        ),
      );
      for (final session in items) {
        final sid = '${session['id'] ?? session['sessionId'] ?? 'main'}';
        final custom = session['custom'] == true;
        final topic = '${session['topic'] ?? ''}'.trim();
        final rawName = '${session['name'] ?? sid}'.trim();
        final name = custom && rawName.isNotEmpty
            ? rawName
            : (topic.isNotEmpty ? topic : rawName);
        final when = _historyWhen(
          session['lastMessageAt'] ?? session['updatedAt'],
          hi,
        );
        final active = sid == _sessionId;
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: active
                  ? AgroColors.gold.withValues(alpha: 0.16)
                  : context.agroSoftFill,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpen(sid, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? AgroColors.gold.withValues(alpha: 0.7)
                          : context.agroBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AgroColors.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: context.agroGold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: context.agroText,
                              ),
                            ),
                            if (when.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                when,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.agroTextMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: hi ? 'शेयर' : 'Share',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onShare(sid, name),
                        icon: Icon(
                          Icons.share_rounded,
                          size: 20,
                          color: context.agroGold,
                        ),
                      ),
                      IconButton(
                        tooltip: hi ? 'नाम बदलो' : 'Rename',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onRename(sid, name),
                        icon: Icon(
                          Icons.edit_rounded,
                          size: 20,
                          color: context.agroGold,
                        ),
                      ),
                      IconButton(
                        tooltip: hi ? 'हटाएँ' : 'Delete',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onDelete(sid, name),
                        icon: Icon(
                          Icons.menu_rounded,
                          size: 22,
                          color: context.agroText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return out;
  }

  Future<void> _openHistorySheet() async {
    final s = AgroScope.of(context).s;
    HapticFeedback.lightImpact();
    await _refreshSessions();
    if (!mounted) return;
    final historyScroll = ScrollController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.agroCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.agroBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: AgroColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              s.chatHistoryTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: context.agroText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetChat();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(s.chatNewTopic),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_serverSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 42,
                            color: context.agroTextMuted.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.noChatHistory,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.agroTextMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.62,
                    ),
                    child: ListView(
                      controller: historyScroll,
                      shrinkWrap: true,
                      children: _historyDaySections(
                        hi: s.isHi,
                        onOpen: (sid, name) async {
                          Navigator.pop(ctx);
                          await _openNamedSession(sid, name);
                        },
                        onRename: (sid, name) async {
                          final next = await _askHistoryName(name, s.isHi);
                          if (next == null || next.isEmpty || next == name) {
                            return;
                          }
                          await chatSyncService.createSession(
                            sessionId: sid,
                            chatName: next,
                          );
                          if (!mounted) return;
                          setState(() {
                            if (_sessionId == sid) _chatName = next;
                            for (final row in _serverSessions) {
                              final id =
                                  '${row['id'] ?? row['sessionId'] ?? ''}';
                              if (id != sid) continue;
                              row['name'] = next;
                              row['topic'] = next;
                              row['custom'] = true;
                            }
                          });
                          setSheet(() {});
                        },
                        onShare: (sid, name) => _shareHistory(sid, name, s.isHi),
                        onDelete: (sid, name) async {
                          final gone = await _deleteHistory(sid, name, s.isHi);
                          if (gone) setSheet(() {});
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
          },
        );
      },
    ).whenComplete(historyScroll.dispose);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!historyScroll.hasClients) return;
      historyScroll.jumpTo(historyScroll.position.maxScrollExtent);
    });
  }

  Future<String?> _askHistoryName(String current, bool hi) async {
    final typed = TextEditingController(text: current);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(hi ? 'चैट का नाम' : 'Chat name'),
          content: TextField(
            controller: typed,
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: hi ? 'अपना नाम लिखो' : 'Type a name',
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(hi ? 'रद्द' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, typed.text.trim()),
              child: Text(hi ? 'रखो' : 'Save'),
            ),
          ],
        );
      },
    );
    typed.dispose();
    if (next == null) return null;
    final name = next.trim();
    return name.isEmpty ? null : name;
  }

  Future<void> _shareTurn(ChatMessage output, bool hi) async {
    final turn = turnForPdf(_messages, output);
    await _sharePdf(
      title: turnPdfTitle(turn, hi: hi),
      messages: turn,
      hi: hi,
    );
  }

  Future<void> _shareHistory(String sid, String name, bool hi) async {
    try {
      var msgs = sid == _sessionId
          ? List<ChatMessage>.from(_messages)
          : await chatSyncService.restore(sessionId: sid, limit: 200);
      if (!mounted) return;
      await _sharePdf(title: name, messages: msgs, hi: hi);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hi
                ? 'PDF अभी शेयर नहीं हुई। एक बार फिर कोशिश करें।'
                : 'The PDF could not be shared. Try once more.',
          ),
        ),
      );
    }
  }

  Future<void> _sharePdf({
    required String title,
    required List<ChatMessage> messages,
    required bool hi,
  }) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    nav.push(dialog);
    try {
      await shareChatPdf(title: title, messages: messages, hi: hi);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hi
                ? 'PDF अभी शेयर नहीं हुई। एक बार फिर कोशिश करें।'
                : 'The PDF could not be shared. Try once more.',
          ),
        ),
      );
    } finally {
      if (dialog.isActive) nav.removeRoute(dialog);
    }
  }

  Future<bool> _deleteHistory(String sid, String name, bool hi) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hi ? 'चैट हटाएँ' : 'Delete chat'),
        content: Text(
          hi
              ? '"$name" हमेशा के लिए हट जाएगी।'
              : '"$name" will be removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(hi ? 'रद्द' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hi ? 'हटाओ' : 'Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return false;
    final res = await chatSyncService.deleteSession(sid);
    if (!mounted) return false;
    if (res == null || res['ok'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hi
                ? 'चैट अभी नहीं हटी। एक बार फिर कोशिश करें।'
                : 'The chat was not deleted. Try once more.',
          ),
        ),
      );
      return false;
    }
    setState(() {
      _serverSessions.removeWhere(
        (row) => '${row['id'] ?? row['sessionId'] ?? ''}' == sid,
      );
      if (_sessionId == sid) {
        final pack = AgroScope.of(context).s;
        _sessionId = 's_${DateTime.now().millisecondsSinceEpoch}';
        _chatName = hi ? 'नई चैट' : 'New chat';
        _messages
          ..clear()
          ..add(
            ChatMessage(
              id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
              text: _packText(pack, 'welcome', pack.chatWelcome),
              role: MessageRole.assistant,
              createdAt: DateTime.now(),
            ),
          );
      }
    });
    return true;
  }

  Future<void> _openNamedSession(String sid, String name) async {
    final s = AgroScope.of(context).s;
    if (_messages.length > 1) {
      // ignore: unawaited_futures
      chatSyncService.sync(
        List<ChatMessage>.from(_messages),
        sessionId: _sessionId,
        chatName: _chatName,
      );
    }
    setState(() {
      _sessionId = sid;
      _chatName = name;
      _typing = true;
    });
    final restored = await chatSyncService.restore(sessionId: sid);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            text: _packText(s, 'welcome', s.chatWelcome),
            role: MessageRole.assistant,
            createdAt: DateTime.now(),
          ),
        );
      if (restored.isNotEmpty) {
        _messages.addAll(restored.where((m) => !m.id.startsWith('welcome_')));
      }
      _typing = false;
    });
    _scrollToEnd(force: true);
  }

  void _openModelPicker() {
    final s = AgroScope.of(context).s;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final locked = chatLimitsService.deepFor(profileService.plan) <= 0 ||
                !featureControls.on('deep');
            final deepOn = _deepResearch && !locked;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: context.isDark
                      ? const [Color(0xFF082236), Color(0xFF031626)]
                      : const [Color(0xFF032B43), Color(0xFF073A5C)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: AgroColors.skyLight.withValues(alpha: 0.35),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AgroColors.premiumHero,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.isHi
                                      ? 'प्रीमियम AI चुनें'
                                      : 'Choose Premium AI',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  s.isHi
                                      ? 'दोनों AG Farmer AI — अपनी पसंद चुनें'
                                      : 'Both are AG Farmer AI — pick your style',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ModelOptionTile(
                        title: 'AG High',
                        subtitle: ChatMessage.providerSubtitle(
                          'gemini',
                          isHi: s.isHi,
                        ),
                        badge: s.isHi ? 'हाई' : 'HIGH',
                        icon: Icons.bolt_rounded,
                        selected: _selectedProvider == 'gemini',
                        premium: false,
                        onTap: () {
                          _setProvider('gemini');
                          Navigator.pop(ctx);
                        },
                      ),
                      const SizedBox(height: 8),
                      _ModelOptionTile(
                        title: 'AG Expert',
                        subtitle: ChatMessage.providerSubtitle(
                          'openai',
                          isHi: s.isHi,
                        ),
                        badge: s.isHi ? 'एक्सपर्ट' : 'EXPERT',
                        icon: Icons.auto_awesome_rounded,
                        selected: _selectedProvider == 'openai',
                        premium: true,
                        onTap: () {
                          _setProvider('openai');
                          Navigator.pop(ctx);
                        },
                      ),
                      const SizedBox(height: 8),
                      _ModelOptionTile(
                        title: s.isHi ? 'डीप रिसर्च' : 'Deep research',
                        subtitle: s.isHi
                            ? 'इस मैसेज पर गहरी जाँच'
                            : 'Deeper check on this message',
                        badge: deepOn
                            ? (s.isHi ? 'चालू' : 'ON')
                            : (s.isHi ? 'बंद' : 'OFF'),
                        icon: Icons.travel_explore_rounded,
                        selected: deepOn,
                        premium: true,
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<({String cropId, String label, String query})> _topSuggestions(bool hi) {
    if (_selectedCropId == 'afim') {
      return [
        (
          cropId: 'afim',
          label: hi ? 'अफीम में खाखरिया' : 'Opium mildew',
          query: hi ? 'अफीम में खाखरिया' : 'Opium mildew',
        ),
      ];
    }
    if (_selectedCropId == 'lasun') {
      return [
        (
          cropId: 'lasun',
          label: hi ? 'लहसुन में थ्रिप्स' : 'Garlic thrips',
          query: hi ? 'लहसुन में थ्रिप्स' : 'Garlic thrips',
        ),
      ];
    }
    return const <({String cropId, String label, String query})>[];
  }

  void _tapSuggest(String cropId, String query) {
    setState(() {
      _selectedCropId = cropId;
      _activeCrop = catalogService.cropById(cropId);
    });
    _send(query);
  }

  Widget _tinyWord(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: context.agroCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.agroBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: context.agroText,
            ),
          ),
        ),
      ),
    );
  }

  void _openChatMenu(dynamic s) {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _MenuLineButton(
                        icon: Icons.add_comment_rounded,
                        label: s.chatNewTopic,
                        onTap: () {
                          Navigator.pop(ctx);
                          _resetChat();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MenuLineButton(
                        icon: Icons.history_rounded,
                        label: s.chatHistoryTitle,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openHistorySheet();
                        },
                      ),
                    ),
                  ],
                ),
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
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: Row(
                children: [
                  const BrandLogo(size: 40, radius: 12),
                  const SizedBox(width: 10),
                  Text(
                    s.navChat,
                    style: TextStyle(
                      color: face.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: s.isHi ? 'मेनू' : 'Menu',
                    onPressed: () => _openChatMenu(s),
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

    final topGap = MediaQuery.paddingOf(context).top + 58;
    final lines = _datedChatLines(_messages);
    final messages = HalfPullRefresh(
            onRefresh: _pullRefresh,
            child: _messages.length <= 1
              ? _buildEmptyState(s)
              : SwipeMessageTime(
                  builder: (context, reveal) => ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(14, topGap, 14, 16),
                    itemCount: lines.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_typing && index == lines.length) {
                        return MessageTimeSlot(
                          reveal: reveal,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              child: _TypingCard(),
                            ),
                          ),
                        );
                      }

                      final line = lines[index];
                      if (line.day != null) {
                        return _ChatDateLine(day: line.day!, hi: s.isHi);
                      }
                      final message = line.message!;
                      final isUser = message.role == MessageRole.user;
                      final bubble = isUser
                          ? _buildUserBubble(message)
                          : _buildAssistantCard(message, s);

                      return MessageTimeSlot(
                        reveal: reveal,
                        time: messageSentTime(message.createdAt, hi: s.isHi),
                        child: RepaintBoundary(child: bubble),
                      );
                    },
                  ),
                ),
          );

    final prompts = ServerPromptStrip(
          screen: 'chat',
          hi: s.isHi,
          onTap: (text, cropId) {
            if (cropId != null && cropId.isNotEmpty) {
              _tapSuggest(cropId, text);
            } else {
              _send(text);
            }
          },
        );

    final composer = _buildBottomInputBar(s);
    _scrollToEnd();
    return FrontScope(
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    messages,
                    if (_showDown)
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: _latestArrow(),
                      ),
                  ],
                ),
              ),
              prompts,
              composer,
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
  }

  // AG Farmer Empty State with Desi Farmer Hero & 6 Prompt Cards
  Widget _buildEmptyState(dynamic s) {
    final topGap = MediaQuery.paddingOf(context).top + 58;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, topGap, 16, 20),
      child: Column(
        children: [
          // Glowing Brand Logo Hero
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AgroColors.gold.withValues(alpha: 0.28),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const BrandLogo(size: 76, radius: 22, framed: true),
          ),
          const SizedBox(height: 14),
          Text(
            _packText(s, 'greetingTitle', s.chatGreetingTitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.agroText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (_topSuggestions(s.isHi).isNotEmpty) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in _topSuggestions(s.isHi))
                  _tinyWord(
                    item.label,
                    () => _tapSuggest(item.cropId, item.query),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _packText(s, 'greetingSub', s.chatGreetingSub),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.agroTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Desi Trust Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AgroColors.gold.withValues(alpha: 0.18),
                  AgroColors.deepGreen.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AgroColors.gold.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AgroColors.gold,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _packText(
                      s,
                      'badge',
                      s.isHi
                          ? '⚡ देसी AI कृषि वैज्ञानिक • तुरंत सटीक जवाब'
                          : '⚡ AI Agri Scientist • Instant Answers',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.isDark
                          ? AgroColors.softGold
                          : AgroColors.deepGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // User Message Bubble
  Widget _buildUserBubble(ChatMessage message) {
    final hindi = AgroScope.of(context).s.isHi;
    return Align(
      alignment: Alignment.centerRight,
      child: Builder(
        builder: (bubbleContext) => GestureDetector(
        onLongPress: () => showMessageCopyMenu(
          bubbleContext,
          text: message.text,
          hindi: hindi,
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
            width: 1,
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
            if (message.imagePath != null) ...[
              _userPhoto(message.imagePath!),
              const SizedBox(height: 8),
            ],
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
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

  /// Answer bubble stays as wide as the words, and stops around 2–3 lines.
  double _bubbleCap(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.62).clamp(200.0, 270.0);
  }

  // AG Farmer Style Assistant Card
  Widget _buildAssistantCard(ChatMessage message, dynamic s) {
    final isSpeakingThis = _isSpeaking && _currentlySpeakingId == message.id;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AG Farmer Left Header Row
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AgroColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message.aiLabel.isNotEmpty
                        ? message.aiLabel
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
                '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10.5, color: context.agroTextMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card Body
          Builder(
            builder: (bubbleContext) => GestureDetector(
            onLongPress: () => showMessageCopyMenu(
              bubbleContext,
              text: message.text,
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
                // Highlighted Dosage Box if present
                if (message.dosageHighlight != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AgroColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AgroColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medication_liquid_rounded,
                          color: AgroColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.dosageHighlight!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.isDark
                                  ? AgroColors.softGold
                                  : const Color(0xFF5B3E00),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                message.isStreaming
                    ? AnswerPipe(
                        key: ValueKey('pipe-${message.id}'),
                        text: message.text,
                        style: TextStyle(
                          color: context.agroText,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: AgroColors.deepGreen,
                        onDone: () => _finishPipe(message.id),
                      )
                    : ChatAnswerBody(text: message.text),
                const SizedBox(height: 8),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _toggleSpeak(message),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        // 44dp min tap target; row is already 48 tall
                        // because of the PopupMenuButton, so no layout shift.
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSpeakingThis
                                ? AgroColors.gold.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSpeakingThis
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded,
                                size: 16,
                                color: isSpeakingThis
                                    ? AgroColors.gold
                                    : context.agroTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSpeakingThis
                                    ? (s.isHi ? 'चल रहा है...' : 'Playing...')
                                    : s.listenButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSpeakingThis
                                      ? AgroColors.gold
                                      : context.agroTextMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!message.isStreaming && !message.id.startsWith('welcome_'))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          onTap: () => _shareTurn(message, s.isHi),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
                          _copyToClipboard(message.text);
                        } else if (value == 'up') {
                          _rateMessage(message.id, true, s);
                        } else if (value == 'down') {
                          _rateMessage(message.id, false, s);
                        } else if (value == 'report' &&
                            !_reportedMessageIds.contains(message.id)) {
                          _openReportAiModal(message, s);
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
                          enabled: !_reportedMessageIds.contains(message.id),
                          child: Text(
                            _reportedMessageIds.contains(message.id)
                                ? (s.isHi ? 'रिपोर्ट हुआ' : 'Reported')
                                : s.reportAiButton,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _userPhoto(String path) {
    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          path,
          height: 160,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 160,
              width: 220,
              color: Colors.white.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, color: Colors.white),
        ),
      );
    }
    if (localFileExists(path)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: localFileImage(path, height: 160, width: 220, fit: BoxFit.cover),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_rounded,
            color: AgroColors.softGold,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'पत्ती की फोटो संलग्न',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingPhotoCard(dynamic s) {
    final photo = _pendingPhoto;
    if (photo == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: localFileExists(photo.path)
                ? localFileImage(
                    photo.path,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.image_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.isHi ? 'फोटो भेजने के लिए तैयार' : 'Photo ready to send',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _pendingPhoto = null),
            child: Text(s.isHi ? 'हटाएँ' : 'Remove'),
          ),
        ],
      ),
    );
  }

  Widget _bottomNoticeCard(dynamic s) {
    final login = _bottomNotice == 'login';
    return ChatLimitNotice(
      login: login,
      isHi: s.isHi,
      onPressed: login ? _openLogin : _openUpgrade,
    );
  }

  // AG Farmer bottom input — stable single-row layout, theme colors preserved
  Widget _buildBottomInputBar(dynamic s) {
    final iconColor = context.isDark
        ? AgroColors.nightGold
        : AgroColors.deepGreen;

    return Material(
      color: context.agroNavBg,
      elevation: 0,
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
                if (_bottomNotice != null) _bottomNoticeCard(s),
                _pendingPhotoCard(s),
                Builder(
                  builder: (context) {
                    final canSend = _controller.text.trim().isNotEmpty ||
                        _pendingPhoto != null;
                    final allowSend =
                        canSend && screenPack.on('chat', 'showSend', true);
                    final showVoiceBtn =
                        screenPack.on('chat', 'showVoice', true) &&
                        featureControls.on('voiceCall');
                    final showVideo = screenPack.on('chat', 'showVideo', true) &&
                        featureControls.on('videoCall');
                    final showPhoto = screenPack.on('chat', 'showPhoto', true) &&
                        featureControls.on('image');
                    final modelTip = _deepResearch
                        ? (s.isHi
                              ? 'प्रीमियम AI • डीप रिसर्च चालू'
                              : 'Premium AI • deep research on')
                        : ChatMessage.providerDisplayName(_selectedProvider);
                    final modelColor = _deepResearch
                        ? const Color(0xFF7C3AED)
                        : iconColor;
                    final left = <_MixHalf>[
                      if (showPhoto)
                        _MixHalf(
                          icon: Icons.photo_camera_rounded,
                          tip: s.isHi ? 'कैमरा' : 'Camera',
                          color: iconColor,
                          onTap: _openCameraModal,
                        ),
                      _MixHalf(
                        icon: Icons.auto_awesome_rounded,
                        tip: modelTip,
                        color: modelColor,
                        onTap: _openModelPicker,
                      ),
                    ];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 3,
                            maxLines: 6,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: context.agroText,
                            ),
                            decoration: InputDecoration(
                              hintText: _packText(s, 'hint', s.chatHint),
                              hintStyle: TextStyle(
                                fontSize: 13.5,
                                color: context.agroTextMuted,
                              ),
                              filled: true,
                              fillColor: context.agroCard,
                              isDense: true,
                              constraints: const BoxConstraints(minHeight: 98),
                              contentPadding: const EdgeInsets.fromLTRB(
                                8,
                                16,
                                12,
                                16,
                              ),
                              prefixIcon: _InMix(parts: left),
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
                        if (allowSend || showVideo || showVoiceBtn) ...[
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showVideo)
                                _FeaturePill(
                                  label: _packText(
                                    s,
                                    'video',
                                    s.isHi ? 'वीडियो कॉल' : 'Video call',
                                  ),
                                  icon: Icons.videocam_rounded,
                                  colors: const [
                                    Color(0xFFB45309),
                                    Color(0xFFE8B84A),
                                  ],
                                  onTap: _openVideoCall,
                                  size: 44,
                                ),
                              if (allowSend) ...[
                                if (showVideo) const SizedBox(height: 6),
                                _FeaturePill(
                                  label: s.isHi ? 'भेजें' : 'Send',
                                  icon: Icons.arrow_upward_rounded,
                                  colors: const [
                                    AgroColors.deepGreen,
                                    AgroColors.leaf,
                                  ],
                                  onTap: () => _send(),
                                  size: 44,
                                ),
                              ] else if (showVoiceBtn) ...[
                                if (showVideo) const SizedBox(height: 6),
                                _FeaturePill(
                                  label: _packText(s, 'live', 'AG Live'),
                                  icon: Icons.mic_rounded,
                                  colors: const [
                                    Color(0xFF0369A1),
                                    Color(0xFF0EA5E9),
                                  ],
                                  onTap: _openLiveAssistant,
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
                const SizedBox(height: 6),
                Text(
                  s.aiDisclaimerNotice,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.25,
                    color: context.agroTextMuted.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  final VoidCallback onTap;
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

class _QuickCrop {
  final String id;
  final String nameHi;
  final String nameEn;
  final String icon;

  const _QuickCrop({
    required this.id,
    required this.nameHi,
    required this.nameEn,
    required this.icon,
  });
}

class _ModelOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool selected;
  final bool premium;
  final VoidCallback onTap;

  const _ModelOptionTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.selected,
    required this.premium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: premium
                      ? [
                          const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                          const Color(0xFF0284C7).withValues(alpha: 0.22),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? (premium ? const Color(0xFF7DD3FC) : Colors.white70)
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: premium ? AgroColors.premiumHero : null,
                color: premium ? null : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: premium
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: premium
                                ? const Color(0xFFE0F2FE)
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? const Color(0xFF7DD3FC)
                  : Colors.white.withValues(alpha: 0.45),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingCard extends StatelessWidget {
  const _TypingCard();

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

final _weakTitle = RegExp(
  r'''^(h+i+|hello+|hey+|helo+|namaste|namaskar|good\s*(morning|evening|afternoon|night)|yo|sup|नमस्ते|नमस्कार|हेलो|हाय|हाए|राम\s*राम|प्रणाम|नई चैट|new chat|general chat)[\s!.,।🙏]*$''',
  caseSensitive: false,
);

bool _isWeakTitle(String name) => _weakTitle.hasMatch(name.trim());

String _stripLeadGreeting(String text) {
  return text
      .replaceFirst(
        RegExp(
          r'''^(h+i+|hello+|hey+|helo+|namaste|namaskar|नमस्ते|नमस्कार|हेलो|हाय|हाए|राम\s*राम|प्रणाम)[,!\s.।🙏]+''',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

String _clipTopicWords(String text, int maxWords) {
  final words = text
      .replaceAll(RegExp(r'[*#_]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final kept = words.take(maxWords).join(' ');
  return words.length > maxWords ? '$kept…' : kept;
}

const _topicCrops = <List<String>>[
  [r'अफीम|अफ़ीम|afim|opium|poppy|पोस्त', 'अफीम'],
  [r'लहसुन|lahsun|garlic', 'लहसुन'],
  [r'प्याज|onion|pyaaz|pyaj', 'प्याज'],
  [r'गेहूँ|गेहूं|gehun|wheat', 'गेहूँ'],
  [r'धान|चावल|paddy|rice|dhan', 'धान'],
  [r'मक्का|makka|maize|corn', 'मक्का'],
  [r'कपास|cotton|kapas', 'कपास'],
  [r'सरसों|mustard|sarson', 'सरसों'],
  [r'चना|chana|gram', 'चना'],
  [r'टमाटर|tomato|tamatar', 'टमाटर'],
  [r'मिर्च|mirch|chilli|chili', 'मिर्च'],
  [r'आलू|potato|aalu|aloo', 'आलू'],
  [r'गन्ना|sugarcane|ganna', 'गन्ना'],
  [r'सोयाबीन|soy', 'सोयाबीन'],
  [r'मूंगफली|groundnut|moongphali', 'मूंगफली'],
  [r'जीरा|jeera|cumin', 'जीरा'],
  [r'धनिया|coriander|dhaniya', 'धनिया'],
  [r'हल्दी|turmeric|haldi', 'हल्दी'],
  [r'अदरक|ginger|adrak', 'अदरक'],
];

const _topicIssues = <List<String>>[
  [r'पील|yellow|peel', 'पीलापन'],
  [r'कीट|कीड़ा|कीडा|pest|keet|insect', 'कीट'],
  [r'रोग|बीमारी|bimari|disease', 'रोग'],
  [r'खाद|fertilizer|fertiliser|khad|यूरिया|urea|\bdap\b', 'खाद'],
  [r'सिंचाई|सिंच|पानी|irrigation|sinchai|water', 'सिंचाई'],
  [r'बुवाई|बुआई|sowing|buwai|बोना|बीज बो', 'बुवाई'],
  [r'बीज|seed|beej', 'बीज'],
  [r'खरपतवार|weed', 'खरपतवार'],
  [r'कटाई|harvest|katai', 'कटाई'],
  [r'धब्ब|spot|daag|दाग', 'धब्बे'],
  [r'सड़|rot|galn|गलन', 'सड़ना'],
  [r'सूख|wilt|sukha|dry', 'सूखना'],
  [r'मंडी|भाव|bhav|price|rate', 'मंडी भाव'],
  [r'दवा|spray|दवाई|छिड़काव', 'दवा'],
];

class _ChatLine {
  const _ChatLine.message(this.message) : day = null;
  const _ChatLine.day(this.day) : message = null;

  final ChatMessage? message;
  final DateTime? day;
}

List<_ChatLine> _datedChatLines(List<ChatMessage> messages) {
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
  final lines = <_ChatLine>[];
  for (final m in welcome) {
    lines.add(_ChatLine.message(m));
  }
  DateTime? day;
  for (final m in rest) {
    final local = m.createdAt.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    if (day == null || d != day) {
      lines.add(_ChatLine.day(d));
      day = d;
    }
    lines.add(_ChatLine.message(m));
  }
  return lines;
}

class _ChatDateLine extends StatelessWidget {
  const _ChatDateLine({required this.day, required this.hi});

  final DateTime day;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    const hiMonths = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
    ];
    const enMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final label = '${day.day} ${hi ? hiMonths[day.month - 1] : enMonths[day.month - 1]} ${day.year}';
    final line = context.agroMuted.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: line, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
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
    );
  }
}

class _MenuLineButton extends StatelessWidget {
  const _MenuLineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF0F9FF) : const Color(0xFF0F2744);
    final fill = dark ? const Color(0xFF0B2942) : Colors.white;
    final line = dark ? const Color(0xFF1B4E74) : const Color(0xFFBAE6FD);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 72,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: ink),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _topicHit(String text, List<List<String>> table) {
  for (final row in table) {
    if (RegExp(row[0], caseSensitive: false).hasMatch(text)) return row[1];
  }
  return null;
}

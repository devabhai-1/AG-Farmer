import 'dart:async';

import 'package:flutter/material.dart';
import '../services/admin_live_sync.dart';
import '../services/agro_scope.dart';
import '../services/api_client.dart';
import '../services/crop_course_service.dart';
import '../services/page_analytics.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'crop_course_screen.dart';
import 'crop_knowledge_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final ProfileService profileService;

  const MainShell({super.key, required this.profileService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _summaryPoll;
  final List<Widget?> _pages = List<Widget?>.filled(5, null);
  final GlobalKey<ChatScreenState> _chatKey = GlobalKey<ChatScreenState>();
  final GlobalKey<CropKnowledgeScreenState> _jankariKey =
      GlobalKey<CropKnowledgeScreenState>();

  Widget _buildPage(int i) {
    final existing = _pages[i];
    if (existing != null) return existing;
    late final Widget page;
    switch (i) {
      case 0:
        page = HomeScreen(
          onOpenChat: () => _go(1),
          onOpenCourses: () => _go(2),
          onOpenJankari: () => _go(3),
          onSelectTopic: (query, cropId) {
            _go(1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _chatKey.currentState?.sendQueryFromExternal(query, cropId: cropId);
            });
          },
        );
        break;
      case 1:
        page = ChatScreen(key: _chatKey);
        break;
      case 2:
        page = const CropCourseScreen();
        break;
      case 3:
        page = CropKnowledgeScreen(key: _jankariKey);
        break;
      default:
        page = ProfileScreen(profileService: widget.profileService);
    }
    _pages[i] = page;
    return page;
  }

  static const _screens = ['home', 'chat', 'course', 'jankari', 'profile'];

  void _go(int i) {
    if (_index == i) return;
    setState(() {
      _index = i;
      _buildPage(i);
    });
    PageAnalytics.instance.hit(_screens[i]);
    ApiClient.instance.logActivity(
      'screen',
      detail: {'screen': _screens[i]},
      state: {'screen': _screens[i]},
    );
    if (i == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jankariKey.currentState?.reload();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildPage(0);
    _summaryPoll = Timer.periodic(const Duration(seconds: 45), (_) {
      final ist = DateTime.now().toUtc().add(
            const Duration(hours: 5, minutes: 30),
          );
      if (ist.hour == 12 && ist.minute <= 20) {
        cropCourseService.refreshOpenFromServer();
      }
    });
    unawaited(ApiClient.instance.pingPresence(screen: 'home'));
    PageAnalytics.instance.hit('home');
    ApiClient.instance.logActivity(
      'app_open',
      detail: {'screen': 'home'},
      state: {'screen': 'home'},
    );
  }

  @override
  void dispose() {
    _summaryPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    widget.profileService.syncSession();
    AdminLiveSync.instance.pull();
    unawaited(ApiClient.instance.pingPresence(screen: _screens[_index]));
    cropCourseService.refreshOpenFromServer();
    PageAnalytics.instance.hit(_screens[_index]);
    ApiClient.instance.logActivity(
      'app_active',
      detail: {'screen': _screens[_index]},
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final isDark = context.isDark;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        sizing: StackFit.expand,
        children: List<Widget>.generate(5, (i) {
          if (_pages[i] == null && i != _index) {
            return const SizedBox.shrink();
          }
          return KeyedSubtree(
            key: ValueKey('tab_$i'),
            child: _buildPage(i),
          );
        }),
      ),
      bottomNavigationBar: ColoredBox(
        color: context.agroNavBg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.agroGold.withValues(alpha: isDark ? 0.28 : 0.22),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: s.navHome,
                    selected: _index == 0,
                    onTap: () => _go(0),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_rounded,
                    label: s.navChat,
                    selected: _index == 1,
                    onTap: () => _go(1),
                  ),
                  _NavItem(
                    icon: Icons.school_rounded,
                    label: s.navCourse,
                    selected: _index == 2,
                    onTap: () => _go(2),
                  ),
                  _NavItem(
                    icon: Icons.menu_book_rounded,
                    label: s.navJankari,
                    selected: _index == 3,
                    onTap: () => _go(3),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: s.navProfile,
                    selected: _index == 4,
                    onTap: () => _go(4),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = selected
        ? (isDark ? const Color(0xFF0E314D) : const Color(0xFF0284C7))
        : Colors.transparent;
    final fg = selected
        ? Colors.white
        : (isDark ? AgroColors.nightMuted : AgroColors.slate);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

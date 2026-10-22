import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/google_complete_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/main_shell.dart';
import 'services/agro_scope.dart';
import 'services/api_client.dart';
import 'services/admin_live_sync.dart';
import 'services/app_services.dart';
import 'services/page_analytics.dart';
import 'services/client_log.dart';
import 'services/course_summary_notify.dart';
import 'screens/force_update_screen.dart';
import 'services/app_release.dart';
import 'services/feature_controls.dart';
import 'services/screen_pack.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;

  // Local-only boot — never block splash on LAN/API timeouts.
  if (!kIsWeb) {
    // Dart-side Firebase app. Android options come from google-services.json
    // (native init), but FirebaseMessaging.instance still throws
    // [core/no-app] until this runs. Never fatal: push just falls back to
    // the local noon notification.
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
    FirebaseMessaging.onBackgroundMessage(courseSummaryBackground);
  }
  await ApiClient.instance.loadSession();
  await screenPack.loadCache();
  await featureControls.loadCache();
  await Future.wait([
    languageService.load(),
    themeService.load(),
  ]);

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    ClientLog.layout(details.exceptionAsString());
    previousFlutterError?.call(details);
  };

  runApp(const AgFarmerApp());

  // Network + heavier prefs after first frame.
  // ignore: unawaited_futures
  Future<void>(() async {
    await Future.wait([
      catalogService.load(),
      chatLimitsService.load(),
      profileService.load(),
      cropTrackService.load(),
      cropCourseService.load(),
    ]);
    // Notifications must never abort the rest of boot (config, support).
    try {
      await CourseSummaryNotify.instance.start();
    } catch (e) {
      debugPrint('Course summary notify skipped: $e');
    }
    AdminLiveSync.instance.start();
    unawaited(ApiClient.instance.pingPresence(screen: 'boot'));
    unawaited(screenPack.refresh());
    unawaited(ApiClient.instance.refreshFeatures());
    cropCourseService.addListener(CourseSummaryNotify.instance.onCoursesChanged);
    try {
      final cfg = await ApiClient.instance.config();
      debugPrint(
        'Backend config → mode=${cfg['authMode']} api=${cfg['apiUrl']}',
      );
    } catch (e) {
      debugPrint('Backend config unreachable: $e');
    }
    supportService.startListening();
  });

  authService.addListener(() {
    profileService.syncSession();
    cropTrackService.syncSession();
    supportService.refreshMine();
    // Re-load courses from server (or wipe local ghosts after logout / DB clear)
    // ignore: unawaited_futures
    cropCourseService.load().then((_) {
      CourseSummaryNotify.instance.start().catchError((Object e) {
        debugPrint('Course summary notify skipped: $e');
      });
    });
  });
}

/// One layout for every phone. System font size and display size cannot
/// restretch it: the app is always laid out at [designWidth], then fitted
/// onto the real screen.
class _CompactDisplay extends StatelessWidget {
  const _CompactDisplay({required this.child});

  final Widget child;

  /// Logical width the screens were designed for, before [scale].
  static const double designWidth = 360;

  /// 1.0 is the design size. Lower paints every screen smaller.
  static const double scale = 0.78;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final physical = View.of(context).physicalSize;
    final layoutWidth = designWidth / scale;
    final viewAspect = mq.size.width == 0 ? 2.1 : mq.size.height / mq.size.width;
    final layoutHeight = layoutWidth * viewAspect;
    final toLayout = mq.size.width == 0 ? 1.0 : layoutWidth / mq.size.width;
    final pixelsWide = physical.width == 0
        ? mq.size.width * mq.devicePixelRatio
        : physical.width;

    final locked = mq
        .copyWith(
          size: Size(layoutWidth, layoutHeight),
          devicePixelRatio: pixelsWide / layoutWidth,
          textScaler: TextScaler.noScaling,
          padding: mq.padding * toLayout,
          viewPadding: mq.viewPadding * toLayout,
          viewInsets: mq.viewInsets * toLayout,
          systemGestureInsets: mq.systemGestureInsets * toLayout,
        )
        .applyTextStyleOverrides(
          lineHeightScaleFactorOverride: null,
          letterSpacingOverride: null,
          wordSpacingOverride: null,
          paragraphSpacingOverride: null,
        );

    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: layoutWidth,
        height: layoutHeight,
        child: MediaQuery(
          data: locked,
          child: child,
        ),
      ),
    );
  }
}

class AgFarmerApp extends StatelessWidget {
  const AgFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AgroScope(
      service: languageService,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          themeService,
          languageService,
          authService,
          appRelease,
        ]),
        builder: (context, _) {
          return MaterialApp(
            title: 'AG Farmer',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeService.materialMode,
            builder: (context, child) => _CompactDisplay(
              child: child ?? const SizedBox.shrink(),
            ),
            navigatorObservers: [PageAnalyticsObserver()],
            home: const _ReleaseHost(),
          );
        },
      ),
    );
  }
}

class _ReleaseHost extends StatefulWidget {
  const _ReleaseHost();

  @override
  State<_ReleaseHost> createState() => _ReleaseHostState();
}

class _ReleaseHostState extends State<_ReleaseHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRelease.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) appRelease.refresh();
  }

  @override
  Widget build(BuildContext context) => const _BootGate();
}

class _BootGate extends StatelessWidget {
  const _BootGate();

  @override
  Widget build(BuildContext context) {
    if (appRelease.checking) {
      return const Scaffold(
        body: Center(child: BrandLogo(size: 88)),
      );
    }
    if (appRelease.blocked) return const ForceUpdateScreen();

    if (!languageService.ready) {
      return const Scaffold(
        body: Center(child: BrandLogo(size: 88)),
      );
    }

    if (!languageService.hasLanguage) {
      return LanguageSelectScreen(languageService: languageService);
    }

    if (authService.isLoggedIn && authService.needsProfileCompletion) {
      return const GoogleCompleteScreen();
    }

    return MainShell(profileService: profileService);
  }
}

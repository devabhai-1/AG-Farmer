import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

/// Sends page visits to the API. RTDB counts who opened which screen.
class PageAnalytics {
  PageAnalytics._();
  static final PageAnalytics instance = PageAnalytics._();

  String? _last;
  DateTime? _lastAt;

  void hit(String page, {String? extra}) {
    final id = page.trim().toLowerCase();
    if (id.isEmpty) return;
    final now = DateTime.now();
    if (_last == id &&
        extra == null &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return;
    }
    _last = id;
    _lastAt = now;
    unawaited(ApiClient.instance.logPage(id, extra: extra));
  }
}

mixin PageHit<T extends StatefulWidget> on State<T> {
  String get analyticsPage;
  String? get analyticsExtra => null;

  @override
  void initState() {
    super.initState();
    PageAnalytics.instance.hit(analyticsPage, extra: analyticsExtra);
  }
}

class PageAnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _from(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _from(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _from(previousRoute);
  }

  void _from(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/') return;
    PageAnalytics.instance.hit(name);
  }
}

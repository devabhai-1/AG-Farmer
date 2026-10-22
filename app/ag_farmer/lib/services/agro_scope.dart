import 'package:flutter/widgets.dart';

import 'language_service.dart';

/// Provides [LanguageService] to the widget tree.
/// Call sites use `AgroScope.of(context).s` / `.lang` (LanguageService APIs).
class AgroScope extends InheritedNotifier<LanguageService> {
  AgroScope({
    super.key,
    required LanguageService service,
    required super.child,
  }) : super(notifier: service);

  static LanguageService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AgroScope>();
    assert(scope != null, 'AgroScope not found in context');
    return scope!.notifier!;
  }
}

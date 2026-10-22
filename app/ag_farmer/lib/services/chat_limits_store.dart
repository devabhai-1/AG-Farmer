import 'package:flutter/foundation.dart';
import '../models/subscription_plan.dart';
import 'api_client.dart';

class PlanChatLimit {
  const PlanChatLimit({
    required this.totalChat,
    required this.strongChat,
    required this.deep,
    required this.deepPer,
    required this.rollsOver,
    this.videoShots = 1,
  });

  final int totalChat;
  final int strongChat;
  final int deep;
  final String deepPer;
  final bool rollsOver;
  final int videoShots;
}

class ChatLimitsStore extends ChangeNotifier {
  int guestChatLimit = 5;
  int bankDays = 30;
  final Map<String, PlanChatLimit> _plans = {};

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.call('chat.limits');
      final limits = res['limits'];
      if (limits is! Map) return;
      guestChatLimit = int.tryParse('${limits['guestChatLimit']}') ?? guestChatLimit;
      bankDays = int.tryParse('${limits['bankDays']}') ?? bankDays;
      final plans = limits['plans'];
      if (plans is Map) {
        for (final entry in plans.entries) {
          final row = entry.value;
          if (row is! Map) continue;
          _plans[entry.key.toString()] = PlanChatLimit(
            totalChat: int.tryParse('${row['totalChat']}') ?? 0,
            strongChat: int.tryParse('${row['strongChat']}') ?? 0,
            deep: int.tryParse('${row['deep']}') ?? 0,
            deepPer: '${row['deepPer'] ?? 'day'}',
            rollsOver: row['rollsOver'] == true,
            videoShots: int.tryParse('${row['videoShots']}') ?? 1,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('chat limits load failed: $e');
    }
  }

  PlanChatLimit? _row(PlanTier plan) => _plans[plan.planKey];

  int totalFor(PlanTier plan) => _row(plan)?.totalChat ?? plan.chatDailyLimit;

  int deepFor(PlanTier plan) => _row(plan)?.deep ?? plan.deepResearchLimit;

  String deepPerFor(PlanTier plan) => _row(plan)?.deepPer ?? plan.deepResearchPeriod;

  bool rollsFor(PlanTier plan) => _row(plan)?.rollsOver ?? plan.rank >= PlanTier.advanced.rank;

  int videoShotsFor(PlanTier plan) {
    final fromServer = _row(plan)?.videoShots ?? 0;
    if (fromServer > 0) return fromServer.clamp(1, 12);
    switch (plan) {
      case PlanTier.distributor:
        return 10;
      case PlanTier.superPro:
        return 8;
      case PlanTier.allCrops:
        return 6;
      case PlanTier.advanced:
        return 4;
      case PlanTier.free:
      case PlanTier.local:
        return 2;
    }
  }
}

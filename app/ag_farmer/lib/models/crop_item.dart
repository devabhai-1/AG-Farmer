import '../models/subscription_plan.dart';

class CropItem {
  final String id;
  final String nameEn;
  final String nameHi;
  final String emoji;
  final PlanTier minPlan;
  final int priority;
  final bool hasLiveAnalysis;
  final bool active;

  const CropItem({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.emoji,
    required this.minPlan,
    required this.priority,
    this.hasLiveAnalysis = false,
    this.active = true,
  });

  String name(bool hi) => hi ? nameHi : nameEn;

  factory CropItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return CropItem(
      id: (map['id'] ?? id).toString(),
      nameEn: (map['nameEn'] ?? id).toString(),
      nameHi: (map['nameHi'] ?? map['nameEn'] ?? id).toString(),
      emoji: (map['emoji'] ?? '🌾').toString(),
      minPlan: PlanTierX.fromKey((map['minPlan'] ?? 'local').toString()),
      priority: map['priority'] is int
          ? map['priority'] as int
          : int.tryParse('${map['priority'] ?? 999}') ?? 999,
      hasLiveAnalysis: map['hasLiveAnalysis'] == true,
      active: map['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'emoji': emoji,
        'minPlan': minPlan.planKey,
        'priority': priority,
        'hasLiveAnalysis': hasLiveAnalysis,
        'active': active,
      };
}

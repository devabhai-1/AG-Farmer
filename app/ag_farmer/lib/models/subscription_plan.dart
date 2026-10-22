enum PlanTier { free, local, advanced, allCrops, superPro, distributor }

extension PlanTierX on PlanTier {
  String get planKey {
    switch (this) {
      case PlanTier.free:
        return 'free';
      case PlanTier.local:
        return 'local';
      case PlanTier.advanced:
        return 'advanced';
      case PlanTier.allCrops:
        return 'all';
      case PlanTier.superPro:
        return 'super';
      case PlanTier.distributor:
        return 'distributor';
    }
  }

  /// ₹2650 and ₹13500 get the full AG Live mic.
  bool get hasSuperLiveMic =>
      this == PlanTier.superPro || this == PlanTier.distributor;

  int get rank {
    switch (this) {
      case PlanTier.free:
        return 0;
      case PlanTier.local:
        return 1;
      case PlanTier.advanced:
        return 2;
      case PlanTier.allCrops:
        return 3;
      case PlanTier.superPro:
        return 4;
      case PlanTier.distributor:
        return 5;
    }
  }

  int get chatDailyLimit {
    switch (this) {
      case PlanTier.free:
      case PlanTier.local:
        return 80;
      case PlanTier.advanced:
        return 104;
      case PlanTier.allCrops:
        return 166;
      case PlanTier.superPro:
        return 330;
      case PlanTier.distributor:
        return 3300;
    }
  }

  int get strongChatDailyLimit {
    switch (this) {
      case PlanTier.free:
      case PlanTier.local:
        return 0;
      case PlanTier.advanced:
        return 4;
      case PlanTier.allCrops:
        return 6;
      case PlanTier.superPro:
        return 30;
      case PlanTier.distributor:
        return 300;
    }
  }

  /// Deep research allowance. ₹299 is per month; higher plans are per day.
  int get deepResearchLimit {
    switch (this) {
      case PlanTier.free:
      case PlanTier.local:
        return 0;
      case PlanTier.advanced:
        return 8;
      case PlanTier.allCrops:
        return 2;
      case PlanTier.superPro:
        return 8;
      case PlanTier.distributor:
        return 80;
    }
  }

  String get deepResearchPeriod {
    switch (this) {
      case PlanTier.advanced:
        return 'month';
      default:
        return 'day';
    }
  }

  int get deepResearchDailyLimit => deepResearchLimit;

  static PlanTier fromKey(String? key) {
    switch (key) {
      case 'local':
        return PlanTier.local;
      case 'advanced':
        return PlanTier.advanced;
      case 'all':
      case 'allCrops':
        return PlanTier.allCrops;
      case 'super':
      case 'superPro':
      case 'superpro':
      case 'superpremium':
      case 'super_premium':
        return PlanTier.superPro;
      case 'distributor':
      case 'distributorPro':
      case 'distributorpro':
      case 'dealer':
        return PlanTier.distributor;
      default:
        return PlanTier.free;
    }
  }
}

class SubscriptionPlan {
  final PlanTier tier;
  final int priceInr;
  final int saleInr;
  final String id;
  final String nameEn;
  final String nameHi;
  final bool active;

  const SubscriptionPlan({
    required this.tier,
    required this.priceInr,
    required this.id,
    this.saleInr = 0,
    this.nameEn = '',
    this.nameHi = '',
    this.active = true,
  });

  int get rank => tier.rank;

  /// Razorpay + on-screen pay amount. saleInr is a cut under the fixed MRP.
  int get payInr =>
      saleInr > 0 && saleInr < priceInr ? saleInr : priceInr;

  bool get hasSale => saleInr > 0 && saleInr < priceInr;

  bool includes(PlanTier required) => rank >= required.rank;

  factory SubscriptionPlan.fromMap(String id, Map<dynamic, dynamic> map) {
    final tierKey = (map['tier'] ?? map['id'] ?? id).toString();
    return SubscriptionPlan(
      id: (map['id'] ?? id).toString(),
      tier: PlanTierX.fromKey(tierKey == 'allCrops' ? 'all' : tierKey),
      priceInr: map['priceInr'] is int
          ? map['priceInr'] as int
          : int.tryParse('${map['priceInr'] ?? 0}') ?? 0,
      saleInr: map['saleInr'] is int
          ? map['saleInr'] as int
          : int.tryParse('${map['saleInr'] ?? 0}') ?? 0,
      nameEn: (map['nameEn'] ?? id).toString(),
      nameHi: (map['nameHi'] ?? map['nameEn'] ?? id).toString(),
      active: map['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tier': tier == PlanTier.distributor
            ? 'distributor'
            : tier == PlanTier.allCrops
                ? 'allCrops'
                : tier == PlanTier.superPro
                    ? 'superPro'
                    : tier.name,
        'priceInr': priceInr,
        'saleInr': saleInr,
        'rank': rank,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'active': active,
      };
}

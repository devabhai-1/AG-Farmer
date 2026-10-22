/// Checkout period for subscription plans (matches server `quote()`).
enum BillingCycle {
  monthly,
  fourMonth,
  yearly;

  /// Value sent as `cycle` on `billing.checkout.create`.
  String get apiValue {
    switch (this) {
      case BillingCycle.monthly:
        return 'monthly';
      case BillingCycle.fourMonth:
        return 'four_month';
      case BillingCycle.yearly:
        return 'yearly';
    }
  }

  /// Payable amount from a monthly base (payInr / MRP).
  int priceInr(int monthlyBase) {
    final base = monthlyBase < 0 ? 0 : monthlyBase;
    switch (this) {
      case BillingCycle.monthly:
        return base;
      case BillingCycle.fourMonth:
        return ((base * 4 * 90) / 100).round();
      case BillingCycle.yearly:
        return ((base * 12 * 75) / 100).round();
    }
  }

  /// Strike-through compare-at (full multi-month without discount).
  int compareAtInr(int monthlyBase) {
    final base = monthlyBase < 0 ? 0 : monthlyBase;
    switch (this) {
      case BillingCycle.monthly:
        return base;
      case BillingCycle.fourMonth:
        return base * 4;
      case BillingCycle.yearly:
        return base * 12;
    }
  }
}

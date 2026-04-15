import '../../data/staff_loyalty_api.dart';

class StaffAccrualPreview {
  final int added;
  final String label;
  final double discountPercent;
  final double discountAmount;
  final double payableAmount;
  final double appliedPercent;

  StaffAccrualPreview({
    required this.added,
    required this.label,
    required this.discountPercent,
    required this.discountAmount,
    required this.payableAmount,
    required this.appliedPercent,
  });
}

class StaffSpendPreview {
  final int available;
  final int recommendedRedeemPoints;
  final int actualRedeemPoints;
  final double maxRedeemRub;
  final double payableAmount;
  final double redeemRate;
  final double maxRedeemPercent;

  StaffSpendPreview({
    required this.available,
    required this.recommendedRedeemPoints,
    required this.actualRedeemPoints,
    required this.maxRedeemRub,
    required this.payableAmount,
    required this.redeemRate,
    required this.maxRedeemPercent,
  });
}

class StaffLoyaltyCalculator {
  static double _cashbackPercentBySpent(
    double totalSpent,
    List<Map<String, dynamic>> levels,
    int basePercent,
  ) {
    var current = basePercent.toDouble();

    final sorted = [...levels]
      ..sort(
        (a, b) => ((a['spent_required'] as num?)?.toDouble() ?? 0).compareTo(
          (b['spent_required'] as num?)?.toDouble() ?? 0,
        ),
      );

    for (final lvl in sorted) {
      final spentRequired = (lvl['spent_required'] as num?)?.toDouble() ?? 0;
      final percent = (lvl['cashback_percent'] as num?)?.toDouble() ?? current;

      if (totalSpent >= spentRequired) {
        current = percent;
      } else {
        break;
      }
    }

    return current;
  }

  static Map<String, dynamic> _discountByVisits(
    int visits,
    List<Map<String, dynamic>> levels,
  ) {
    if (levels.isEmpty) {
      return {
        'name': '',
        'purchases_required': 0,
        'discount_percent': 0.0,
      };
    }

    final sorted = [...levels]
      ..sort(
        (a, b) => ((a['purchases_required'] as num?)?.toInt() ?? 0).compareTo(
          (b['purchases_required'] as num?)?.toInt() ?? 0,
        ),
      );

    Map<String, dynamic> current = sorted.first;

    for (final lvl in sorted) {
      final required = (lvl['purchases_required'] as num?)?.toInt() ?? 0;
      if (visits >= required) {
        current = lvl;
      } else {
        break;
      }
    }

    return current;
  }

  static StaffAccrualPreview previewAccrual({
    required StaffLoyaltyConfig config,
    required double amount,
  }) {
    final mode = config.mode;
    final accrualType = config.accrualType;

    double discountPercent = 0;
    double discountAmount = 0;
    double payable = amount;
    double appliedPercent = 0;
    int added = 0;
    String label = '';

    if (mode == 'discount_levels') {
      final lvl = _discountByVisits(config.clientVisits, config.levels);
      discountPercent = ((lvl['discount_percent'] as num?)?.toDouble() ?? 0);
      discountAmount = amount * discountPercent / 100.0;
      payable = amount - discountAmount;
      if (payable < 0) payable = 0;

      if (config.pointsEnabledInDiscountMode) {
        if (accrualType == 'per_purchase') {
          added = config.fixedPointsPerPurchase;
          label = 'Фиксированные баллы за покупку';
        } else {
          added = ((payable / 100.0) * config.pointsPer100Rub).floor();
          label = '${config.pointsPer100Rub} баллов за 100 ₽';
        }
      } else {
        added = 0;
        label = 'Баллы в режиме скидок отключены';
      }

      return StaffAccrualPreview(
        added: added,
        label: label,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        payableAmount: payable,
        appliedPercent: 0,
      );
    }

    if (mode == 'cashback') {
      final percent = _cashbackPercentBySpent(
        config.clientTotalSpent + amount,
        config.cashbackLevels,
        config.cashbackPercent,
      );
      appliedPercent = percent;
      added = ((amount / 100.0) * percent).round();
      label = 'Кэшбэк ${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%';
      return StaffAccrualPreview(
        added: added,
        label: label,
        discountPercent: 0,
        discountAmount: 0,
        payableAmount: amount,
        appliedPercent: percent,
      );
    }

    if (accrualType == 'per_purchase') {
      added = config.fixedPointsPerPurchase;
      label = 'Фиксированные баллы за покупку';
    } else {
      added = ((amount / 100.0) * config.pointsPer100Rub).floor();
      label = '${config.pointsPer100Rub} баллов за 100 ₽';
    }

    return StaffAccrualPreview(
      added: added,
      label: label,
      discountPercent: 0,
      discountAmount: 0,
      payableAmount: amount,
      appliedPercent: 0,
    );
  }

  static StaffSpendPreview previewSpend({
    required StaffLoyaltyConfig config,
    required double amount,
    int? manualRedeemPoints,
  }) {
    final available = config.clientBalance;
    final redeemRate = config.mode == 'cashback' ? 1.0 : config.redeemRate;
    final maxRedeemRub = amount * (config.maxRedeemPercent / 100.0);

    int recommendedPoints = (maxRedeemRub / redeemRate).floor();
    if (recommendedPoints > available) {
      recommendedPoints = available;
    }
    if (recommendedPoints < 0) {
      recommendedPoints = 0;
    }

    var actualPoints = manualRedeemPoints ?? recommendedPoints;
    if (actualPoints > available) {
      actualPoints = available;
    }
    if (actualPoints < 0) {
      actualPoints = 0;
    }

    final redeemRub = actualPoints * redeemRate;
    final payable = (amount - redeemRub) < 0 ? 0.0 : (amount - redeemRub);

    return StaffSpendPreview(
      available: available,
      recommendedRedeemPoints: recommendedPoints,
      actualRedeemPoints: actualPoints,
      maxRedeemRub: maxRedeemRub,
      payableAmount: payable,
      redeemRate: redeemRate,
      maxRedeemPercent: config.maxRedeemPercent.toDouble(),
    );
  }
}
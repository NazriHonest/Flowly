enum AllowancePeriodType { monthly, weekly, daily }

enum AllowanceStatus { onTrack, nearLimit, limitReached, overLimit }

class SpendingAllowanceConfig {
  const SpendingAllowanceConfig({
    this.id,
    required this.monthStart,
    required this.monthlyLimitMinor,
    required this.weeklyEnabled,
    this.weeklyLimitMinor,
    required this.dailyEnabled,
    this.dailyLimitMinor,
    required this.repeatsMonthly,
    this.notes,
  });

  final int? id;
  final DateTime monthStart;
  final int monthlyLimitMinor;
  final bool weeklyEnabled;
  final int? weeklyLimitMinor;
  final bool dailyEnabled;
  final int? dailyLimitMinor;
  final bool repeatsMonthly;
  final String? notes;

  int? limitFor(AllowancePeriodType type) => switch (type) {
    AllowancePeriodType.monthly => monthlyLimitMinor,
    AllowancePeriodType.weekly => weeklyEnabled ? weeklyLimitMinor : null,
    AllowancePeriodType.daily => dailyEnabled ? dailyLimitMinor : null,
  };
}

class AllowancePeriod {
  const AllowancePeriod(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class SpendingAllowanceSummary {
  const SpendingAllowanceSummary({
    required this.type,
    required this.period,
    required this.limitMinor,
    required this.spentMinor,
  });
  final AllowancePeriodType type;
  final AllowancePeriod period;
  final int limitMinor;
  final int spentMinor;
  int get remainingMinor => limitMinor - spentMinor;
  double get usage => limitMinor <= 0 ? 0 : spentMinor / limitMinor;
  AllowanceStatus get status {
    if (spentMinor > limitMinor) return AllowanceStatus.overLimit;
    if (spentMinor == limitMinor) return AllowanceStatus.limitReached;
    if (usage >= .8) return AllowanceStatus.nearLimit;
    return AllowanceStatus.onTrack;
  }
}

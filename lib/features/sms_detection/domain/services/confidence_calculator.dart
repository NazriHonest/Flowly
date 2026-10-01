class ConfidenceCalculator {
  const ConfidenceCalculator();
  static const automaticallyConfirm = .90;
  static const needsReview = .70;

  double score({
    required bool provider,
    required bool type,
    required bool amount,
    required bool currency,
    bool reference = false,
    bool merchant = false,
    bool validTimestamp = true,
  }) {
    var score = 0.0;
    if (provider) score += .20;
    if (type) score += .24;
    if (amount) score += .28;
    if (currency) score += .12;
    if (reference) score += .08;
    if (merchant) score += .04;
    if (validTimestamp) score += .04;
    return score.clamp(0, 1);
  }

  DetectionDisposition disposition(double confidence) =>
      confidence >= automaticallyConfirm
      ? DetectionDisposition.confirmed
      : confidence >= needsReview
      ? DetectionDisposition.needsReview
      : DetectionDisposition.rejected;
}

enum DetectionDisposition { confirmed, needsReview, rejected }

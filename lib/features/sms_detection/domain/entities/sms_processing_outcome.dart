enum SmsProcessingDisposition {
  persisted,
  duplicate,
  transferPending,
  mappingMissing,
  providerDisabled,
  unsupported,
  retryableFailure,
}

class SmsProcessingOutcome {
  const SmsProcessingOutcome(this.disposition);

  final SmsProcessingDisposition disposition;

  bool get advancesCursor =>
      disposition != SmsProcessingDisposition.retryableFailure;

  bool get databaseChanged =>
      disposition == SmsProcessingDisposition.persisted ||
      disposition == SmsProcessingDisposition.transferPending;
}

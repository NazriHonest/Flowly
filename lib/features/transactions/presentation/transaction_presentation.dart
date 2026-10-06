import 'package:flutter/material.dart';

import '../domain/entities/transaction.dart';

extension TransactionSourcePresentation on TransactionSource {
  String get displayLabel => switch (this) {
    TransactionSource.smsImport => 'Imported',
    TransactionSource.smsLive => 'Auto',
    TransactionSource.manual => 'Manual',
    TransactionSource.recurring => 'Recurring',
  };
}

String formatTransactionDate(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
}

int compareTransactionsByCreatedAtDescending(
  Transaction first,
  Transaction second,
) {
  final firstCreatedAt = first.createdAt;
  final secondCreatedAt = second.createdAt;

  if (firstCreatedAt != null && secondCreatedAt != null) {
    final createdAtOrder = secondCreatedAt.compareTo(firstCreatedAt);
    if (createdAtOrder != 0) return createdAtOrder;
  } else if (firstCreatedAt == null && secondCreatedAt != null) {
    return 1;
  } else if (firstCreatedAt != null && secondCreatedAt == null) {
    return -1;
  }

  return (second.id ?? -1).compareTo(first.id ?? -1);
}

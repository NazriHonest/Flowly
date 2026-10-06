import '../../../core/database/app_database.dart';
import '../../categorization/domain/services/categorization_service.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../domain/entities/transaction_candidate.dart';
import '../domain/entities/sms_transfer_observation.dart';
import '../domain/services/confidence_calculator.dart';
import '../domain/services/financial_sms_pipeline.dart';
import 'historical_sms_bridge.dart';
import '../../notifications/data/local_notification_service.dart';

class HistoricalImportItem {
  const HistoricalImportItem({
    required this.transaction,
    required this.fingerprint,
    required this.duplicate,
    required this.provider,
    required this.currency,
    required this.accountName,
    this.linkedAccountName,
    this.transferCandidate,
    this.providerId,
    this.linkedAccountId,
    this.smsReceivedAt,
  });
  final Transaction transaction;
  final String fingerprint;
  final bool duplicate;
  final String provider;
  final String currency;

  /// Normalized display-only account label; never contains SMS sender data.
  final String accountName;
  final String? linkedAccountName;
  final TransactionCandidate? transferCandidate;
  final int? providerId;
  final int? linkedAccountId;
  final DateTime? smsReceivedAt;
}

class HistoricalImportSummary {
  const HistoricalImportSummary({
    required this.scanned,
    required this.detected,
    required this.duplicates,
    required this.confirmed,
    required this.needsReview,
    required this.ignored,
    required this.rejected,
    required this.evcPlus,
    required this.jeeb,
    required this.deeqtoon,
    required this.agroBank,
    required this.generic,
    required this.items,
  });
  final int scanned,
      detected,
      duplicates,
      confirmed,
      needsReview,
      ignored,
      rejected,
      evcPlus,
      jeeb,
      deeqtoon,
      agroBank,
      generic;
  final List<HistoricalImportItem> items;
}

/// Reuses the live pipeline; raw rows are converted immediately and do not
/// escape [scan].
class HistoricalImportProcessor {
  HistoricalImportProcessor({
    required this._pipeline,
    required this._database,
    this._categorization = const CategorizationService(),
  });
  final FinancialSmsPipeline _pipeline;
  final AppDatabase _database;
  final CategorizationService _categorization;

  Future<HistoricalImportSummary> scan(List<HistoricalSmsMessage> rows) async {
    final accounts = await _database.accounts();
    final providers = await _database.smsProviders();
    final mappings = await _database.providerAccountMappings();
    final rules = await _database.merchantRules();
    final merchantRules = rules
        .map(
          (r) => MerchantRule(
            r['normalized_merchant'] as String,
            r['category'] as String,
          ),
        )
        .toList();
    var detected = 0,
        duplicates = 0,
        confirmed = 0,
        review = 0,
        ignored = 0,
        rejected = 0,
        evcPlus = 0,
        jeeb = 0,
        deeqtoon = 0,
        agroBank = 0,
        generic = 0;
    final items = <HistoricalImportItem>[];
    for (final row in rows) {
      final result = _pipeline.process(
        sender: row.sender,
        message: row.body,
        receivedAt: row.receivedAt,
      );
      if (result == null ||
          result.disposition == DetectionDisposition.rejected) {
        rejected++;
        ignored++;
        continue;
      }
      final candidate = result.candidate;
      final normalizedSender = row.sender.trim().toLowerCase();
      final parsedProvider = candidate.provider.trim().toLowerCase();
      final provider = providers.where((value) {
        final identity = value.name.trim().toLowerCase();
        final aliases = value.senderAliases
            .map((alias) => alias.trim().toLowerCase())
            .toSet();
        return value.enabled &&
            (identity == normalizedSender ||
                aliases.contains(normalizedSender) ||
                (parsedProvider != 'generic' && identity == parsedProvider));
      }).firstOrNull;
      final mappedAccountId = provider == null
          ? null
          : mappings
                .where((mapping) => mapping.providerId == provider.id)
                .map((mapping) => mapping.accountId)
                .firstOrNull;
      final accountId = accounts.any((account) => account.id == mappedAccountId)
          ? mappedAccountId
          : null;
      if (provider == null || accountId == null) {
        ignored++;
        continue;
      }
      detected++;
      // Provider buckets describe the same recognized set as [detected].
      // Count only after explicit account mapping succeeds so the totals are
      // mutually exclusive and internally consistent.
      switch (candidate.provider.trim().toLowerCase()) {
        case 'evc plus':
          evcPlus++;
          break;
        case 'jeeb':
          jeeb++;
          break;
        case 'deeqtoon':
          deeqtoon++;
          break;
        case 'agrobank':
          agroBank++;
          break;
        default:
          generic++;
          break;
      }
      final merchant = candidate.merchant ?? candidate.provider;
      final category =
          candidate.categorySuggestion ??
          _categorization.suggest(
            merchant: merchant,
            merchantRules: merchantRules,
            keywordRules: const [],
          );
      final mapping = mappings.firstWhere(
        (value) =>
            value.providerId == provider.id && value.accountId == accountId,
      );
      final internalTransfer =
          candidate.semantics == CandidateSemantics.internalTransfer;
      final status = internalTransfer && mapping.linkedAccountId == null
          ? ReviewStatus.needsReview
          : result.disposition == DetectionDisposition.confirmed
          ? ReviewStatus.confirmed
          : ReviewStatus.needsReview;
      final duplicate = await _database.hasFingerprint(result.fingerprint);
      if (duplicate) duplicates++;
      // A duplicate is already processed and cannot be actionable review work.
      if (!duplicate && status == ReviewStatus.confirmed) {
        confirmed++;
      } else if (!duplicate) {
        review++;
      }
      items.add(
        HistoricalImportItem(
          fingerprint: result.fingerprint,
          duplicate: duplicate,
          provider: candidate.provider,
          currency: candidate.currency,
          accountName: accounts
              .firstWhere((account) => account.id == accountId)
              .name,
          linkedAccountName: mapping.linkedAccountId == null
              ? null
              : accounts
                    .where((account) => account.id == mapping.linkedAccountId)
                    .firstOrNull
                    ?.name,
          transferCandidate: internalTransfer ? candidate : null,
          providerId: internalTransfer ? provider.id : null,
          linkedAccountId: internalTransfer ? mapping.linkedAccountId : null,
          smsReceivedAt: internalTransfer ? row.receivedAt : null,
          transaction: Transaction(
            amountMinor: candidate.amountMinor,
            type: internalTransfer
                ? TransactionType.transfer
                : candidate.type == CandidateType.income
                ? TransactionType.income
                : TransactionType.expense,
            title: merchant,
            category: category,
            accountId: accountId,
            destinationAccountId:
                internalTransfer &&
                    candidate.transferDirection ==
                        TransferObservationDirection.outgoing
                ? mapping.linkedAccountId
                : null,
            date: candidate.transactionDate,
            source: TransactionSource.smsImport,
            status: status,
            providerTransactionAt: candidate.providerTransactionAt,
            smsReceivedAt: row.receivedAt,
          ),
        ),
      );
    }
    return HistoricalImportSummary(
      scanned: rows.length,
      detected: detected,
      duplicates: duplicates,
      confirmed: confirmed,
      needsReview: review,
      ignored: ignored,
      rejected: rejected,
      evcPlus: evcPlus,
      jeeb: jeeb,
      deeqtoon: deeqtoon,
      agroBank: agroBank,
      generic: generic,
      items: items,
    );
  }

  Future<int> commit(Iterable<HistoricalImportItem> items) async {
    var saved = 0;
    for (final item in items) {
      if (item.duplicate) continue;
      final transferCandidate = item.transferCandidate;
      if (transferCandidate != null) {
        final outcome = await _database.saveInternalTransferObservation(
          candidate: transferCandidate,
          providerId: item.providerId!,
          mappedAccountId: item.transaction.accountId,
          linkedAccountId: item.linkedAccountId,
          source: TransactionSource.smsImport,
          smsReceivedAt: item.smsReceivedAt!,
          fingerprint: item.fingerprint,
        );
        if (outcome != SmsTransferSaveOutcome.duplicate) saved++;
      } else if (await _database.saveDetectedTransaction(
        item.transaction,
        item.fingerprint,
      )) {
        saved++;
      }
    }
    if (saved > 0) {
      await _database.createNotification(
        'Historical import complete',
        '$saved transactions were imported.',
      );
      await LocalNotificationService.instance.show(
        event: 'historicalImport',
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: 'Historical import complete',
        body: '$saved transactions were imported.',
      );
    }
    return saved;
  }
}

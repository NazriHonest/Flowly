import '../../../core/database/app_database.dart';
import '../../categorization/domain/services/categorization_service.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../domain/entities/transaction_candidate.dart';
import '../domain/entities/sms_provider.dart';
import '../domain/services/confidence_calculator.dart';
import '../domain/services/financial_sms_pipeline.dart';
import 'sms_event_bridge.dart';
import '../../notifications/data/local_notification_service.dart';

/// Constructs the normalized transaction persisted for an SMS broadcast.
/// Keeping the source assignment here makes it independently regression-testable.
Transaction createLiveSmsTransaction({
  required TransactionCandidate candidate,
  required String merchant,
  required String category,
  required int accountId,
  required ReviewStatus status,
  required DateTime smsReceivedAt,
}) => Transaction(
  amountMinor: candidate.amountMinor,
  type: candidate.type == CandidateType.income
      ? TransactionType.income
      : TransactionType.expense,
  title: merchant,
  category: category,
  accountId: accountId,
  date: candidate.transactionDate,
  source: TransactionSource.smsLive,
  status: status,
  providerTransactionAt: candidate.providerTransactionAt,
  smsReceivedAt: smsReceivedAt,
);

/// Converts a transient native SMS event into a normalized stored transaction.
/// It deliberately drops the raw body immediately after [process] returns.
class AutomaticTransactionProcessor {
  AutomaticTransactionProcessor({
    required this._pipeline,
    required this._database,
    this._categorization = const CategorizationService(),
  });
  final FinancialSmsPipeline _pipeline;
  final AppDatabase _database;
  final CategorizationService _categorization;

  Future<bool> handle(SmsEvent event) async {
    final result = _pipeline.process(
      sender: event.sender,
      message: event.body,
      receivedAt: event.receivedAt,
    );
    if (result == null ||
        result.disposition == DetectionDisposition.rejected ||
        result.candidate.type == CandidateType.transfer) {
      return false;
    }
    final accounts = await _database.accounts();
    if (accounts.isEmpty) return false;
    // Provider configuration is optional. When the sender has been explicitly
    // configured, honour its enabled flag and account mapping rather than
    // silently assigning the transaction to the first account.
    final providers = await _database.smsProviders();
    final normalizedSender = event.sender.trim().toLowerCase();
    final parsedProvider = result.candidate.provider.trim().toLowerCase();
    final configuredProvider = providers
        .where((provider) {
          final identity = provider.name.trim().toLowerCase();
          final aliases = provider.senderAliases
              .map((alias) => alias.trim().toLowerCase())
              .toSet();
          final senderMatches = identity == normalizedSender ||
              aliases.contains(normalizedSender);
          final parserMatches = parsedProvider != 'generic' &&
              identity == parsedProvider;
          return senderMatches || parserMatches;
        })
        .firstOrNull;
    if (configuredProvider != null && !configuredProvider.enabled) return false;
    final mappings = configuredProvider == null
        ? const <ProviderAccountMapping>[]
        : (await _database.providerAccountMappings())
            .where((mapping) => mapping.providerId == configuredProvider.id)
            .toList();
    final mappedAccountId = mappings.isEmpty ? null : mappings.first.accountId;
    final accountId = accounts.any((account) => account.id == mappedAccountId)
        ? mappedAccountId
        : null;
    // Never attribute an unknown/unmapped sender to an arbitrary account.
    // The provider must be mapped explicitly before its messages are stored.
    if (configuredProvider == null || accountId == null) {
      await _database.createNotification(
        'SMS provider needs mapping',
        'Map ${event.sender} to an account before importing its transactions.',
      );
      return false;
    }
    final candidate = result.candidate;
    final merchant = candidate.merchant ?? candidate.provider;
    final storedRules = await _database.merchantRules();
    final category =
        candidate.categorySuggestion ??
        _categorization.suggest(
          merchant: merchant,
          merchantRules: storedRules.map(
            (rule) => MerchantRule(
              rule['normalized_merchant'] as String,
              rule['category'] as String,
            ),
          ),
          keywordRules: const [],
        );
    final status = result.disposition == DetectionDisposition.confirmed
        ? ReviewStatus.confirmed
        : ReviewStatus.needsReview;
    final saved = await _database.saveDetectedTransaction(
      createLiveSmsTransaction(
        candidate: candidate,
        merchant: merchant,
        category: category,
        accountId: accountId,
        status: status,
        smsReceivedAt: event.receivedAt,
      ),
      result.fingerprint,
    );
    if (saved && status == ReviewStatus.needsReview) {
      await _database.createNotification(
        'Transaction needs review',
        'A detected transaction from $merchant needs your confirmation.',
      );
      await LocalNotificationService.instance.show(
        event: 'needsReview',
        id: result.fingerprint.hashCode,
        title: 'Transaction needs review',
        body: 'A detected transaction from $merchant needs your confirmation.',
      );
    }
    return saved;
  }
}

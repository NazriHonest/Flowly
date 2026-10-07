import '../../../core/database/app_database.dart';

import 'dart:developer' as developer;

import '../../categorization/domain/services/categorization_service.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../domain/entities/transaction_candidate.dart';
import '../domain/entities/sms_processing_outcome.dart';
import '../domain/entities/sms_provider.dart';
import '../domain/entities/sms_transfer_observation.dart';
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
/// It deliberately drops the raw body immediately after [handle] returns.
class AutomaticTransactionProcessor {
  AutomaticTransactionProcessor({
    required this._pipeline,
    required this._database,
    this._categorization = const CategorizationService(),
  });
  final FinancialSmsPipeline _pipeline;
  final AppDatabase _database;
  final CategorizationService _categorization;

  Future<SmsProcessingOutcome> handle(SmsEvent event) async {
    try {
      developer.log('dart_event_received', name: 'FlowlySMS');
      final result = _pipeline.process(
        sender: event.sender,
        message: event.body,
        receivedAt: event.receivedAt,
      );
      if (result == null ||
          result.disposition == DetectionDisposition.rejected) {
        developer.log('normalized_failed', name: 'FlowlySMS');
        return const SmsProcessingOutcome(
          SmsProcessingDisposition.unsupported,
        );
      }
      developer.log('normalized_success', name: 'FlowlySMS');
      developer.log(
        'provider_detected=${result.candidate.provider.toUpperCase().replaceAll(' ', '_')}',
        name: 'FlowlySMS',
      );
      final accounts = await _database.accounts();
      if (accounts.isEmpty) {
        developer.log('mapping_found=false', name: 'FlowlySMS');
        return const SmsProcessingOutcome(
          SmsProcessingDisposition.mappingMissing,
        );
      }
      // Provider configuration is optional. When the sender has been
      // configured, honour its enabled flag and mapping.
      final providers = await _database.smsProviders();
      developer.log('mapping_state_ready', name: 'FlowlySMS');
      final normalizedSender = event.sender.trim().toLowerCase();
      final parsedProvider = result.candidate.provider.trim().toLowerCase();
      final configuredProvider = providers.where((provider) {
        final identity = provider.name.trim().toLowerCase();
        final aliases = provider.senderAliases
            .map((alias) => alias.trim().toLowerCase())
            .toSet();
        final senderMatches =
            identity == normalizedSender || aliases.contains(normalizedSender);
        final parserMatches =
            parsedProvider != 'generic' && identity == parsedProvider;
        return senderMatches || parserMatches;
      }).firstOrNull;
      if (configuredProvider != null && !configuredProvider.enabled) {
        developer.log('provider_enabled=false', name: 'FlowlySMS');
        return const SmsProcessingOutcome(
          SmsProcessingDisposition.providerDisabled,
        );
      }
      final mappings = configuredProvider == null
          ? const <ProviderAccountMapping>[]
          : (await _database.providerAccountMappings())
                .where(
                  (mapping) => mapping.providerId == configuredProvider.id,
                )
                .toList();
      final mappedAccountId = mappings.isEmpty
          ? null
          : mappings.first.accountId;
      final accountId = accounts.any(
        (account) => account.id == mappedAccountId,
      )
          ? mappedAccountId
          : null;
      // Never attribute an unknown sender to an arbitrary account.
      if (configuredProvider == null || accountId == null) {
        developer.log('mapping_found=false', name: 'FlowlySMS');
        developer.log('mapping_missing', name: 'FlowlySMS');
        await _bestEffort(
          () => _database.createNotification(
            'SMS provider needs mapping',
            'Configure this SMS provider before importing its transactions.',
          ),
        );
        return const SmsProcessingOutcome(
          SmsProcessingDisposition.mappingMissing,
        );
      }
      developer.log('mapping_found=true', name: 'FlowlySMS');
      final candidate = result.candidate;
      if (candidate.semantics == CandidateSemantics.internalTransfer) {
        final mapping = mappings.first;
        final outcome = await _database.saveInternalTransferObservation(
          candidate: candidate,
          providerId: configuredProvider.id!,
          mappedAccountId: mapping.accountId!,
          linkedAccountId: mapping.linkedAccountId,
          source: TransactionSource.smsLive,
          smsReceivedAt: event.receivedAt,
          fingerprint: result.fingerprint,
        );
        final saved = outcome != SmsTransferSaveOutcome.duplicate;
        developer.log(
          'transfer_observation=${outcome.name}',
          name: 'FlowlySMS',
        );
        developer.log('persistence_success=$saved', name: 'FlowlySMS');
        if (outcome == SmsTransferSaveOutcome.pending) {
          await _bestEffort(
            () => _database.createNotification(
              'Possible account transfer',
              'Choose the linked owned account to confirm a detected transfer.',
            ),
          );
        }
        if (outcome == SmsTransferSaveOutcome.duplicate) {
          developer.log('duplicate', name: 'FlowlySMS');
          return const SmsProcessingOutcome(
            SmsProcessingDisposition.duplicate,
          );
        }
        if (outcome == SmsTransferSaveOutcome.pending) {
          return const SmsProcessingOutcome(
            SmsProcessingDisposition.transferPending,
          );
        }
        return const SmsProcessingOutcome(SmsProcessingDisposition.persisted);
      }
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
      developer.log('persistence_success=$saved', name: 'FlowlySMS');
      if (!saved) {
        developer.log('duplicate', name: 'FlowlySMS');
        return const SmsProcessingOutcome(SmsProcessingDisposition.duplicate);
      }
      if (status == ReviewStatus.needsReview) {
        await _bestEffort(
          () => _database.createNotification(
            'Transaction needs review',
            'A detected transaction from $merchant needs your confirmation.',
          ),
        );
        await _bestEffort(
          () => LocalNotificationService.instance.show(
            event: 'needsReview',
            id: result.fingerprint.hashCode,
            title: 'Transaction needs review',
            body:
                'A detected transaction from $merchant needs your confirmation.',
          ),
        );
      }
      return const SmsProcessingOutcome(SmsProcessingDisposition.persisted);
    } catch (_) {
      developer.log('retryable_failure', name: 'FlowlySMS');
      return const SmsProcessingOutcome(
        SmsProcessingDisposition.retryableFailure,
      );
    }
  }
}

Future<void> _bestEffort(Future<void> Function() operation) async {
  try {
    await operation();
  } catch (_) {
    developer.log('notification_failed', name: 'FlowlySMS');
  }
}

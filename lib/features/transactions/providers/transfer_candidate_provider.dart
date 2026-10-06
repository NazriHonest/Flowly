import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/transfer_candidate.dart';
import '../../sms_detection/domain/entities/sms_transfer_observation.dart';

class TransferCandidateController
    extends StateNotifier<AsyncValue<List<TransferCandidate>>> {
  TransferCandidateController() : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await AppDatabase.instance.transferCandidates());
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> reject(int candidateId) async {
    await AppDatabase.instance.rejectTransferCandidate(candidateId);
    await refresh();
  }
}

final transferCandidateListProvider =
    StateNotifierProvider<
      TransferCandidateController,
      AsyncValue<List<TransferCandidate>>
    >((_) => TransferCandidateController());

class PendingSmsTransferController
    extends StateNotifier<AsyncValue<List<SmsTransferObservation>>> {
  PendingSmsTransferController() : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(
        await AppDatabase.instance.pendingSmsTransferObservations(),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> resolve(int observationId, int counterpartAccountId) async {
    await AppDatabase.instance.resolvePendingSmsTransfer(
      observationId,
      counterpartAccountId,
    );
    await refresh();
  }

  Future<void> reject(int observationId) async {
    await AppDatabase.instance.rejectPendingSmsTransfer(observationId);
    await refresh();
  }
}

final pendingSmsTransferListProvider =
    StateNotifierProvider<
      PendingSmsTransferController,
      AsyncValue<List<SmsTransferObservation>>
    >((_) => PendingSmsTransferController());

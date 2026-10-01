import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/transfer_candidate.dart';

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

final transferCandidateListProvider = StateNotifierProvider<
  TransferCandidateController,
  AsyncValue<List<TransferCandidate>>
>((_) => TransferCandidateController());

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/detail/data/detail_repository.dart';

enum SyncStatus { idle, loading, success, error }

class SyncState {
  const SyncState({this.status = SyncStatus.idle, this.message});

  final SyncStatus status;
  final String? message;

  bool get isLoading => status == SyncStatus.loading;
}

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> sync({String mode = 'new'}) async {
    if (state.isLoading) return;
    state = const SyncState(status: SyncStatus.loading);

    try {
      final secret = dotenv.env['SYNC_SECRET'] ?? '';
      final repo = ref.read(_syncRepoProvider);
      final result = await repo.triggerSync(mode: mode, secret: secret);

      if (result == null) {
        state = const SyncState(
          status: SyncStatus.error,
          message: 'Gagal terhubung ke server sync',
        );
        return;
      }

      state = SyncState(status: SyncStatus.success, message: result.message);
    } catch (e) {
      state = SyncState(status: SyncStatus.error, message: e.toString());
    }
  }

  void reset() => state = const SyncState();
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

final _syncRepoProvider = Provider<DetailRepository>(
  (_) => const DetailRepository(),
);

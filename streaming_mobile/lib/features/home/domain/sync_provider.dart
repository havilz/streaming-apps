import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/domain/domain.dart';

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
      // Force bypass cache/cooldown for manual pull-to-refresh
      await ClientSyncService.markGlobalSynced(); // Force reset cooldown
      final tempFile = File('${Directory.systemTemp.path}/last_sync_time.txt');
      if (await tempFile.exists()) {
        await tempFile.delete(); // Delete file to bypass cooldown
      }

      await ClientSyncService.syncGlobal();
      await ref.read(homeProvider.notifier).reload();

      state = const SyncState(
        status: SyncStatus.success,
        message: 'Sinkronisasi katalog berhasil',
      );
    } catch (e) {
      state = SyncState(status: SyncStatus.error, message: e.toString());
    }
  }

  void reset() => state = const SyncState();
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

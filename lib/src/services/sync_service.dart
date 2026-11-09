import '../models/local_change.dart';
import '../models/remote_conflict.dart';
import '../models/sync_info.dart';
import 'remote_provider.dart';
import 'core/store.dart';

class SyncEngine {
  SyncEngine(this.store, {this.provider});
  final ServiceStore store;
  RemoteProvider? provider;
  DateTime? lastSuccess;
  bool _running = false;
  SyncInfo get info => SyncInfo(
    pending: store.count('sync_queue', where: (r) => r['state'] == 'pending'),
    conflicts: store.count(
      'sync_queue',
      where: (r) => r['state'] == 'conflict',
    ),
    provider: provider?.name,
    lastSuccess: lastSuccess,
  );
  Future<void> synchronize({Future<void> Function()? flush}) async {
    final remote = provider;
    if (remote == null || _running) return;
    _running = true;
    try {
      final blockedActors = store
          .select(
            'sync_queue',
            where: (r) => r['state'] == 'conflict',
            fields: const ['actor'],
          )
          .map((r) => r['actor'])
          .toSet();
      for (final row in store.select(
        'sync_queue',
        where: (r) => r['state'] == 'pending',
        orderBy: 'created',
      )) {
        final change = LocalChange.fromRow(row);
        if (blockedActors.contains(change.actor) ||
            !remote.canSyncActor(change.actor)) {
          continue;
        }
        // The account may have been deleted while an earlier request was sent.
        if (store.find(
              'sync_queue',
              where: (r) => r['id'] == change.id,
              fields: const ['id'],
            ) ==
            null) {
          continue;
        }
        try {
          final receipt = await remote
              .push(change)
              .timeout(const Duration(seconds: 20));
          if (receipt.operationId != change.id) {
            throw StateError('Confirmação inválida.');
          }
          store.delete('sync_queue', (r) => r['id'] == change.id);
          lastSuccess = store.clock();
        } on RemoteConflict {
          store.update(
            'sync_queue',
            (r) => r['id'] == change.id,
            (r) => {
              'state': 'conflict',
              'attempts': r['attempts'] + 1,
              'last_error': 'Conflito de versão. Revisão necessária.',
            },
          );
          blockedActors.add(change.actor);
        } catch (_) {
          store.update(
            'sync_queue',
            (r) => r['id'] == change.id,
            (r) => {
              'attempts': r['attempts'] + 1,
              'last_error': 'Envio pendente. Será tentado novamente.',
            },
          );
          blockedActors.add(change.actor);
        }
        if (flush != null) await flush();
      }
    } finally {
      _running = false;
    }
  }

  void retryConflict(String id) => store.update(
    'sync_queue',
    (r) => r['id'] == id,
    (r) => {'state': 'pending', 'last_error': ''},
  );
}
